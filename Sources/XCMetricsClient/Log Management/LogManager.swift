// Copyright (c) 2020 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation
import XCMetricsUtils

enum LogManagerError: Error {
    /// If a file is not found on disk, this error is thrown.
    case notFound
}

protocol LogManager {
    /// Retrieve logs from the Xcode directory. If no logs recent logs are found, this method will sleep for a fixed
    /// amount of time in order to let Xcode write the last log. If the log is big, Xcode will take a while to write it.
    /// This is a best-effort logic, since if the log is written after our timeout, we will upload it during the next
    /// build anyway.
    /// - Parameter buildDirectory: The build directory for the current project.
    /// - Parameter timeout: For how many seconds it should retry waiting for current xcode log.
    /// - Returns: currentLog (if any has been found) and a set of older logs tuple.
    func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>)

    /// Retrieve the logs in the cache folder.
    func retrieveCachedLogs() throws -> Set<URL>

    /// Moves logs from the given URLs to the Cache folder in order to self-manage their upload and naming.
    /// - Parameter xcodeLogs: The Xcode logs present in Xcode's directory.
    /// - Parameter cachedLogs: The logs in the cache directory.
    /// - Parameter retries: For how many seconds it should retry until all logs to copy are valid
    func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL>

    /// Saves a failed request to upload a log to disk, in order to be retried later on.
    /// - Parameters:
    ///   - url: The URL of the xcactivitylog for which we need to save the request.
    ///   - data: The HTTP body data that we will need to retry sending to the backend.
    func saveFailedRequest(url: URL, data: Data) throws -> URL

    /// Removes a request of a failed log. Takes place when such a request is finally delivered successfully.
    /// - Parameter url: The URL of the request stored on disk.
    func removeUploadedFailedRequest(url: URL) throws

    /// Appends UPLOADED to the given xcactivitylog file in order to signal its new uploaded status and prevent log duplication.
    /// We can't simply delete logs because otherwise during the next run we would copy old logs from the Xcode directory and end up
    /// with duplicate logs. In this way, we can simply not copy new logs if they are already present in the `xcmetrics` directory.
    /// - Parameter logURL: The URL to the request
    func tagLogAsUploaded(logURL: URL) throws -> URL

    /// Retrieves the cached requests that failed to upload in past runs.
    func retrieveLogRequestsToUpload() throws -> [URL]

    /// Removes logs that are old from the cache directory.
    func evictLogs() throws -> Set<URL>
}

class LogManagerImplementation: LogManager {

    /// The directory where the logs that failed to upload will be stored as binary data.
    static let failedRequestsDirectoryName = "requests"

    /// What is the maximum log age to mark is as a current
    private static let maximumCurrentLogAge: TimeInterval = 2
    /// The directory where the logs will be managed by XCMetrics.
    private static let cacheDirectoryName = "XCMetrics"

    private let projectName: String
    private let fileAccessor: FileAccessor
    private let logCopier: LogCopier
    private let dateProvider: () -> Date
    private let sleepFunction: (UInt32) -> (UInt32)

    init(
        projectName: String,
        fileAccessor: FileAccessor = FileManagerAccessor(.default),
        logCopier: LogCopier? = nil,
        dateProvider: @escaping () -> Date = Date.init,
        sleepFunction: @escaping (UInt32) -> (UInt32) = sleep
    ) {
        self.projectName = projectName
        self.fileAccessor = fileAccessor
        self.logCopier = logCopier ?? ZipValidatorLogCopier(fileAccessor: fileAccessor)
        self.dateProvider = dateProvider
        self.sleepFunction = sleepFunction
    }

    func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>){
        // Find all logs in Xcode's build and archive directories.
        let xcodeLogs = findXCActivityLogsInDirectoriesSorted(buildDirectory)
        let mostRecentLog = xcodeLogs.first
        let mostRecentLogDate = mostRecentLog?.modificationDate
        if let mostRecentLog = mostRecentLog,
            let recentLogDate = mostRecentLogDate, dateProvider().timeIntervalSince(recentLogDate) < LogManagerImplementation.maximumCurrentLogAge {
            return (mostRecentLog.url, Set(xcodeLogs.dropFirst().map { $0.url }))
        }
        // In some cases, Xcode will take a while to write the log (size of the log, CPU usage, etc.).
        // This is a best-effort logic to try and wait up until the amount of seconds specified before timing out.
        var timePassed = 0
        while timePassed < timeout {
            _ = sleepFunction(1)
            timePassed += 1
            if let latestLogURL = try? checkIfNewerLogAppeared(in: buildDirectory, afterDate: mostRecentLogDate) {
                log("Latest log found.")
                return (latestLogURL, Set(xcodeLogs.map({$0.url})))
            }
        }
        return (nil, Set(xcodeLogs.map{$0.url}))
    }

    func retrieveCachedLogs() throws -> Set<URL> {
        let logsDirectoryURL = try retrieveOrCreateCachedLogsURL()
        return Set(try findXCActivityLogsInDirectory(logsDirectoryURL).map { $0.url })
    }

    func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL> {
        var logsToBeCopied = Array(computeLogsToBeCopied(xcodeLogs: xcodeLogs, cachedLogs: cachedLogs))

        var copiedLogs: [URL] = []
        var attemptsLeft = retries + 1
        while attemptsLeft > 0 && !logsToBeCopied.isEmpty {
            logsToBeCopied = try logsToBeCopied.filter { logURL in
                let logsDirectoryURL = try retrieveOrCreateCachedLogsURL()
                let newLocation = logsDirectoryURL.appendingPathComponent(logURL.lastPathComponent)
                do {
                    try logCopier.copyLog(from: logURL, to: newLocation)
                } catch LogCopierError.invalidLog {
                    log("Couldn't copy log because it is invalid")
                    return true
                }
                log("Cached log to location: \(newLocation.path)")
                copiedLogs.append(newLocation)
                return false
            }
            attemptsLeft -= 1
            if logsToBeCopied.isEmpty || attemptsLeft <= 0 {
                break
            }
            // For big log files, Xcode will take a while to finish writing the log to the file.
            // This is a best-effort logic to try `retries` times and wait up until all logs to copy are valid logs.
            _ = sleepFunction(1)
        }
        return Set(copiedLogs)
    }

    func saveFailedRequest(url: URL, data: Data) throws -> URL {
        let failedRequestsDirURL = try retrieveOrCreateRequestsToRetryURL()
        let failedRequestFileURL = failedRequestsDirURL.appendingPathComponent(url.lastPathComponent).deletingPathExtension()
        try data.write(to: failedRequestFileURL)
        return failedRequestFileURL
    }

    func removeUploadedFailedRequest(url: URL) throws {
        try fileAccessor.removeItem(at: url)
    }

    func tagLogAsUploaded(logURL: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: logURL.path) else { throw LogManagerError.notFound }
        let directory = logURL.deletingLastPathComponent()
        let pathExtension = logURL.pathExtension
        let pathName = logURL.deletingPathExtension().lastPathComponent
        let uploadedFileURL = directory.appendingPathComponent(pathName +  "_UPLOADED." + pathExtension)
        do {
            try FileManager.default.moveItem(at: logURL, to: uploadedFileURL)
            log("Successfully marked log as uploaded: \(uploadedFileURL)")
            return uploadedFileURL
        } catch {
            log("Error (\(error.localizedDescription)) in marking log as uploaded: \(uploadedFileURL)")
            throw error
        }
    }

    func retrieveLogRequestsToUpload() throws -> [URL] {
        let directory = try retrieveOrCreateRequestsToRetryURL()
        let requests = try fileAccessor.entriesOfDirectory(at: directory, options: .skipsHiddenFiles)
        return requests.map { $0.url }
    }
    
    func evictLogs() throws -> Set<URL> {
        // Remove logs older than 7 days from cache directory.
        let cachedLogs = try retrieveCachedLogs()
        let logsToBeEvicted = cachedLogs.filter { logURL in
            do {
                let attributes = try fileAccessor.attributesOfItem(atPath: logURL.path)
                guard let lastModificationDate = attributes[FileAttributeKey.modificationDate] as? Date else { return false }
                let components = Calendar.current.dateComponents([.day], from: lastModificationDate, to: dateProvider())
                if components.day ?? 0 > 7 {
                    return true
                }
                return false
            } catch {
                log("Failed to get attributes for item at \(logURL.path): \(error.localizedDescription)")
                return false
            }
        }

        var removedLogs = Set<URL>()
        for logURL in logsToBeEvicted {
            do {
                // Remove old xcactivitylog.
                try fileAccessor.removeItem(at: logURL)
                log("Evicted xcactivitylog at url \(logURL)")
                removedLogs.insert(logURL)
            } catch {
                log("Failed to evict log or upload request for url \(logURL) with error \(error.localizedDescription)")
            }
        }
        return removedLogs
    }
}

extension LogManagerImplementation {

    private func computeLogsToBeCopied(xcodeLogs: Set<URL>, cachedLogs: Set<URL>) -> Set<URL> {
        var logsToBeCopied = Set<URL>()
        let managedLogsFileNames = cachedLogs.map { $0.lastPathComponent }
        for xcodeLog in xcodeLogs {
            let fileName = xcodeLog.lastPathComponent
            let pathExtension = xcodeLog.pathExtension
            let pathName = xcodeLog.deletingPathExtension().lastPathComponent
            let possibleUpdoadedFileName = pathName +  "_\(Constants.uploadedFileNameSuffix)." + pathExtension
            if !managedLogsFileNames.contains(fileName) && !managedLogsFileNames.contains(possibleUpdoadedFileName) {
                logsToBeCopied.insert(xcodeLog)
            }
        }
        return logsToBeCopied
    }

    private func checkIfNewerLogAppeared(in buildDirectory: String, afterDate: Date?) throws -> URL? {
        // Sort the logs by modification date in order to find the most recent one.
        let sortedLogs = findXCActivityLogsInDirectoriesSorted(buildDirectory)
        // Get the most recent log, if it doesn't exist there's no log in the Xcode folder.
        guard let mostRecentLog = sortedLogs.first else { return nil }
        // If there's no after date to compare to, it means this is the first log, so just return it.
        guard let afterDate = afterDate else { return mostRecentLog.url }
        // If the log we have found is newer that the one we're comparing to, return it.
        if mostRecentLog.modificationDate?.compare(afterDate) == .orderedDescending {
            return mostRecentLog.url
        }
        return nil
    }

    private func findXCActivityLogsInDirectory(_ url: URL) throws -> [FileEntry] {
        return try fileAccessor.entriesOfDirectory(
            at: url,
            options: .skipsHiddenFiles
        )
        .filter { $0.url.pathExtension == String.xcactivitylog }
    }

    private func findXCActivityLogsInDirectoriesSorted(_ buildDirectory: String) -> [FileEntry] {
        let xcodeLogsDirectoryURL = URL.makeBuildLogsDirectory(for: buildDirectory)
        let xcodeArchiveLogsDirectoryURL = URL.makeBuildLogsDirectoryWhenArchiving(for: buildDirectory)

        let buildLogs = (try? findXCActivityLogsInDirectory(xcodeLogsDirectoryURL)) ?? []
        let archiveLogs = (try? findXCActivityLogsInDirectory(xcodeArchiveLogsDirectoryURL)) ?? []
        return (buildLogs + archiveLogs).sorted(by: { (lhs, rhs) -> Bool in
            let lhDate = lhs.modificationDate ?? Date.distantPast
            let rhDate = rhs.modificationDate ?? Date.distantPast
            return lhDate.compare(rhDate) == .orderedDescending
        })
    }

    private func retrieveOrCreateCachedLogsURL() throws -> URL {
        guard let cacheURL = fileAccessor.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw LogParserError.noCacheFolder
        }
        let managedLocation = cacheURL
            .appendingPathComponent(Self.cacheDirectoryName)
            .appendingPathComponent(self.projectName)
        if !fileAccessor.fileExists(atPath: managedLocation.path, isDirectory: &.true) {
            try fileAccessor.createDirectory(at: managedLocation, withIntermediateDirectories: true, attributes: nil)
        }
        return managedLocation
    }

    private func retrieveOrCreateRequestsToRetryURL() throws -> URL {
        guard let cacheURL = fileAccessor.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw LogParserError.noCacheFolder
        }
        let managedLocation = cacheURL
            .appendingPathComponent(Self.cacheDirectoryName)
            .appendingPathComponent(self.projectName)
            .appendingPathComponent(Self.failedRequestsDirectoryName)
        if !fileAccessor.fileExists(atPath: managedLocation.path, isDirectory: &.true) {
            try fileAccessor.createDirectory(at: managedLocation, withIntermediateDirectories: true, attributes: nil)
        }
        return managedLocation
    }
}

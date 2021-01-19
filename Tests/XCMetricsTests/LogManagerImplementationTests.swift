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

import XCTest
import Basic
import Utility
@testable import XCMetricsClient

class LogManagerImplementationTests: XCTestCase {

    class MockFileAccessor: FileAccessor {
        var entriesOfDirectoryToReturn: [String: [FileEntry]] = [:]
        var entriesLookups = [URL]()
        func entriesOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> [FileEntry] {
            entriesLookups.append(url)
            return entriesOfDirectoryToReturn[url.path] ?? []
        }

        func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
            return [URL(fileURLWithPath: "Cache", isDirectory: true)]
        }

        func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            return false
        }

        func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
        }
        func copyItem(at srcURL: URL, to dstURL: URL) throws {
        }
        func moveItem(at srcURL: URL, to dstURL: URL) throws {
        }
        func removeItem(at URL: URL) throws {
        }

        func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
            return [:]
        }
        func readFileContent(atPath path: String) throws -> String {
            return ""
        }
    }

    class MockLogCopier: LogCopier {
        var copyLogArgs: [(URL, URL)] = []
        var errorToThrowOnCopy: Error?
        var numerOfErrorsToThrowonCopy = 0
        var noThrowForLogs:[URL] = []
        func copyLog(from source: URL, to destination: URL) throws {
            copyLogArgs.append((source, destination))
            if numerOfErrorsToThrowonCopy > 0,
                let error = errorToThrowOnCopy,
                !noThrowForLogs.contains(source) {
                numerOfErrorsToThrowonCopy -= 1
                throw error
            }
        }
    }

    private var sleepFunction: ((UInt32) -> ())!
    private var mockFileAccessor: MockFileAccessor!
    private var mockLogCopier: MockLogCopier!
    private var dateToProvide: Date!
    private var logManager: LogManager!

    private let sampleNewURL = URL(fileURLWithPath: "some.xcactivitylog")
    private let referenceDate = Date()
    private let projectName = "MyProject"
    private let buildDir = "/Path/Where/My/Repo/Is/Stored"
    private let xcodeLogsDir = "/Path/Where/My/Repo/Logs/Build"
    private let xcodeArchiveLogsDir = "/Path/Logs/Build"

    override func setUp() {
        super.setUp()
        sleepFunction = {_ in XCTFail("Unexpected sleep")}
        mockFileAccessor = MockFileAccessor()
        mockLogCopier = MockLogCopier()
        dateToProvide = referenceDate
        logManager = LogManagerImplementation(
            projectName: projectName,
            fileAccessor: mockFileAccessor,
            logCopier: mockLogCopier,
            dateProvider: { self.dateToProvide },
            sleepFunction: { self.sleepFunction($0); return 0 }
        )
    }

    override func tearDown() {
        super.tearDown()
        sleepFunction = nil
        mockFileAccessor = nil
        logManager = nil
    }

    func testRetrivingXcodeLogsSearchesInLogsBuildDirectories() throws {
        let expectedURLs = Set([
            URL(fileURLWithPath: "/Users/username/repo-path/build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/Logs/Build"),
            URL(fileURLWithPath: "/Users/username/repo-path/build/DerivedData/Logs/Build"),
        ])
        _ = try logManager.retrieveXcodeLogs(in: "/Users/username/repo-path/build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/Spotify/BuildProductsPath", timeout: 0)

        XCTAssertEqual(Set(mockFileAccessor.entriesLookups), expectedURLs)
    }

    func testRetrivingAlreadyExistingFreshLogReturnsImmediatelly() throws {
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: referenceDate)
            ]
        ]

        let (currentLog, _) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertEqual(currentLog, sampleNewURL)
    }

    func testRetrivingXcodeLogsRecognizesLogsOnlyWithXcactivityExtension() throws {
        let invalidNewURL = URL(fileURLWithPath: "some.invalidExtension")
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: invalidNewURL, modificationDate: referenceDate)
            ]
        ]

        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertNil(currentLog)
        XCTAssertTrue(otherLogs.isEmpty)
    }

    func testRetrivingExistingXcodeLogOlderThan2SecondsIsTreatedAsOther() throws {
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: referenceDate.addingTimeInterval(-3.0))
            ]
        ]

        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertNil(currentLog)
        XCTAssertEqual(otherLogs, [sampleNewURL])
    }

    func testRetrivingExistingXcodeLogsSelectsLastFileAsCurrent() throws {
        let otherURL = URL(fileURLWithPath: "other.xcactivitylog")
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: referenceDate.addingTimeInterval(-1.0)),
                FileEntry(url: otherURL, modificationDate: referenceDate.addingTimeInterval(-1.5))
            ]
        ]

        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertEqual(currentLog, sampleNewURL)
        XCTAssertEqual(otherLogs, [otherURL])
    }

    func testRetrivingExistingXcodeLogsSelectsLastFileAsCurrentFromArchiveDirectory() throws {
        let otherURL = URL(fileURLWithPath: "other.xcactivitylog")
        let newerURL = URL(fileURLWithPath: "newer.xcactivitylog")
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: referenceDate.addingTimeInterval(-1.0)),
                FileEntry(url: otherURL, modificationDate: referenceDate.addingTimeInterval(-1.5))
            ],
            xcodeArchiveLogsDir: [
                FileEntry(url: newerURL, modificationDate: referenceDate.addingTimeInterval(-0.5))
            ]
        ]

        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertEqual(currentLog, newerURL)
        XCTAssertEqual(otherLogs, [otherURL, sampleNewURL])
    }

    func testRetrivingXcodeLogsWithUnspecifiedModifiedDataMarksAsOtherLogs() throws {
        let otherURL = URL(fileURLWithPath: "other.xcactivitylog")
        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: nil),
                FileEntry(url: otherURL, modificationDate: nil)
            ]
        ]

        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 0)

        XCTAssertNil(currentLog)
        XCTAssertEqual(otherLogs, [otherURL, sampleNewURL])
    }

    func testRetrivingXcodeLogsTriesTimeoutTimes() throws {
        var sleepIntervals = [UInt32]()
        sleepFunction = {
            sleepIntervals.append($0)
        }
        _ = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 10)

        XCTAssertEqual(sleepIntervals, Array(repeating: 1, count: 10))
    }

    func testRetrivingXcodeLogsNewlyAppearedFileRecognizesAsCurrent() throws {
        let newFileDate = referenceDate.addingTimeInterval(1)
        var sleepIntervals = [UInt32]()
        sleepFunction = {
            sleepIntervals.append($0)
            self.mockFileAccessor.entriesOfDirectoryToReturn = [
                self.xcodeLogsDir: [
                    FileEntry(url: self.sampleNewURL, modificationDate: newFileDate)
                ]
            ]
        }
        let (currentLog, _) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 5)

        XCTAssertEqual(currentLog, sampleNewURL)
        XCTAssertEqual(sleepIntervals, [1])
    }

    func testRetrivingXcodeLogsNewlyAppearedFileWithNotNewerDateIsSkipped() throws {
        let sampleFileDate = referenceDate.addingTimeInterval(-100)
        let otherURL = URL(fileURLWithPath: "other.xcactivitylog")

        mockFileAccessor.entriesOfDirectoryToReturn = [
            xcodeLogsDir: [
                FileEntry(url: sampleNewURL, modificationDate: sampleFileDate)
            ]
        ]
        sleepFunction = { _ in
            self.mockFileAccessor.entriesOfDirectoryToReturn = [
                self.xcodeLogsDir: [
                    FileEntry(url: otherURL, modificationDate: sampleFileDate)
                ]
            ]
        }
        let (currentLog, otherLogs) = try logManager.retrieveXcodeLogs(in: buildDir, timeout: 1)

        XCTAssertNil(currentLog)
        XCTAssertEqual(otherLogs, [sampleNewURL])
    }

    func testCacheCopiesLog() throws {

        _ = try logManager.cacheLogs([sampleNewURL], cachedLogs: [], retries: 5)

        XCTAssertEqual(mockLogCopier.copyLogArgs.count, 1)
    }

    func testCacheLogsRetriesOnNonValidLogOnCopying() throws {
        mockLogCopier.numerOfErrorsToThrowonCopy = 1
        mockLogCopier.errorToThrowOnCopy = LogCopierError.invalidLog
        var sleepCount = 0
        sleepFunction = { _ in
            sleepCount += 1
        }

        _ = try logManager.cacheLogs([sampleNewURL], cachedLogs: [], retries: 1)

        XCTAssertEqual(sleepCount, 1)
    }

    func testCacheLogsDoesNotRetryIfSeriousErrorsDuringCopying() throws {
        mockLogCopier.numerOfErrorsToThrowonCopy = 1
        mockLogCopier.errorToThrowOnCopy = "SomeSeriousError"
        sleepFunction = { _ in
            XCTFail("Unexpected sleep")
        }

        XCTAssertThrowsError(try logManager.cacheLogs([sampleNewURL], cachedLogs: [], retries: 1))
        XCTAssertEqual(mockLogCopier.copyLogArgs.count, 1)
    }

    func testCacheLogsRetriesLimitedTimesOnCopying() throws {
        mockLogCopier.numerOfErrorsToThrowonCopy = 3
        mockLogCopier.errorToThrowOnCopy = LogCopierError.invalidLog
        var sleepCount = 0
        sleepFunction = { _ in
            sleepCount += 1
        }

        let cached = try logManager.cacheLogs([sampleNewURL], cachedLogs: [], retries: 2)

        XCTAssertEqual(cached, [])
        XCTAssertEqual(mockLogCopier.copyLogArgs.count, 3)
        XCTAssertEqual(sleepCount, 2)
    }

    func testCacheRetriesIfSomeFileIsInvalidOnCopying() throws {
        let errorURL = URL(fileURLWithPath: "errous.xcactivitylog")
        mockLogCopier.noThrowForLogs = [sampleNewURL]
        mockLogCopier.numerOfErrorsToThrowonCopy = 3
        mockLogCopier.errorToThrowOnCopy = LogCopierError.invalidLog
        var sleepCount = 0
        sleepFunction = { _ in
            sleepCount += 1
        }

        _ = try logManager.cacheLogs([sampleNewURL, errorURL], cachedLogs: [], retries: 5)

        XCTAssertEqual(mockLogCopier.copyLogArgs.count, 5)
        XCTAssertEqual(sleepCount, 3)
    }

    func testCacheCopiesMultipleFilesWithoutRetries() throws {
        let log2URL = URL(fileURLWithPath: "log2.xcactivitylog")
        let logDestURL = URL(fileURLWithPath: "Cache/XCMetrics/MyProject/some.xcactivitylog")
        let log2DestURL = URL(fileURLWithPath: "Cache/XCMetrics/MyProject/log2.xcactivitylog")

        let cached = try logManager.cacheLogs([sampleNewURL, log2URL], cachedLogs: [], retries: 0)

        XCTAssertEqual(cached, [logDestURL, log2DestURL])
    }

    func testPartialCopyIsDoneOnExceededRetries() throws {
        let errorURL = URL(fileURLWithPath: "errous.xcactivitylog")
        let validLogDestURL = URL(fileURLWithPath: "Cache/XCMetrics/MyProject/some.xcactivitylog")
        mockLogCopier.noThrowForLogs = [sampleNewURL]
        mockLogCopier.numerOfErrorsToThrowonCopy = 2
        mockLogCopier.errorToThrowOnCopy = LogCopierError.invalidLog
        sleepFunction = {_ in }

        let cached = try logManager.cacheLogs([sampleNewURL, errorURL], cachedLogs: [], retries: 1)

        XCTAssertEqual(cached, [validLogDestURL])
    }

    func testLogsToUploadRetrieval() throws {
        let log1 = try! TemporaryFile(prefix: "log1", suffix: ".xcactivitylog")
        let log2 = try! TemporaryFile(prefix: "log2", suffix: ".xcactivitylog")
        let log1UploadRequestURL = writeUploadBuildMetricsRequest(at: log1.url)
        let log2UploadRequestURL = writeUploadBuildMetricsRequest(at: log2.url)
        mockFileAccessor.entriesOfDirectoryToReturn = [
            URL(fileURLWithPath: "Cache/XCMetrics/MyProject/requests").path: [
                FileEntry(url: log1UploadRequestURL, modificationDate: referenceDate),
                FileEntry(url: log2UploadRequestURL, modificationDate: referenceDate)
            ]
        ]

        let logManager = LogManagerImplementation(projectName: projectName, fileAccessor: mockFileAccessor)
        let cached = try logManager.retrieveLogRequestsToUpload()

        XCTAssertEqual(Set(cached), Set([log1UploadRequestURL, log2UploadRequestURL]))
    }

    private func writeUploadBuildMetricsRequest(at url: URL) -> URL {
        let uploadRequestURL = url.deletingLastPathComponent()
            .appendingPathComponent(LogManagerImplementation.failedRequestsDirectoryName)
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent)

        let fakeRequest = UploadBuildMetricsRequest()
        try! FileManager.default.createDirectory(at: uploadRequestURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [:])
        try! fakeRequest.serializedData().write(to: uploadRequestURL)
        return uploadRequestURL
    }
}

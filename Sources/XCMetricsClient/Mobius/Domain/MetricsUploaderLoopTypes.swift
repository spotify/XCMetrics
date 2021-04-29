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
import MobiusCore
import MobiusExtras

// MARK: - Model

struct MetricsUploaderModel: Equatable, Hashable {
    /// The build directory of the project, passed as a command-line argument.
    let buildDirectory: String
    /// The name of the project, passed as a command-line argument.
    let projectName: String
    /// The URL of the service where to send metrics to.
    let serviceURL: URL
    /// The amount of seconds to wait for the Xcode's log to appear.
    let timeout: Int
    /// Whether or not this build was performed in a continuous integration environment.
    let isCI: Bool
    /// The custom provided plugins.
    let plugins: [XCMetricsPlugin]
    /// The log upload requests in this run.
    let parsedRequests: Set<MetricsUploadRequest>
    /// Number of scheduled parsing logs in progress
    let awaitingParsingResultsCount: Int
    /// If true, the Notes found in the log won't be inserted into the database
    let skipNotes: Bool

    init(
        buildDirectory: String,
        projectName: String,
        serviceURL: URL,
        timeout: Int,
        isCI: Bool,
        plugins: [XCMetricsPlugin],
        parsedRequests: Set<MetricsUploadRequest> = Set(),
        awaitingParsingLogResponses: Int = 0,
        skipNotes: Bool = false
    ) {
        self.buildDirectory = buildDirectory
        self.projectName = projectName
        self.serviceURL = serviceURL
        self.plugins = plugins
        self.timeout = timeout
        self.isCI = isCI
        self.parsedRequests = parsedRequests
        self.awaitingParsingResultsCount = awaitingParsingLogResponses
        self.skipNotes = skipNotes
    }

    init() {
        self.buildDirectory = ""
        self.projectName = ""
        self.serviceURL = URL(string: "")!
        self.plugins = []
        self.timeout = 0
        self.isCI = false
        self.parsedRequests = []
        self.awaitingParsingResultsCount = 0
        self.skipNotes = false
    }
}

extension MetricsUploaderModel: CustomDebugStringConvertible {
    var debugDescription: String {
        return """
        buildDirectory: \(buildDirectory),
        projectName: \(projectName),
        serviceURL: \(serviceURL),
        plugins: \(plugins),
        timeout: \(timeout),
        isCI: \(isCI),
        parsedRequests: \(parsedRequests.count),
        awaitingParsingLogResponses: \(awaitingParsingResultsCount)
        skipNotes: \(skipNotes)
        """
    }
}

// MARK: - Events

enum MetricsUploaderEvent {
    /// Xcode and cached logs have been loaded.
    case logsFound(currentLog: URL?, xcodeLogs: Set<URL>, cachedLogs: Set<URL>)
    /// The log has been cached.
    case logsCached(currentLog: URL?, previousLogs: Set<URL>, cachedUploadRequests: Set<MetricsUploadRequest>)
    /// Metadata has been appended to the request.
    case requestMetadataAppended(currentRequest: MetricsUploadRequest)
    /// Plugins have been executed and data appended to the request.
    case pluginsExecuted(currentRequest: MetricsUploadRequest)
    /// The logs that have been uploaded successfully.
    case logsUploaded(logs: Set<URL>)
    /// The logs that have not been uploaded successfully.
    case logsUploadFailed(logs: [URL: Data])
    /// The logs that have been uploaded have been renamed to signal their status.
    case logsTaggedAsUploaded(logs: Set<URL>)
    /// The cached logs that have been evicted from the managed's cache folder.
    case cleanedUpLogs(logs: Set<URL>)
    /// The upload requests that failed to send have been saved to disk.
    case savedUploadRequests
}

extension MetricsUploaderEvent: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .logsFound:
            return "logsFound"
        case .logsCached:
            return "logsCached"
        case .requestMetadataAppended:
            return "requestMetadataAppended"
        case .pluginsExecuted:
            return "pluginsExecuted"
        case .logsUploaded:
            return "logsUploaded"
        case .logsTaggedAsUploaded:
            return "logsTaggedAsUploaded"
        case .cleanedUpLogs:
            return "cleanedUpLogs"
        case .logsUploadFailed:
            return "logsUploadFailed"
        case .savedUploadRequests:
            return "savedUploadRequests"
        }
    }
}

// MARK: - Effects

enum MetricsUploaderEffect: Hashable {
    /// Finds the Xcode logs in the given build directory.
    case findLogs(buildDirectory: String, timeout: Int)
    /// Moves the given Xcode logs that are not yet cached for the given project name.
    case cacheLogs(currentLog: URL?, previousLogs: Set<URL>, cachedLogs: Set<URL>, projectName: String)
    /// Adds metadata to the request.
    case appendMetadata(request: MetricsUploadRequest)
    /// Executes the custom plugins configured if any to add more data to the build.
    case executePlugins(request: MetricsUploadRequest, plugins: [XCMetricsPlugin])
    /// Uploads the given log upload requests to the specified backend service.
    case uploadLogs(serviceURL: URL, projectName: String, isCI: Bool, skipNotes: Bool, logs: Set<MetricsUploadRequest>)
    /// Uploaded logs should be renamed to signal their status and differentiate them from logs yet to be uploaded.
    case tagLogsAsUploaded(logs: Set<URL>)
    /// Logs failed to upload are saved to disk in order to preserve the metadata collected (the actual xcactivitylog is always kept on disk for 7 days).
    case persistNonUploadedLogs(logs: [URL: Data])
    /// Logs should be evicted when too old.
    case cleanUpLogs
}

extension MetricsUploaderEffect: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .findLogs:
            return "findLogs"
        case .cacheLogs:
            return "cacheLogs"
        case .appendMetadata:
            return "appendMetadata"
        case .executePlugins:
            return "executePlugins"
        case .uploadLogs:
            return "uploadLogs"
        case .tagLogsAsUploaded:
            return "tagLogsAsUploaded"
        case .cleanUpLogs:
            return "cleanUpLogs"
        case .persistNonUploadedLogs:
            return "persistNonUploadedLogs"
        }
    }
}

enum MetricsUploaderLogType {
    /// Log created for current build.
    case current
    /// Log for current build with appended metadatas.
    case currentWithMetadata
    /// Log that has been generated for other builds.
    case previous
}

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
import Vapor

/// Stores an .xcactivitylog that would be processed in a later stage
protocol LogFileRepository {

    /// Stores the given file
    /// - Parameter logFile: An xcactivitylog
    /// - Returns: The URL where the file was stored
    func put(logFile: File) throws -> URL

    /// Fetches the log from the given URL
    /// - Parameter logURL: URL of the log to fetch
    /// - Returns: A local URL to the file
    func get(logURL: URL) throws -> URL

}

/// `LogFileRepository` that stores logs in temporary local files
/// This is useful for running the backend locally, but should not be used when running in production
/// if the `ProcessMetricsJob` runs in different servers than the `UploadController`
struct LocalLogFileRepository: LogFileRepository {

    func put(logFile: File) throws -> URL {
        let tmp = try TemporaryFile(creatingTempDirectoryForFilename: "\(UUID().uuidString).xcactivitylog")
        let logData = logFile.data.xcm_onlyFileData()
        let data = Data(buffer: logData)
        try data.write(to: tmp.fileURL)
        return tmp.fileURL
    }

    func get(logURL: URL) throws -> URL {
        let tmp = try TemporaryFile(creatingTempDirectoryForFilename: "\(UUID().uuidString).xcactivitylog")
        try FileManager.default.copyItem(atPath: logURL.path, toPath: tmp.fileURL.path)
        return tmp.fileURL
    }

}

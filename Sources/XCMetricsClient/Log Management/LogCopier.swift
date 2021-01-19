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

enum LogCopierError: Error {
    case invalidLog
    case underlyingError(Error)
}

protocol LogCopier {
    /// Copies a log from one location to another and ensures that source log is a valid file.
    /// - Parameter source: The URL of a log to copy
    /// - Parameter destination: The name of the project for the logs.
    /// - Throws: LogCopierError.notValidLog if a log is invalid, LogCopierError.underlyingError for other errors
    func copyLog(from source: URL, to destination: URL) throws
}


/// Copies a log only if it is a valid zip file
class ZipValidatorLogCopier: LogCopier {
    private let fileAccessor: FileAccessor

    init(fileAccessor: FileAccessor) {
        self.fileAccessor = fileAccessor
    }

    func copyLog(from source: URL, to destination: URL) throws {
        if exec("gzip", "-t", source.path) != 0 {
            throw LogCopierError.invalidLog
        }
        try fileAccessor.copyItem(at: source, to: destination)
    }

    private func exec(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()

        return task.terminationStatus
    }
}

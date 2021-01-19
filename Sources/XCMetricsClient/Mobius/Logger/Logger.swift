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
import os.log

/// Exits the process with the provided exit code and printing the message.
/// - Parameters:
///   - exitCode: The exit code to exit with.
///   - message: The message to be printed to the console.
/// - Returns: Never.
public func exit(_ exitCode: Int32, _ message: String) -> Never {
    print(message)
    os_log("%{public}@", log: OSLog.default, type: .default, message)
    exit(exitCode)
}

/// Logs a message to the console that can be filtered via the Console app.
/// - Parameter string: The message to be logged.
public func log(_ string: String) {
    os_log("%{public}@", log: OSLog.default, type: .default, string)
}

/// Logs an error to the console that can be filtered via the Console app.
/// - Parameter string: The error message to be logged.
public func logError(_ string: String) {
    os_log("%{public}@", log: OSLog.default, type: .error, string)
}

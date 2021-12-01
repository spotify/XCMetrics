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

/// Data needed from the client that did the build
public final class UploadRequestExtraInfo: Codable {

    /// Name of the Xcode project
    public let projectName: String

    /// Name of the host where the build was done
    public let machineName: String

    /// Name of the user that did the build
    public let user: String

    /// True if the build was performed on a continuous integration machine, false otherwise.
    public let isCI: Bool

    /// The last time the host went to sleep as reported by sysctl's `kern.sleeptime` property.
    public let sleepTime: Int?

    /// Don't process the Notes found in the log
    /// In some cases, we can have thousands of these that can make database grow exponentially
    /// while providing little value
    public let skipNotes: Bool?

    /// Build tag
    public let tag: String?

    /// If true, individual tasks with more than a 100 issues (Warnings, Notes, Errors) will be truncated
    /// to have only 100. This is useful to fix memory issues and speed up log processing.
    public let truncLargeIssues: Bool?

    public init(projectName: String,
                machineName: String,
                user: String,
                isCI: Bool,
                sleepTime: Int?,
                skipNotes: Bool?,
                tag: String?,
                truncLargeIssues: Bool?) {
        self.projectName = projectName
        self.machineName = machineName
        self.user = user
        self.isCI = isCI
        self.sleepTime = sleepTime
        self.skipNotes = skipNotes
        self.tag = tag
        self.truncLargeIssues = truncLargeIssues
    }
}

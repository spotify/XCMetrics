// Copyright (c) 2021 Spotify AB.
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
import XCMetricsClient
import XCMetricsUtils

public struct GitPlugin {
    
    public enum GitData {
        case branch // the current branch name
        case latestSHA // the most recent commit hash in short format (6)
    }

    private let gitDirectoryPath: String
    private let gitData: [GitData]
    private let shell: ShellOutFunction

    /// Initializes a `GitPlugin` using a configurable location for the git directory
    /// as well as the git data to attach the associated build metadata.
    /// - Parameter gitDirectoryPath: The location of the git directory to use - usualy Xcode's `${SRCROOT}` environment variable can be used (this variable is not available in the default environment variables for XCMetrics, and would need to be passed in).
    /// - Parameter gitData: The data to be retrieved from git (eg: the build's current branch).  Available data points can be found and added to the `GitData` enumeration.
    /// - Parameter shell: Will default to `shellGetStdout`
    public init(gitDirectoryPath: String, gitData: [GitData] = [.branch, .latestSHA], shell: @escaping ShellOutFunction = shellGetStdout) {
        self.gitDirectoryPath = gitDirectoryPath
        self.gitData = gitData
        self.shell = shell
    }

    public func create() -> XCMetricsPlugin {
        return XCMetricsPlugin(name: "Git", body: { _ -> [String : String] in
            guard !gitData.isEmpty else { return [:] }

            return gitData.reduce(into: [String: String]()) {
                dictionary, target  in
                switch target {
                case .branch:
                    if let branch = try? shell("git", ["-C", gitDirectoryPath, "rev-parse", "--abbrev-ref", "HEAD"], nil, nil) {
                        dictionary["Git_Branch"] = branch
                    }
                case .latestSHA:
                    if let latestSHA = try? shell("git", ["-C", gitDirectoryPath, "rev-parse", "--short=6", "--verify", "HEAD"], nil, nil) {
                        dictionary["Git_Commit_SHA"] = latestSHA
                    }
                }
            }
        })
    }
}

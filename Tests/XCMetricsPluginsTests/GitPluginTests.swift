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

import XCTest
@testable import XCMetricsPlugins
@testable import XCMetricsClient
import XCMetricsUtils

class GitPluginTests: XCTestCase {
    func testGitBranch() {
        let fakeShellOutFunction: ShellOutFunction = { _,_,_,_ in
            return "main"
        }
        let plugin = GitPlugin(gitDirectoryPath: "", gitData: [.branch], shell: fakeShellOutFunction).create()
        let pluginData = plugin.body([:])
        let expectedData = ["Git_Branch": "main"]
        XCTAssertEqual(pluginData, expectedData)
    }
    
    func testGitSHA() {
        let fakeShellOutFunction: ShellOutFunction = { _,_,_,_ in
            return "123f4d"
        }
        let plugin = GitPlugin(gitDirectoryPath: "", gitData: [.latestSHA], shell: fakeShellOutFunction).create()
        let pluginData = plugin.body([:])
        let expectedData = ["Git_Commit_SHA": "123f4d"]
        XCTAssertEqual(pluginData, expectedData)
    }
}

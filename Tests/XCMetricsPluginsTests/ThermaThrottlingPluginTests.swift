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

class ThermaThrottlingPluginTests: XCTestCase {

    func testParseThermInfo100() {
        let fakeShellOutFunction: ShellOutFunction = { _,_,_,_ in
            return """
Note: No thermal warning level has been recorded
Note: No performance warning level has been recorded
2021-01-25 15:04:29 +0100 CPU Power notify
    CPU_Scheduler_Limit \t= 100
    CPU_Available_CPUs \t= 12
    CPU_Speed_Limit \t= 100
"""
        }
        let plugin = ThermalThrottlingPlugin(shell: fakeShellOutFunction).create()
        // This plugin doesn't need any environment variables, just pass an empty dictionary.
        let pluginData = plugin.body([:])
        let expectedData = ["CPU_Speed_Limit": "100"]
        XCTAssertEqual(pluginData, expectedData)
    }

    func testParseThermInfo25() {
        let fakeShellOutFunction: ShellOutFunction = { _,_,_,_ in
            return """
Note: No thermal warning level has been recorded
Note: No performance warning level has been recorded
2021-01-25 15:04:29 +0100 CPU Power notify
    CPU_Scheduler_Limit \t= 100
    CPU_Available_CPUs \t= 12
    CPU_Speed_Limit \t= 25
"""
        }
        let plugin = ThermalThrottlingPlugin(shell: fakeShellOutFunction).create()
        // This plugin doesn't need any environment variables, just pass an empty dictionary.
        let pluginData = plugin.body([:])
        let expectedData = ["CPU_Speed_Limit": "25"]
        XCTAssertEqual(pluginData, expectedData)
    }
}

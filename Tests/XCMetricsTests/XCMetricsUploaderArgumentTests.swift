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
import Foundation

@testable import XCMetricsClient

class XCMetricsArgumentTests: XCTestCase {

    func testDoesNotFailWhenProvidedWithMandatoryArguments() {
        XCTAssertNoThrow(try XCMetrics.parse([
            "--name",
            "Spotify",
            "--buildDir",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test",
        ]))

        XCTAssertNoThrow(try XCMetrics.parse([
            "-n",
            "Spotify",
            "-b",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test",
        ]))
    }

    func testDoesNotFailWhenProvidedWithOptionalArguments() {
        XCTAssertNoThrow(try XCMetrics.parse([
            "--name",
            "Spotify",
            "--buildDir",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test/",
            "--timeout",
            "10",
            "--authorizationKey",
            "Authorization",
            "--authorizationValue",
            "Bearer XXXXXXXXXXXXXXX"
        ]))

        XCTAssertNoThrow(try XCMetrics.parse([
            "-n",
            "Spotify",
            "-b",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test/",
            "-t",
            "10",
            "-k",
            "Authorization",
            "-a",
            "Bearer XXXXXXXXXXXXXXX"
        ]))
    }

    func testFailWhenNoNameIsProvided() {
        XCTAssertThrowsError(try XCMetrics.parse([
            "--buildDir",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test/",
        ]))

        XCTAssertThrowsError(try XCMetrics.parse([
            "-b",
            "/Users/Username/Library/Developer/Xcode/DerivedData/test/",
        ]))
    }

    func testFailWhenNotKnownArgumentIsProvided() {
        XCTAssertThrowsError(try XCMetrics.parse([
            "anyParameter",
            "test"
        ]))
    }

    func testFailWhenNoArgumentsAreProvided() {
        XCTAssertThrowsError(try XCMetrics.parse([]))
    }
}


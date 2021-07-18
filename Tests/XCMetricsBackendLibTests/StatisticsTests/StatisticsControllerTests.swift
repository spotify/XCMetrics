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

@testable import XCMetricsBackendLib
import XCTVapor
import Fluent

final class StatisticsControllerTests: XCTestCase {

    func testBuildCounts() throws {
        let app = Application(.testing)
        try configure(app)
        try app.register(collection: StatisticsController(repository: FakeStatisticsRepository()))
        defer { app.shutdown() }

        let firstDay = Date().truncateTime()!.ago(days: 13)! // Since today is supposed to be included
        let lastDay = Date().truncateTime()!

        try app.test(.GET, "v1/statistics/build/count?days=14", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let dayCounts = try res.content.decode([DayCount].self)
            XCTAssertEqual(dayCounts.count, 14)
            XCTAssertEqual(dayCounts.first!.id, firstDay)
            XCTAssertEqual(dayCounts.last!.id, lastDay)
        })

        // Missing parameter
        try app.test(.GET, "v1/statistics/build/count", afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })

        // Invalid parameter
        try app.test(.GET, "v1/statistics/build/count?days=0", afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testBuildStatus() throws {
        let app = Application(.testing)
        try configure(app)
        try app.register(collection: StatisticsController(repository: FakeStatisticsRepository()))
        defer { app.shutdown() }

        try app.test(.GET, "v1/statistics/build/status", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNoThrow(try res.content.decode(Page<BuildStatusResult>.self))
        })
    }
}

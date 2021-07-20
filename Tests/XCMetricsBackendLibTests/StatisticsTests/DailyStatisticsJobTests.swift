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

final class DailyStatisticsJobTests: XCTestCase {
    func testCreatesDailyCount() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        let repository = FakeStatisticsRepository();
        repository.reset()

        XCTAssertNoThrow(
            try DailyStatisticsJob(repository: repository)
                .run(context: app.queues.queue.context).wait()
        )
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dayCounts = try repository.getDayCounts(
            from: yesterday, to: yesterday, using: app.queues.queue.context.eventLoop
        ).wait()

        XCTAssertEqual(dayCounts.count, 1)
        XCTAssertEqual(dayCounts.first!.id, yesterday.xcm_truncateTime())
    }
}

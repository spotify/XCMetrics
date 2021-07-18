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

import Vapor
import Fluent
@testable import XCMetricsBackendLib

class FakeStatisticsRepository: StatisticsRepository {

    var dayCounts: [DayCount] = []

    init() {
        self.dayCounts = generateDayCounts()
    }

    func getBuildStatuses(page: Int, per: Int, using eventLoop: EventLoop) -> EventLoopFuture<Page<BuildStatusResult>> {
        let statuses = [
            BuildStatusResult(id: "test1", buildStatus: "succeeded"),
            BuildStatusResult(id: "test2", buildStatus: "succeeded"),
            BuildStatusResult(id: "test3", buildStatus: "failed"),
            BuildStatusResult(id: "test4", buildStatus: "pending")
        ]

        let limit = per < statuses.count ? per : statuses.count - 1

        // JSON decoding is used here since access to PageMetadata initializer is restricted,
        // thus Page(items: [], metadata: PageMetadata(page: 1, per: 1, total: 1)) can't be used
        let data = "{\"page\" : \(page),\"per\" : \(per),\"total\": \(statuses.count)}".data(using: .utf8)!
        let meta = try! JSONDecoder().decode(PageMetadata.self, from: data)
        let page: Page<BuildStatusResult> = Page(items: statuses[0...limit].map({$0}), metadata: meta)
        return eventLoop.makeSucceededFuture(page)
    }

    func createDayCount(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.dayCounts.append(DayCount(day: day.truncateTime()!, builds: 1, errors: 1))
        return eventLoop.makeSucceededFuture(())
    }

    func getCount(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<DayCount> {
        let count = dayCounts.first(where: { $0.id == day.truncateTime()! })

        if let count = count {
            return eventLoop.makeSucceededFuture(count)
        }

        return eventLoop.makeSucceededFuture(DayCount(day: day.truncateTime(), builds: 0, errors: 0))
    }

    func getDayCounts(from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[DayCount]> {
        let counts = self.dayCounts
            .filter { $0.id! >= from.truncateTime()! && $0.id! <= to.truncateTime()! }
            .reversed()
            .map { $0 }
        return eventLoop.makeSucceededFuture(counts)
    }

    func reset() {
        self.dayCounts = []
    }

    // MARK: - Private Methods

    func generateDayCounts() -> [DayCount] {
        return stride(from: 1, to: 30, by: 1).map {
            DayCount(day: Date().truncateTime()!.ago(days: $0)!, builds: 10, errors: 2)
        }
    }
}

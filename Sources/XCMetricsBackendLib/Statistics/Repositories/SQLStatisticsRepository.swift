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
import Fluent
import FluentSQL
import NIO

private struct CountResult: Decodable {
    var builds: Int;
    var errors: Int;
}

class SQLStatisticsRepository: StatisticsRepository {

    let db: Database

    init(db: Database) {
        self.db = db;
    }

    func getBuildStatuses(page: Int, per: Int, using eventLoop: EventLoop) -> EventLoopFuture<Page<BuildStatusResult>> {
        return Build.query(on: self.db)
            .field(\.$id)
            .field(\.$buildStatus)
            .sort(\.$startTimestampMicroseconds, .descending)
            .paginate(PageRequest(page: page, per: per))
            .map { $0.map { BuildStatusResult(id: $0.id!, buildStatus: $0.buildStatus) } }
    }

    func getDayCounts(from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[DayCount]> {
        return DayCount.query(on: db)
            .filter(\.$id >= from)
            .filter(\.$id <= to)
            .sort(\.$id)
            .all()
            .flatMap { counts in
                return eventLoop.makeSucceededFuture(
                    self.fillDayCounts(counts: counts, from: from, to: to)
                )
            }

    }

    func getCount(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<DayCount> {
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not SQL"))
        }

        let query: SQLQueryString = """
        SELECT
            sum(error_count) as errors,
            count(*) as builds
        FROM
            \(raw: Build.schema)_\(raw: day.xcm_toPartitionedTableFormat())
        """

        return sql.raw(query)
            .first(decoding: CountResult.self)
            .flatMapAlways { result in
                let count = (try? result.get()) ?? CountResult(builds: 0, errors: 0)
                return eventLoop.makeSucceededFuture(DayCount(day: day, builds: count.builds, errors: count.errors))
            }
    }

    func createDayCount(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return self.getCount(day: day, using: eventLoop).flatMap { count in
            count.create(on: self.db)
        }
    }

    // MARK: - Private Methods

    /// Since days without any build information potentially could exist (for instance if a job has failed or not been run)
    /// we need to fill days without build information with zero values to keep the format consistent.
    /// Performance of this method should be considered for large date ranges.
    private func fillDayCounts(counts: [DayCount], from: Date, to: Date) -> [DayCount] {
        let from = from.truncateTime()
        let days = Calendar.current.dateComponents([.day], from: from, to: to.truncateTime()).day! + 1

        guard days > 0 && counts.count != days else { return counts }

        var filled = [DayCount]()

        for dayOffset in stride(from: 0, to: days, by: 1) {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: from)!

            if let dayCount = counts.first(where: { $0.id == day }) {
                filled.append(dayCount)
            } else {
                filled.append(DayCount(day: day))
            }
        }

        return filled
    }
}

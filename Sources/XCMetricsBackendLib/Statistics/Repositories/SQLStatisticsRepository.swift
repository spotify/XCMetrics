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

    // MARK: - Build Status

    func getBuildStatuses(page: Int, per: Int, using eventLoop: EventLoop) -> EventLoopFuture<Page<BuildStatusResult>> {
        return Build.query(on: self.db)
            .field(\.$id)
            .field(\.$buildStatus)
            .sort(\.$startTimestampMicroseconds, .descending)
            .paginate(PageRequest(page: page, per: per))
            .map { $0.map { BuildStatusResult(id: $0.id!, buildStatus: $0.buildStatus) } }
    }

    // MARK: - Day Count

    func getDayCounts(from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[DayCount]> {
        return DayCount.query(on: db)
            .filter(\.$id >= from)
            .filter(\.$id <= to)
            .sort(\.$id)
            .all()
            .flatMap { counts in
                return eventLoop.makeSucceededFuture(
                    self.fillDays(dayStatistics: counts, from: from, to: to)
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

    // MARK: - Day Build Times

    func getDayBuildTimes(from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[DayBuildTime]> {
        return DayBuildTime.query(on: db)
            .filter(\.$id >= from)
            .filter(\.$id <= to)
            .sort(\.$id)
            .all()
            .flatMap { times in
                return eventLoop.makeSucceededFuture(
                    self.fillDays(dayStatistics: times, from: from, to: to)
                )
            }

    }

    func getBuildTime(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<DayBuildTime> {
        var durations: EventLoopFuture<[Double]>;

        if let sql = db as? SQLDatabase {
            // Optimization to speed up queries if we're using tables sharded by day
            durations = sql.select()
                .column("duration")
                .from("\(Build.schema)_\(day.xcm_toPartitionedTableFormat())")
                .orderBy("duration")
                .all()
                .flatMapError { _ in return eventLoop.makeSucceededFuture([]) }
                .mapEach { (try? $0.decode(column: "duration", as: Double.self)) ?? 0 }
        } else {
            durations = Build.query(on: db).filter(\.$day == day).sort(\.$duration).all(\.$duration)
        }

        return
            durations.flatMap { durations in
                let count = Float(durations.count)

                guard durations.count > 0 else {
                    return eventLoop.makeSucceededFuture(
                        DayBuildTime(day: day, durationP50: 0, durationP95: 0, totalDuration: 0)
                    )
                }

                // Nearest-rank percentiles
                let durationP50 = durations[Int((0.50 * count).rounded(.up)) - 1]
                let durationP95 = durations[Int((0.95 * count).rounded(.up)) - 1]
                let totalDuration = durations.reduce(0, +)

                return eventLoop.makeSucceededFuture(
                    DayBuildTime(day: day, durationP50: durationP50, durationP95: durationP95, totalDuration: totalDuration)
                )
            }
    }


    func createDayBuildTime(day: Date, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return self.getBuildTime(day: day, using: eventLoop).flatMap { time in
            time.create(on: self.db)
        }
    }

    // MARK: - Private Methods

    /// Since days without any build information potentially could exist (for instance if a job has failed or not been run)
    /// we need to fill days without build information with zero values to keep the format consistent.
    /// Performance of this method should be considered for large date ranges.
    private func fillDays<T: DayData>(dayStatistics: [T], from: Date, to: Date) -> [T] {
        let from = from.xcm_truncateTime()
        let days = Calendar.current.dateComponents([.day], from: from, to: to.xcm_truncateTime()).day! + 1

        guard days > 0 && dayStatistics.count != days else { return dayStatistics }

        var filled = [T]()

        for dayOffset in 0..<days {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: from)!

            if let dayStatistic = dayStatistics.first(where: { $0.id == day }) {
                filled.append(dayStatistic)
            } else {
                filled.append(T(day: day))
            }
        }

        return filled
    }
}

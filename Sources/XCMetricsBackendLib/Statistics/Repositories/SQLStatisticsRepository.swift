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
            .sort(\.$id, .descending)
            .paginate(PageRequest(page: page, per: per))
            .map { $0.map { BuildStatusResult(id: $0.id!, buildStatus: $0.buildStatus) } }
    }

    func getDayCounts(from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[DayCount]> {
        return DayCount.query(on: db)
            .filter(\.$id >= from)
            .filter(\.$id <= to)
            .sort(\.$id)
            .all()
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
}

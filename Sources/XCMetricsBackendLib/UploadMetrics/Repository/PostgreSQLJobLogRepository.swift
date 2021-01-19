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

import Foundation
import Fluent
import FluentSQL
import NIO

/// PostgreSQL implementation of `JobLogRepository`
struct PostgreSQLJobLogRepository: JobLogRepository {

    let db: Database

    func create(_ jobLogEntry: JobLogEntry, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return jobLogEntry.save(on: db)
    }

    func update(_ id: String, status: JobLogStatus, error: Error?,
                using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return JobLogEntry.find(id, on: db)
            .flatMap {  entry -> EventLoopFuture<Void> in
                if let entry = entry {
                    return update(entry, status: status, error: error, using: eventLoop)
                } else {
                    // In case the `Job` was not a `ProcessMetricsJob` we don't do anything
                    // This could happen in the future if we add more `Job` types
                    return eventLoop.future()
                }
            }
    }

    func getDashboardFrom(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<JobDashboard> {
        return getCountByStatusFrom(from, to: to, using: eventLoop)
            .map { values -> JobDashboard in
                let failed: Int = values.filter { $0.key == JobLogStatus.failed.rawValue }.first?.value ?? 0
                let successful: Int = values.filter { $0.key == JobLogStatus.successful.rawValue }.first?.value ?? 0
                let running: Int = values.filter { $0.key == JobLogStatus.running.rawValue }.first?.value ?? 0
                let pending: Int = values.filter { $0.key == JobLogStatus.pending.rawValue }.first?.value ?? 0
                return JobDashboard(from: from,
                                    to: to,
                                    successful: successful,
                                    running: running,
                                    failed: failed,
                                    pending: pending,
                                    averageTime: 0.0)
            }.flatMap { jobDashboard -> EventLoopFuture<JobDashboard> in
                self.getAverageExecutionTimeFrom(from, to: to, using: eventLoop)
                    .map { jobDashboard.with(averageTime: $0?.result) }
            }.flatMap { jobDashboard -> EventLoopFuture<JobDashboard> in
                return self.getAveragesPerHour(from, to: to, using: eventLoop)
                    .and(self.getThroughputPerHours(from, to: to, using: eventLoop))
                    .map { jobDashboard.with(averageTimes: $0.0, throughput: $0.0) }
            }
    }

    func getJobs(params: JobListRequest, on db: Database) -> EventLoopFuture<Page<JobLogEntry>> {
        let query = JobLogEntry.query(on: db)
            .filter(\.$createdAt >= params.from)
            .filter(\.$createdAt <= params.to)
        if let status = params.status {
            query.filter(\.$status == status)
        }
        if let filter = params.filter {
            query.filter(\.$logFile ~~ filter)
        }        
        return query.sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: params.page, per: params.per))
    }

    private func update(_ entry: JobLogEntry, status: JobLogStatus,
                        error: Error?, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        entry.status = status
        switch status {
        case .running:
            entry.dequeuedAt = Date()
        case .successful:
            entry.finishedAt = Date()
        case .failed:
            entry.error = error?.localizedDescription ?? "Unknown error"
            entry.finishedAt = Date()
        case .pending:
            entry.queuedAt = Date()
        }
        return entry.update(on: db)
    }

    private func getCountByStatusFrom(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[CountResult]> {
        let query: SQLQueryString = """
        SELECT
            status as key, count(*) as value
        FROM
            \(raw: JobLogEntry.schema)
        WHERE
            created_at BETWEEN \(bind: from) AND \(bind: to)
        GROUP BY
            status;
        """
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not SQL"))
        }
        return sql.raw(query).all(decoding: CountResult.self)
    }


    private func getAverageExecutionTimeFrom(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<AgreggatedResult?> {
        let query: SQLQueryString = """
        SELECT
            COALESCE(AVG(EXTRACT(EPOCH FROM (finished_at - dequeued_at))), 0.0) as "result"
        FROM
            \(raw: JobLogEntry.schema)
        WHERE
            created_at BETWEEN \(bind: from) AND \(bind: to)
        AND
            finished_at IS NOT NULL;
        """
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not SQL"))
        }
        return sql.raw(query).first(decoding: AgreggatedResult.self)
    }

    private func getThroughputPerHours(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[ChartTimeSeries]> {
        let query: SQLQueryString = """
        SELECT
            TO_CHAR(finished_at, 'dd/MM/yyyy HH24:00') as "key",
            COUNT(*) * 1.0 AS "value"
        FROM
            \(raw: JobLogEntry.schema)
        WHERE
            finished_at IS NOT NULL
        AND
            finished_at BETWEEN \(bind: from) AND \(bind: to)
        GROUP BY
            TO_CHAR(finished_at, 'dd/MM/yyyy HH24:00')
        ;
        """
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not SQL"))
        }
        return sql.raw(query).all(decoding: ChartTimeSeries.self)
    }

    private func getAveragesPerHour(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<[ChartTimeSeries]> {
        let query: SQLQueryString = """
        SELECT
            TO_CHAR(finished_at, 'dd/MM/yyyy HH24:00') AS "key",
            AVG(EXTRACT(EPOCH FROM (finished_at - dequeued_at))) AS "value"
        FROM
            \(raw: JobLogEntry.schema)
        WHERE
            finished_at IS NOT NULL
        AND
            finished_at BETWEEN \(bind: from) AND \(bind: to)
        GROUP BY
            TO_CHAR(finished_at, 'dd/MM/yyyy HH24:00')
        ;
        """
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not SQL"))
        }
        return sql.raw(query).all(decoding: ChartTimeSeries.self)
    }

    /// Struct used to decode queries aggregated results
    private struct AgreggatedResult: Decodable {
        var result: Double
    }

    /// Struct used to decode queries results that returs counters
    private struct CountResult: Decodable {
        var key: String
        var value: Int
    }

}

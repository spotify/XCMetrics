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

import Fluent
import FluentSQL
import Foundation
import FluentPostgresDriver

/// PostgresSQL implementation of `MetricsRepository`
struct PostgreSQLMetricsRepository: MetricsRepository {

    let db: Database
    let logger: Logger

    /// Holds the name of the partitions that are already created
    let partitionsCache: NSCache<NSString, NSString>

    init(db: Database, logger: Logger) {
        self.db = db
        self.logger = logger
        self.partitionsCache = NSCache()
        self.partitionsCache.countLimit = 100
    }

    func insertBuildMetrics(_ buildMetrics: BuildMetrics, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let metrics = decorateMetricsWithDay(buildMetrics)
        return db.transaction { database in
            logWithTimestamp(self.logger, msg: "[PostgressMetricsRepository] creating daily partitions")
            return self.createDailyPartitions(on: database, using: eventLoop, for: metrics)
        }.flatMap { (_ : Void) -> EventLoopFuture<Void> in
            logWithTimestamp(self.logger, msg: "[PostgressMetricsRepository] creating daily partitions")

            return self.findBuild(with: buildMetrics.build.id, using: eventLoop).flatMap { build -> EventLoopFuture<Void> in
                // Insert the build in db only once
                guard build == nil else {
                    logWithTimestamp(self.logger, msg: "[PostgressMetricsRepository] build already inserted in db")
                    return eventLoop.future()
                }
                return self.db.transaction { database in
                    self.insert(on: database, buildMetrics: buildMetrics)
                }
            }
        }.map {
            logWithTimestamp(self.logger, msg: "[PostgressMetricsRepository] metrics inserted")
        }
    }

    /// We need to add the day to each entity, so we can insert them on the daily partition
    private func decorateMetricsWithDay(_ buildMetrics: BuildMetrics) -> BuildMetrics {
        let start = buildMetrics.build.startTimestamp

        let day = toZeroHours(start)
        let mirror = Mirror.init(reflecting: buildMetrics)
        mirror.children.forEach { child in
            if var p = child.value as? PartitionedByDay {
                p.day = day
            } else if let list = child.value as? Array<PartitionedByDay> {
                list.forEach { p in
                    var p = p
                    p.day = day
                }
            }
        }
        // Workaround, Mirror can't infer these two are `PartitionedByDay`
        buildMetrics.xcodeVersion?.day = buildMetrics.build.day
        buildMetrics.buildMetadata?.day = buildMetrics.build.day
        return buildMetrics
    }

    /// In Postgress we store the data in tables partitioned by day
    /// Here we create those tables if they don't exist already
    private func createDailyPartitions(on db: Database, using eventLoop: EventLoop, for buildMetrics: BuildMetrics)
    -> EventLoopFuture<Void> {
        guard let dayBuild = buildMetrics.build.day else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "Empty `day` property in `build`"))
        }
        let tableDateFormatter = DateFormatter()
        tableDateFormatter.dateFormat  = "yyyyMMdd"
        tableDateFormatter.timeZone = TimeZone(identifier:"GMT")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat  = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier:"GMT")
        let tableDay = tableDateFormatter.string(from: dayBuild)
        let day = dateFormatter.string(from: dayBuild)
        guard let sql = db as? SQLDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The current DB is not a SQLDatabase"))
        }

        let tables = ["builds",
                      "build_targets",
                      "build_steps",
                      "build_warnings",
                      "build_errors",
                      "build_notes",
                      "swift_functions",
                      "build_hosts",
                      "swift_type_checks",
                      "xcode_versions",
                      "build_metadata",
        ]
        return tables.map { name -> EventLoopFuture<Void> in
            let schemaName = name.xcm_toSchemaName()
            let tableName = "\(schemaName)_\(tableDay)"
            if self.tableExistsInCache(tableName: tableName) {
                return eventLoop.future()
            }
            return self.doesTableExist(tableName,
                                       using: db,
                                       eventLoop: eventLoop)
                .flatMap { tableExists -> EventLoopFuture<Void> in
                    if tableExists {
                        self.addToCache(tableName: tableName)
                        return eventLoop.future()
                    } else {
                        let createStatement = """
                            CREATE TABLE IF NOT EXISTS \(tableName) PARTITION OF \(schemaName)
                            FOR VALUES IN ('\(day)');
                            """
                        return sql.raw(SQLQueryString(stringLiteral: createStatement))
                            .run()
                            .map { () -> Void in
                                self.addToCache(tableName: tableName)
                            }
                    }
                }
        }
        .flatten(on: eventLoop)
    }

    private func findBuild(with id: String?, using eventLoop: EventLoop) -> EventLoopFuture<Build?> {
        guard let id = id else {
            return eventLoop.makeSucceededFuture(nil)
        }
        return Build.query(on: db).filter(\.$id == id).first()
    }

    private func insert(on db: Database, buildMetrics: BuildMetrics) -> EventLoopFuture<Void> {
        // Postgress NIO can handle up to Int16.max connections at once and we usually have more items in a list
        // We split them in chunks to avoid reaching the limit
        let chunk_size = 1_000

        var result = buildMetrics.build.save(on: db)

        let splittedTargets = buildMetrics.targets.xcm_chunked(into: chunk_size)
        splittedTargets.forEach { targets in
            result = result.flatMap{ targets.create(on: db) }
        }
        if !buildMetrics.host.buildIdentifier.isEmpty {
            result = result.flatMap { buildMetrics.host.save(on: db) }
        }
        if let xcodeVersion = buildMetrics.xcodeVersion, !xcodeVersion.buildIdentifier.isEmpty {
            result = result.flatMap { xcodeVersion.save(on: db) }
        }
        let splittedWarnings = buildMetrics.warnings?.xcm_chunked(into: chunk_size)
        splittedWarnings?.forEach { warnings in
            result = result.flatMap { warnings.create(on: db) }
        }
        let splittedErrors = buildMetrics.errors?.xcm_chunked(into: chunk_size)
        splittedErrors?.forEach { errors in
            result = result.flatMap { errors.create(on: db) }
        }
        let splittedNotes = buildMetrics.notes?.xcm_chunked(into: chunk_size)
        splittedNotes?.forEach { notes in
            result = result.flatMap { notes.create(on: db) }
        }
        let splittedSwiftFunctions = buildMetrics.swiftFunctions?.xcm_chunked(into: chunk_size)
        splittedSwiftFunctions?.forEach { swiftFunctions in
            result = result.flatMap { swiftFunctions.create(on: db) }
        }
        let splittedSwiftTypeChecks = buildMetrics.swiftTypeChecks?.xcm_chunked(into: chunk_size)
        splittedSwiftTypeChecks?.forEach { swiftTypeChecks in
            result = result.flatMap { swiftTypeChecks.create(on: db) }
        }
        if let buildMetadata = buildMetrics.buildMetadata, !buildMetadata.buildIdentifier.isEmpty {
            result = result.flatMap{ buildMetadata.create(on: db) }
        }
        let splittedSteps = buildMetrics.steps.xcm_chunked(into: chunk_size)
        splittedSteps.forEach { steps in
            result = result.flatMap { steps.create(on: db) }
        }
        return result
    }


    private func toZeroHours(_ date: Date) -> Date {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        components.timeZone = TimeZone(identifier:"GMT")
        components.hour = 0
        components.minute = 0
        components.second = 0

        return cal.date(from: components) ?? date
    }

    private func doesTableExist(_ tableName: String, using db: Database, eventLoop: EventLoop) -> EventLoopFuture<Bool> {
        guard let postgres = db as? PostgresDatabase else {
            return eventLoop.makeFailedFuture(RepositoryError.unexpected(message: "The database is not Postgress"))
        }
        return postgres.simpleQuery("SELECT to_regclass('\(tableName)')").map { (row) -> Bool in
            // The query always returns a row, but if the table doesn't exists it returns a nil value and if it exists
            // returns the name of the table as a String
            return row.first?.column("to_regclass")?.string != nil
        }
    }

    private func addToCache(tableName: String) {
        let nsTableName = tableName as NSString
        self.partitionsCache.setObject(nsTableName, forKey: nsTableName)
    }

    private func tableExistsInCache(tableName: String) -> Bool {
        return self.partitionsCache.object(forKey: tableName as NSString) != nil
    }
}

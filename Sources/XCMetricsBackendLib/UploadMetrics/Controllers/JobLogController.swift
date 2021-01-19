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
import Vapor

struct JobLogController: RouteCollection {

    let repository: JobLogRepository

    func boot(routes: RoutesBuilder) throws {
        routes.get("v1", "job", "dashboard", use: dashboard)
        routes.post("v1", "job", "list", use: list)
    }

    /// Returns a `JobDashboard` with the data between the provided dates.
    /// The dates are passed as query parameters named `from` and `to` in ISO Format.
    /// e.g. `?from=2020-10-23T01:00:00Z&to=2020-10-23T09:00`
    func dashboard(req: Request) throws -> EventLoopFuture<JobDashboard> {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime,
                                       .withDashSeparatorInDate,
                                       .withFullDate,
                                       .withColonSeparatorInTimeZone,
                                       .withFractionalSeconds]
        guard
            let fromStr = req.query["from"] as String?,
            let toStr = req.query["to"] as String?,
            let from = dateFormatter.date(from: fromStr),
            let to = dateFormatter.date(from: toStr) else {
            throw Abort(.badRequest)
        }
        return repository.getDashboardFrom(from, to: to, using: req.eventLoop)
    }

    /// Retuns a paginated list of `JobLogEntry` that matches the `JobListRequest` parameters
    func list(req: Request) throws -> EventLoopFuture<Page<JobLogEntry>> {
        let params = try req.content.decode(JobListRequest.self)
        return repository.getJobs(params: params, on: req.db)
    }
}

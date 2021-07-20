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
import Vapor

/// Controller with endpoints that return statistics for build related data
public struct StatisticsController: RouteCollection {

    let repository: StatisticsRepository;

    init(repository: StatisticsRepository) {
        self.repository = repository;
    }
    
    /// Returns the routes supported by this Controller.
    /// All the routes are in the `v1/statistics` path
    /// - Parameter routes: RoutesBuilder to which the routes will be added
    /// - Throws: An `Error` if something goes wrong
    public func boot(routes: RoutesBuilder) throws {
        routes.get("v1", "statistics", "build", "count", use: buildCounts)
        routes.get("v1", "statistics", "build", "status", use: buildStatus)
    }

    /// Endpoint that returns a list of `DayCount` which includes
    /// the sum of errors and builds during a given day
    /// - Method: `GET`
    /// - Route: `/v1/statistics/build/count?days=14`
    /// - Request parameters
    ///     - `days`. How many days to include in the past, starting
    ///     from the current date
    ///
    /// - Response:
    /// ```
    /// [
    ///   {
    ///      "id": "2021-07-14",
    ///      "builds": 197,
    ///      "errors": 4,
    ///   },
    ///   ...
    /// ]
    /// ```
    public func buildCounts(req: Request) throws -> EventLoopFuture<[DayCount]> {
        guard let days = Int(req.query["days"] ?? "") else { throw Abort(.badRequest) }
        guard days > 0 else { throw Abort(.badRequest) }

        let from = Calendar.current.date(byAdding: .day, value: -days + 1, to: Date())!
        let to = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        return self.repository.getDayCounts(from: from, to: to, using: req.eventLoop).flatMap { counts in
            self.repository.getCount(day: Date().xcm_truncateTime(), using: req.eventLoop).flatMap { count in
                req.eventLoop.makeSucceededFuture(counts + [count])
            }
        }
    }

    /// Endpoint that returns the paginated list of `BuildStatusResult`
    /// to minimize payload size when many statuses are required
    /// - Method: `GET`
    /// - Route: `/v1/statistics/build/status?page=1&per=10`
    /// - Request parameters
    ///     - `page`. Optional. Page number to fetch. Default is `1`
    ///     - `per`. Optional. Number of items to fetch per page. Default is `10`
    ///
    /// - Response:
    /// ```
    /// {
    ///   "metadata": {
    ///       "per": 10,
    ///       "total": 100,
    ///       "page": 2
    ///     },
    ///    "items": [
    ///      {
    ///        "id": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///        "buildStatus": "succeeded",
    ///      },
    ///      ...
    ///    ]
    /// }
    /// ```
    public func buildStatus(req: Request) throws -> EventLoopFuture<Page<BuildStatusResult>> {
        guard let page = Int(req.query["page"] ?? "1"),
              let per = Int(req.query["per"] ?? "10")
        else { throw Abort(.badRequest) }

        return self.repository.getBuildStatuses(page: page, per: per, using: req.eventLoop)
    }
}

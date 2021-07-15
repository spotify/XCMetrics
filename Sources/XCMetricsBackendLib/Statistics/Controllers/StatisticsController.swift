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
    
    /// Returns the routes supported by this Controller.
    /// All the routes are in the `v1/statistics` path
    /// - Parameter routes: RoutesBuilder to which the routes will be added
    /// - Throws: An `Error` if something goes wrong
    public func boot(routes: RoutesBuilder) throws {
        routes.get("v1", "statistics", "build", "status", use: buildStatus)
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
        return Build.query(on: req.db)
            .field(\.$id)
            .field(\.$buildStatus)
            .paginate(for: req)
            .map { $0.map { BuildStatusResult(id: $0.id!, buildStatus: $0.buildStatus) } }
    }
}

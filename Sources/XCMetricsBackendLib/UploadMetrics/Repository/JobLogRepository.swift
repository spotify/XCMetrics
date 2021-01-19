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
import NIO

/// Repository of Job Log entries
protocol JobLogRepository {

    /// Creates a new JobLogEntry
    func create(_ jobLogEntry: JobLogEntry, using eventLoop: EventLoop) -> EventLoopFuture<Void>

    /// Updates an existing `JobLogEntry`
    func update(_ id: String, status: JobLogStatus, error: Error?, using eventLoop: EventLoop) -> EventLoopFuture<Void>

    /// - Returns: a `JobDashboard` with data between `from` and `to`
    func getDashboardFrom(_ from: Date, to: Date, using eventLoop: EventLoop) -> EventLoopFuture<JobDashboard>


    /// Returns the Paginated list of existing `JobLogEntry`
    /// - Parameters:
    ///   - params: a `JobListRequest`
    ///   - db: The `Database` of the current request
    func getJobs(params: JobListRequest, on db: Database) -> EventLoopFuture<Page<JobLogEntry>>
}

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

struct JobLogEntryMigration: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(JobLogEntry.schema)
            .field(.id, .string, .identifier(auto: false))
            .field("log_file", .string, .required)
            .field("log_url", .string)
            .field("status", .string, .required)
            .field("error", .string)
            .field("queued_at", .datetime, .required)
            .field("dequeued_at", .datetime)
            .field("finished_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "log_file", name: "no_duplicated_log_files")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(JobLogEntry.schema).delete()
    }
}

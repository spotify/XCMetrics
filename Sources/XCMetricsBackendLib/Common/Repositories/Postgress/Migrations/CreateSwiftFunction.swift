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

struct CreateSwiftFunction: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
            CREATE TABLE swift_functions (
                id uuid,
                day date NOT NULL,
                build_identifier text NOT NULL,
                step_identifier text NOT NULL,
                file text NOT NULL,
                signature text NOT NULL,
                starting_line integer NOT NULL,
                starting_column integer NOT NULL,
                duration double precision NOT NULL,
                occurrences integer NOT NULL,
                PRIMARY KEY (id, day)
            ) PARTITION BY LIST (day);
            """).run()
        }
        return database.schema("swift_functions")
            .id()
            .field("build_identifier", .string, .required)
            .field("step_identifier", .string, .required)
            .field("file", .string, .required)
            .field("signature", .string, .required)
            .field("starting_line", .int32, .required)
            .field("starting_column", .int32, .required)
            .field("duration", .double, .required)
            .field("occurrences", .int32, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("swift_functions").delete()
    }
}

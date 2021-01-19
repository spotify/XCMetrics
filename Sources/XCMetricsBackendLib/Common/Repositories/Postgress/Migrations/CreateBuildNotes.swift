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

struct CreateBuildNotes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
            CREATE TABLE build_notes (
                id uuid,
                day date NOT NULL,
                build_identifier text NOT NULL,
                parent_identifier text NOT NULL,
                parent_type text NOT NULL,
                title text NOT NULL,
                document_url text NOT NULL,
                severity integer NOT NULL,
                starting_line integer NOT NULL,
                ending_line integer NOT NULL,
                starting_column integer NOT NULL,
                ending_column integer NOT NULL,
                character_range_start integer NOT NULL,
                character_range_end integer NOT NULL,
                PRIMARY KEY (id, day)
            ) PARTITION BY LIST (day);
            """).run()
        }
        return database.schema("build_notes")
            .id()
            .field("build_identifier", .string, .required)
            .field("parent_identifier", .string, .required)
            .field("parent_type", .string, .required)
            .field("title", .string, .required)
            .field("document_url", .string, .required)
            .field("severity", .int32, .required)
            .field("starting_line", .int32, .required)
            .field("ending_line", .int32, .required)
            .field("starting_column", .int32, .required)
            .field("ending_column", .int32, .required)
            .field("character_range_start", .int32, .required)
            .field("character_range_end", .int32, .required)

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("build_notes").delete()
    }
}

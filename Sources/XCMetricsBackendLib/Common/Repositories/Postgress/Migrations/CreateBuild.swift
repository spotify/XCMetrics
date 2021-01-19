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

struct CreateBuild: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
                CREATE TABLE builds (
                    id text,
                    day date NOT NULL,
                    project_name text NOT NULL,
                    machine_name text NOT NULL,
                    schema text NOT NULL,
                    build_status text NOT NULL,
                    start_timestamp timestamp with time zone NOT NULL,
                    end_timestamp timestamp with time zone NOT NULL,
                    compilation_end_timestamp timestamp with time zone NOT NULL,
                    start_timestamp_microseconds double precision NOT NULL,
                    end_timestamp_microseconds double precision NOT NULL,
                    compilation_end_timestamp_microseconds double precision NOT NULL,
                    duration double precision NOT NULL,
                    compilation_duration double precision NOT NULL,
                    warning_count integer NOT NULL,
                    error_count integer NOT NULL,
                    tag text NOT NULL,
                    is_ci boolean NOT NULL,
                    user_id text NOT NULL,
                    user_id_256 text NOT NULL,
                    category text NOT NULL,
                    compiled_count integer NOT NULL,
                    was_suspended boolean NOT NULL,
                    PRIMARY KEY (id, day)
                ) PARTITION BY LIST (day);
            """).run()
        }
        return database.schema("builds")            
            .field("id", .string, .identifier(auto: false))
            .field("project_name", .string, .required)
            .field("machine_name", .string, .required)
            .field("schema", .string, .required)
            .field("build_status", .string, .required)
            .field("start_timestamp", .datetime, .required)
            .field("end_timestamp", .datetime, .required)
            .field("compilation_end_timestamp", .datetime, .required)
            .field("start_timestamp_microseconds", .double, .required)
            .field("end_timestamp_microseconds", .double, .required)
            .field("compilation_end_timestamp_microseconds", .double, .required)
            .field("duration", .double, .required)
            .field("compilation_duration", .double, .required)
            .field("warning_count", .int32, .required)
            .field("error_count", .int32, .required)
            .field("tag", .string, .required)
            .field("is_ci", .bool, .required)
            .field("user_id", .string, .required)
            .field("user_id_256", .string, .required)
            .field("category", .string, .required)
            .field("compiled_count", .int32, .required)
            .field("was_suspended", .bool, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("builds").delete()
    }
}

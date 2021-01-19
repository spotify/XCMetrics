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

struct CreateBuildHosts: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
            CREATE TABLE build_hosts (
                id text,
                day date NOT NULL,
                build_identifier text NOT NULL,
                host_os text NOT NULL,
                host_architecture text NOT NULL,
                host_model text NOT NULL,
                host_os_family text NOT NULL,
                host_os_version text NOT NULL,
                cpu_model text NOT NULL,
                cpu_count integer NOT NULL,
                cpu_speed_ghz double precision NOT NULL,
                memory_total_mb double precision NOT NULL,
                memory_free_mb double precision NOT NULL,
                swap_total_mb double precision NOT NULL,
                swap_free_mb double precision NOT NULL,
                uptime_seconds bigint NOT NULL,
                timezone text NOT NULL,
                is_virtual boolean NOT NULL,
                PRIMARY KEY (id, day)
            ) PARTITION BY LIST (day);
            """).run()
        }
        return database.schema("build_hosts")
            .field("id", .string, .identifier(auto: false))
            .field("build_identifier", .string, .required)
            .field("host_os", .string, .required)
            .field("host_architecture", .string, .required)
            .field("host_model", .string, .required)
            .field("host_os_family", .string, .required)
            .field("host_os_version", .string, .required)
            .field("cpu_model", .string, .required)
            .field("cpu_count", .int32, .required)
            .field("cpu_speed_ghz", .float, .required)
            .field("memory_total_mb", .double, .required)
            .field("memory_free_mb", .double, .required)
            .field("swap_total_mb", .double, .required)
            .field("swap_free_mb", .double, .required)
            .field("uptime_seconds", .int64, .required)
            .field("timezone", .string, .required)
            .field("is_virtual", .bool, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("build_hosts").delete()
    }
}

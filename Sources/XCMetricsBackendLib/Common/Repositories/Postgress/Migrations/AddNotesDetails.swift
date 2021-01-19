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


struct AddDetailsToErrors: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildError.schema)
            .field("detail", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildError.schema)
            .deleteField("detail")
            .update()
    }

}

struct AddDetailsToWarnings: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildWarning.schema)
            .field("detail", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildWarning.schema)
            .deleteField("detail")
            .update()
    }

}

struct AddDetailsToNotes: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildNote.schema)
            .field("detail", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(BuildNote.schema)
            .deleteField("detail")
            .update()
    }

}


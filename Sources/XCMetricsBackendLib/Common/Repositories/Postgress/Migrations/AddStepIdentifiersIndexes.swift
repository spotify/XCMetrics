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

import Foundation

import Fluent
import FluentSQL

struct AddStepIdentifierIndexToSwiftFunctions: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddStepIdentifierIndexToSwiftFunctions can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_step_identifier_on_swift_functions"
                ON \(raw: SwiftFunction.schema) using btree(step_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddStepIdentifierIndexToSwiftFunctions can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_step_identifier_on_swift_functions";
                """)
                .run()
    }

}

struct AddStepIdentifierIndexToSwiftTypeChecks: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddStepIdentifierIndexToSwiftTypeChecks can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_step_identifier_on_swift_type_checks"
                ON \(raw: SwiftTypeChecks.schema) using btree(step_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddStepIdentifierIndexToSwiftTypeChecks can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_step_identifier_on_swift_type_checks";
                """)
                .run()
    }

}

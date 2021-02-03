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

struct AddBuildIdentifierIndexToTarget: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdIndexToTarget can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_targets"
                ON \(raw: Target.schema) using btree(build_identifier);
                """)
                .run()
            .flatMap {
                sql.raw("""
                        DROP INDEX "index_build_identifier_on_targets";
                        """)
                        .run()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdIndexToTarget can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_targets";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToStep: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToStep can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_steps"
                ON \(raw: Step.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToStep can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_steps";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToBuildErrors: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildErrors can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_build_errors"
                ON \(raw: BuildError.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildErrors can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_build_errors";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToBuildWarnings: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildWarnings can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_build_warnings"
                ON \(raw: BuildWarning.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildWarnings can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_build_warnings";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToBuildNotes: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildNotes can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_build_notes"
                ON \(raw: BuildNote.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildNotes can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_build_notes";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToBuildHost: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildHost can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_build_hosts"
                ON \(raw: BuildHost.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildHost can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_build_hosts";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToSwiftFunctions: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToSwiftFunctions can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_swift_functions"
                ON \(raw: SwiftFunction.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToSwiftFunctions can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_swift_functions";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToSwiftTypeChecks: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToSwiftTypeChecks can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_swift_type_checks"
                ON \(raw: SwiftTypeChecks.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToSwiftTypeChecks can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_swift_type_checks";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToXcodeVersion: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToXcodeVersion can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_xcode_versions"
                ON \(raw: XcodeVersion.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToXcodeVersion can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_xcode_versions";
                """)
                .run()
    }

}

struct AddBuildIdentifierIndexToBuildMetadata: Migration {

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildMetadata can only run on a SQL database")
        }
        return sql.raw("""
                CREATE INDEX "index_build_identifier_on_build_metadata"
                ON \(raw: BuildMetadata.schema) using btree(build_identifier);
                """)
                .run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let sql = database as? SQLDatabase else {
            preconditionFailure("AddBuildIdentifierIndexToBuildMetadata can only run on a SQL database")
        }
        return sql.raw("""
                DROP INDEX "index_build_identifier_on_build_metadata";
                """)
                .run()
    }

}

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
import Vapor
import XCLogParser

final class SwiftTypeChecks: Model, Content, PartitionedByDay {

    static let schema = "swift_type_checks"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "build_identifier")
    var buildIdentifier: String

    @Field(key: "step_identifier")
    var stepIdentifier: String

    @Field(key: "file")
    var file: String

    @Field(key: "starting_line")
    var startingLine: Int32

    @Field(key: "starting_column")
    var startingColumn: Int32

    @Field(key: "duration")
    var duration: Double

    @Field(key: "occurrences")
    var occurrences: Int32

    @Field(key: "day")
    var day: Date?

}

extension SwiftTypeChecks {

    func withBuildIdentifier(_ buildIdentifier: String) -> SwiftTypeChecks {
        self.buildIdentifier = buildIdentifier
        return self
    }


    func withStepIdentifier(_ stepIdentifier: String) -> SwiftTypeChecks {
        self.stepIdentifier = stepIdentifier
        return self
    }

    func withTypeCheck(_ typeCheck: SwiftTypeCheck) -> SwiftTypeChecks {
        self.file = typeCheck.file
        self.startingLine = Int32(typeCheck.startingLine)
        self.startingColumn = Int32(typeCheck.startingColumn)
        self.duration = typeCheck.durationMS
        self.occurrences = Int32(typeCheck.occurrences)
        return self
    }
}

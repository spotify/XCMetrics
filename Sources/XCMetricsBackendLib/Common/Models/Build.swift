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

public final class Build: Model, Content, PartitionedByDay {

    public typealias IDValue = String

    public static let schema = "builds"

    public init() { }

    @ID(custom: .id, generatedBy: IDProperty.Generator.user)
    public var id: String?

    @Field(key: "project_name")
    var projectName: String

    @Field(key: "machine_name")
    var machineName: String

    @Field(key: "schema")
    var schema: String

    @Field(key: "start_timestamp")
    var startTimestamp: Date

    @Field(key: "end_timestamp")
    var endTimestamp: Date

    @Field(key: "start_timestamp_microseconds")
    var startTimestampMicroseconds: Double

    @Field(key: "end_timestamp_microseconds")
    var endTimestampMicroseconds: Double

    @Field(key: "duration")
    var duration: Double

    @Field(key: "build_status")
    var buildStatus: String

    @Field(key: "warning_count")
    var warningCount: Int32

    @Field(key: "error_count")
    var errorCount: Int32

    @Field(key: "tag")
    var tag: String

    @Field(key: "is_ci")
    var isCi: Bool

    @Field(key: "user_id")
    var userid: String

    @Field(key: "user_id_256")
    var userid256: String

    @Field(key: "category")
    var category: String

    @Field(key: "compiled_count")
    var compiledCount: Int32

    @Field(key: "was_suspended")
    var wasSuspended: Bool

    @Field(key: "compilation_end_timestamp")
    var compilationEndTimestamp: Date

    @Field(key: "compilation_end_timestamp_microseconds")
    var compilationEndTimestampMicroseconds: Double

    @Field(key: "compilation_duration")
    var compilationDuration: Double

    @Field(key: "day")
    var day: Date?

}

extension Build {

    func withBuildStep(buildStep: BuildStep) -> Build {
        self.id = buildStep.identifier
        self.machineName = buildStep.machineName
        self.schema = buildStep.schema
        self.startTimestamp = Date(timeIntervalSince1970: buildStep.startTimestamp)
        self.endTimestamp = Date(timeIntervalSince1970: buildStep.endTimestamp)
        self.startTimestampMicroseconds = buildStep.startTimestamp
        self.endTimestampMicroseconds = buildStep.endTimestamp
        self.duration = buildStep.duration.xcm_roundToDecimal(9)
        self.buildStatus = buildStep.buildStatus
        self.warningCount = Int32(buildStep.warningCount)
        self.errorCount = Int32(buildStep.errorCount)
        self.compilationEndTimestamp = Date(timeIntervalSince1970: buildStep.compilationEndTimestamp)
        self.compilationEndTimestampMicroseconds = buildStep.compilationEndTimestamp
        self.compilationDuration = buildStep.compilationDuration.xcm_roundToDecimal(9)
        return self
    }

    func withCategory(_ category: String) -> Build {
        self.category = category
        return self
    }

    func withCompiledCount(_ compiledCount: Int32) -> Build {
        self.compiledCount = compiledCount
        return self
    }

}

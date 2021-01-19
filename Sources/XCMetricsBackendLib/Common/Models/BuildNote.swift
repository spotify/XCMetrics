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

final class BuildNote: Model, Content, PartitionedByDay {

    static let schema = "build_notes"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "build_identifier")
    var buildIdentifier: String

    @Field(key: "parent_identifier")
    var parentIdentifier: String

    @Field(key: "parent_type")
    var parentType: String

    @Field(key: "title")
    var title: String

    @Field(key: "document_url")
    var documentURL: String

    @Field(key: "severity")
    var severity: Int32

    @Field(key: "starting_line")
    var startingLine: Int32

    @Field(key: "ending_line")
    var endingLine: Int32

    @Field(key: "starting_column")
    var startingColumn: Int32

    @Field(key: "ending_column")
    var endingColumn: Int32

    @Field(key: "character_range_start")
    var characterRangeStart: Int32

    @Field(key: "character_range_end")
    var characterRangeEnd: Int32

    @Field(key: "detail")
    var detail: String?

    @Field(key: "day")
    var day: Date?

}


extension BuildNote {

    func withNotice(_ notice: Notice) -> BuildNote {
        self.title = notice.title        
        self.documentURL = notice.documentURL
        self.severity = Int32(notice.severity)
        self.startingLine = Int32.xcm_fromUInt64(notice.startingLineNumber)
        self.endingLine = Int32.xcm_fromUInt64(notice.endingLineNumber)
        self.startingColumn = Int32.xcm_fromUInt64(notice.startingColumnNumber)
        self.endingColumn = Int32.xcm_fromUInt64(notice.endingColumnNumber)
        self.characterRangeStart = Int32.xcm_fromUInt64(notice.characterRangeStart)
        self.characterRangeEnd = Int32.xcm_fromUInt64(notice.characterRangeEnd)
        self.detail = notice.detail
        return self
    }

    func withBuildIdentifier(_ buildIdentifier: String) -> BuildNote {
        self.buildIdentifier = buildIdentifier
        return self
    }

    func withParentIdentifier(_ parentIdentifier: String) -> BuildNote {
        self.parentIdentifier = parentIdentifier
        return self
    }

    func withParentType(_ parentType: String) -> BuildNote {
        self.parentType = parentType
        return self
    }

}

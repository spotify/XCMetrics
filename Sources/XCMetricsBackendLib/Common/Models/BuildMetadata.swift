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

public final class BuildMetadata: Model, Content, PartitionedByDay {
    public static let schema = "build_metadata"

    public init() { }

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "build_identifier")
    var buildIdentifier: String

    @Field(key: "metadata")
    var metadata: [String: JSONValue]

    @Field(key: "day")
    var day: Date?

}

extension BuildMetadata {

    convenience init(id: UUID?, buildIdentifier: String, metadata: [String: JSONValue], day: Date?) {
        self.init()
        self.id = id
        self.buildIdentifier = buildIdentifier
        self.metadata = metadata
        self.day = day
    }

    func withBuildIdentifier(_ newBuildIdentifier: String) -> BuildMetadata {
        return BuildMetadata(id: id,
                             buildIdentifier: newBuildIdentifier,
                             metadata: metadata,
                             day: day)
    }
}

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

final class XcodeVersion: Model, Content, PartitionedByDay {

    static let schema = "xcode_versions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "build_identifier")
    var buildIdentifier: String

    @Field(key: "version")
    var version: String

    @Field(key: "build_number")
    var buildNumber: String

    @Field(key: "day")
    var day: Date?

}

extension XcodeVersion {

    convenience init(id: UUID?, buildIdentifier: String, version: String, buildNumber: String, day: Date?) {
        self.init()
        self.id = id
        self.buildIdentifier = buildIdentifier
        self.version = version
        self.buildNumber = buildNumber
        self.day = day
    }

    func withBuildIdentifier(_ newBuildIdentifier: String) -> XcodeVersion {
        return XcodeVersion(id: id,
                            buildIdentifier: newBuildIdentifier,
                            version: version,
                            buildNumber: buildNumber,
                            day: day)
    }

}

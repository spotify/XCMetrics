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

import Vapor

/// Wraps the data of a whole XCMetrics Build
final class BuildMetrics: Content {

    init(build: Build,
         targets: [Target],
         steps: [Step],
         warnings: [BuildWarning]?,
         errors: [BuildError]?,
         notes: [BuildNote]?,
         swiftFunctions: [SwiftFunction]?,
         swiftTypeChecks: [SwiftTypeChecks]?,
         host: BuildHost,
         xcodeVersion: XcodeVersion?,
         buildMetadata: BuildMetadata?) {
        self.build = build
        self.targets = targets
        self.steps = steps
        self.warnings = warnings
        self.errors = errors
        self.notes = notes
        self.swiftFunctions = swiftFunctions
        self.swiftTypeChecks = swiftTypeChecks
        self.host = host
        self.xcodeVersion = xcodeVersion
        self.buildMetadata = buildMetadata
    }

    /// Build data, mandatory
    let build: Build

    let targets: [Target]

    let steps: [Step]

    let warnings: [BuildWarning]?

    let errors: [BuildError]?

    let notes: [BuildNote]?

    let swiftFunctions: [SwiftFunction]?

    let swiftTypeChecks: [SwiftTypeChecks]?

    let host: BuildHost

    let xcodeVersion: XcodeVersion?

    /// Build metadata, can be nil if the user decided not to collect it
    let buildMetadata: BuildMetadata?

}

extension BuildMetrics {

    func withHost(_ newBuildHost: BuildHost) -> BuildMetrics {
        return BuildMetrics(build: build,
                            targets: targets,
                            steps: steps,
                            warnings: warnings,
                            errors: errors,
                            notes: notes,
                            swiftFunctions: swiftFunctions,
                            swiftTypeChecks: swiftTypeChecks,
                            host: newBuildHost,
                            xcodeVersion: xcodeVersion,
                            buildMetadata: buildMetadata)
    }

    func withXcodeVersion(_ newXcodeVersion: XcodeVersion?) -> BuildMetrics {
        return BuildMetrics(build: build,
                            targets: targets,
                            steps: steps,
                            warnings: warnings,
                            errors: errors,
                            notes: notes,
                            swiftFunctions: swiftFunctions,
                            swiftTypeChecks: swiftTypeChecks,
                            host: host,
                            xcodeVersion: newXcodeVersion,
                            buildMetadata: buildMetadata)
    }

    func withBuildMetadata(_ newBuildMetadata: BuildMetadata?) -> BuildMetrics {
        return BuildMetrics(build: build,
                            targets: targets,
                            steps: steps,
                            warnings: warnings,
                            errors: errors,
                            notes: notes,
                            swiftFunctions: swiftFunctions,
                            swiftTypeChecks: swiftTypeChecks,
                            host: host,
                            xcodeVersion: xcodeVersion,
                            buildMetadata: newBuildMetadata)
    }

    func addDayToMetrics() -> BuildMetrics {
        let start = self.build.startTimestamp
        guard let day = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: start) else {
            return self
        }
        let mirror = Mirror.init(reflecting: self)
        mirror.children.forEach { child in
            if var p = child.value as? PartitionedByDay {
                p.day = day
            }
            if let list = child.value as? Array<PartitionedByDay> {
                list.forEach { p in
                    var p = p
                    p.day = day
                }
            }
        }
        return self
    }
}

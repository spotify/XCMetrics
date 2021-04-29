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

import Foundation
import XCLogParser

struct LogParser {

    enum NoteType: String {
        case main
        case target
        case step
    }

    enum BuildCategoryType: String {
        case noop
        case incremental
        case clean
    }

    struct BuildCategorisation {
        let buildCategory: BuildCategoryType
        let buildCompiledCount: Int
        let targetsCategory: [String: BuildCategoryType]
        let targetsCompiledCount: [String: Int]
    }

    static func parseFromURL(
        _ url: URL,
        machineName: String,
        projectName: String,
        userId: String,
        userIdSHA256: String,
        isCI: Bool,
        sleepTime: Int?,
        skipNotes: Bool?
    ) throws -> BuildMetrics {
        let activityLog = try ActivityParser().parseActivityLogInURL(url, redacted: true, withoutBuildSpecificInformation: true)
        let buildSteps = try ParserBuildSteps(machineName: machineName,
                                              omitWarningsDetails: false,
                                              omitNotesDetails: skipNotes ?? false)
            .parse(activityLog: activityLog)
            .flatten()
        return toBuildMetrics(
            buildSteps,
            projectName: projectName,
            userId: userId,
            userIdSHA256: userIdSHA256,
            isCI: isCI,
            sleepTime: sleepTime
        )
    }

    private static func toBuildMetrics(
        _ buildSteps: [BuildStep],
        projectName: String,
        userId: String,
        userIdSHA256: String,
        isCI: Bool,
        sleepTime: Int?
    ) -> BuildMetrics {
        let buildInfo: BuildStep = buildSteps[0]
        var build = Build().withBuildStep(buildStep: buildInfo)
        build.projectName = projectName
        build.userid = userId
        build.userid256 = userIdSHA256
        build.tag = ""
        build.isCi = isCI

        if let sleepTime = sleepTime {
            build.wasSuspended = Int64(round(buildInfo.startTimestamp)) < sleepTime
        } else {
            build.wasSuspended = false
        }

        let targetBuildSteps = buildSteps.filter { $0.type == .target }
        var targets = targetBuildSteps.map { step in
            return Target().withBuildStep(buildStep: step)
        }
        let steps = buildSteps.filter { $0.type == .detail && $0.detailStepType != .swiftAggregatedCompilation }

        let detailsBuild = steps.filter { $0.detailStepType != .swiftCompilation }.map {
            return Step().withBuildStep(buildStep: $0,
                                        buildIdentifier: buildSteps[0].identifier,
                                        targetIdentifier: $0.parentIdentifier)
        }
        var stepsBuild = detailsBuild + parseSwiftSteps(buildSteps: buildSteps, targets: targetBuildSteps, steps: steps)

        // Categorize build based on all build steps in the build log except non-compilation or linking phases.
        // Some tasks are ran by Xcode always, even on noop builds, so we want to filter them out and only
        // consider the compilation and linking steps for our categorisation.
        let buildCategorisation = parseBuildCategory(
            with: targets,
            steps: stepsBuild.filter { $0.type != "other" && $0.type != "scriptExecution" && $0.type != "copySwiftLibs" }
        )

        targets = targets.map { target -> Target in
            let category = buildCategorisation.targetsCategory[target.id ?? ""]?.rawValue
            let count = buildCategorisation.targetsCompiledCount[target.id ?? ""]
            if let category = category, let count = count {
                return target
                    .withCategory(category)
                    .withCompiledCount(Int32(count))
            } else if let category = category {
                return target
                    .withCategory(category)
            } else if let count = count {
                return target
                    .withCompiledCount(Int32(count))
            }
            return target
        }

        // TODO: pass the HardwareFactsFetcherImplementation().sleepTime from the client
        build = build
        .withCategory(buildCategorisation.buildCategory.rawValue)
        .withCompiledCount(Int32(buildCategorisation.buildCompiledCount))

        stepsBuild.sort {
            if $0.targetIdentifier == $1.targetIdentifier {
                return $0.startTimestamp > $1.startTimestamp
            }
            return $0.targetIdentifier > $1.targetIdentifier
        }

        let warnings = parseWarnings(buildSteps: buildSteps, targets: targetBuildSteps, steps: steps)
        let errors = parseErrors(buildSteps: buildSteps, targets: targetBuildSteps, steps: steps)
        let notes = parseNotes(buildSteps: buildSteps, targets: targetBuildSteps, steps: steps)

        let functionBuildTimes = steps.compactMap { step in
            step.swiftFunctionTimes?.map {
                SwiftFunction()
                    .withBuildIdentifier(build.id ?? "")
                    .withStepIdentifier(step.identifier)
                    .withFunctionTime($0)
            }
        }.joined()

        let typeChecks = steps.compactMap { step in
            step.swiftTypeCheckTimes?.map {
                SwiftTypeChecks()
                    .withBuildIdentifier(build.id ?? "")
                    .withStepIdentifier(step.identifier)
                    .withTypeCheck($0)
            }
        }.joined()

        return BuildMetrics(build: build,
                            targets: targets,
                            steps: stepsBuild,
                            warnings: warnings,
                            errors: errors,
                            notes: notes,
                            swiftFunctions: Array(functionBuildTimes),
                            swiftTypeChecks: Array(typeChecks),
                            host: fakeHost(buildIdentifier: build.id ?? ""), // TODO
                            xcodeVersion: nil, // TODO
                            buildMetadata: nil) // TODO
                            .addDayToMetrics()
    }

    private static func parseSwiftSteps(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [Step] {
        let buildIdentifier = buildSteps[0].identifier
        let swiftAggregatedSteps = buildSteps.filter { $0.type == .detail
            && $0.detailStepType == .swiftAggregatedCompilation }

        let swiftAggregatedStepsIds = swiftAggregatedSteps.reduce([String: String]()) {
            dictionary, step -> [String: String] in
            return dictionary.merging(zip([step.identifier], [step.parentIdentifier])) { (_, new) in new }
        }

        let targetsIds = targets.reduce([String: String]()) {
            dictionary, target -> [String: String] in
            return dictionary.merging(zip([target.identifier], [target.identifier])) { (_, new) in new }
        }

        return steps
            .filter { $0.detailStepType == .swiftCompilation }
            .compactMap { step -> Step? in
                var targetId = step.parentIdentifier
                // A swift step can have either a target as a parent or a swiftAggregatedCompilation
                if targetsIds[step.parentIdentifier] == nil {
                    // If the parent is a swiftAggregatedCompilation we use the target id from that parent step
                    guard let swiftTargetId = swiftAggregatedStepsIds[step.parentIdentifier] else {
                        return nil
                    }
                    targetId = swiftTargetId
                }
                return Step().withBuildStep(buildStep: step, buildIdentifier: buildIdentifier, targetIdentifier: targetId)

        }
    }

    private static func parseBuildCategory(with targets: [Target], steps: [Step]) -> BuildCategorisation {
        var targetsCompiledCount = [String: Int]()
        // Initialize map with all targets identifiers.
        for target in targets {
            targetsCompiledCount[target.id ?? ""] = 0
        }
        // Compute how many steps were not fetched from cache for each target.
        for step in steps {
            if !step.fetchedFromCache {
                targetsCompiledCount[step.targetIdentifier, default: 0] += 1
            }
        }

        // Compute how many steps in total were not fetched from cache.
        let buildCompiledCount = Array<Int>(targetsCompiledCount.values).reduce(0, +)
        // Classify each target based on how many steps were not fetched from cache and how many are actually present.
        var targetsCategory = [String: BuildCategoryType]()
        for (target, filesCompiledCount) in targetsCompiledCount {
            // If the number of steps not fetched from cache in 0, it was a noop build.
            // If the number of steps not fetched from cache is equal to the number of all steps in the target, it was a clean build.
            // If anything in between, it was an incremental build.
            // There's an edge case where some external run script phases don't have any files compiled and are classified
            // as noop, but we're fine with that since further down we classify a clean build if at least 50% of the targets
            // were built cleanly.
            switch filesCompiledCount {
            case 0: targetsCategory[target] = .noop
            case steps.filter { $0.targetIdentifier == target }.count: targetsCategory[target] = .clean
            default: targetsCategory[target] = .incremental
            }
        }

        // If all targets are noop, we categorise the build as noop.
        let isNoopBuild = Array<BuildCategoryType>(targetsCategory.values).allSatisfy { $0 == .noop }
        // If at least 50% of the targets are clean, we categorise the build as clean.
        let isCleanBuild = Array<BuildCategoryType>(targetsCategory.values).filter { $0 == .clean }.count > targets.count / 2
        let buildCategory: BuildCategoryType
        if isCleanBuild {
            buildCategory = .clean
        } else if isNoopBuild {
            buildCategory = .noop
        } else {
            buildCategory = .incremental
        }
        return BuildCategorisation(
            buildCategory: buildCategory,
            buildCompiledCount: buildCompiledCount,
            targetsCategory: targetsCategory,
            targetsCompiledCount: targetsCompiledCount
        )
    }

    private static func parseWarnings(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [BuildWarning] {
        let buildIdentifier = buildSteps[0].identifier
        let buildWarnings = buildSteps[0].warnings?.map {
            BuildWarning()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
        }

        let targetWarnings = targets.compactMap { target in
            target.warnings?.map {
                BuildWarning()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
            }
        }.joined()

        let stepsWarnings = steps.compactMap { step in
            step.warnings?.map {
                BuildWarning()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
            }
        }.joined()
        return (buildWarnings ?? []) + targetWarnings + stepsWarnings
    }

    private static func parseErrors(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [BuildError] {
        let buildIdentifier = buildSteps[0].identifier

        let buildErrors = buildSteps[0].errors?.map {
            BuildError()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
        }

        let targetErrors = targets.compactMap { target in
            target.errors?.map {
                BuildError()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
            }
        }.joined()

        let stepsErrors = steps.compactMap { step in
            step.errors?.map {
                BuildError()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
            }
        }.joined()
        return (buildErrors ?? []) + targetErrors + stepsErrors
    }

    private static func parseNotes(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [BuildNote] {
        let buildIdentifier = buildSteps[0].identifier

        let buildNotes = buildSteps[0].notes?.map {
            BuildNote()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
        }

        let targetNotes = targets.compactMap { target in
            target.notes?.map {
                BuildNote()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
            }
        }.joined()

        let stepsNotes = steps.compactMap { step in
            step.notes?.map {
                BuildNote()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
            }
        }.joined()
        return (buildNotes ?? []) + targetNotes + stepsNotes
    }

    private static func fakeHost(buildIdentifier: String) -> BuildHost {
        let host = BuildHost()
        host.buildIdentifier = buildIdentifier
        host.cpuCount = 2
        host.cpuModel = "model"
        host.cpuSpeedGhz = 3.0
        host.hostArchitecture = "x86"
        host.hostModel = "model"
        host.hostOs = "MacOS"
        host.hostOsFamily = ""
        host.hostOsVersion = ""
        host.isVirtual = false
        host.memoryFreeMb = 0.0
        host.memoryTotalMb = 0.0
        host.swapFreeMb = 0.0
        host.swapTotalMb = 0.0
        host.timezone = "CET"
        host.uptimeSeconds = 0
        return host

    }
}

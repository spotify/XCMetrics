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

import CryptoSwift
import Foundation
import XCLogParser

protocol LogParser {
    /// Parse the log at the given URL and returns Protobuf objects that can be sent to the backend service for processing and storage.
    /// - Parameter logURL: The URL of a log to process
    /// - Parameter projectName: The name of the project for the logs.
    /// - Parameter userID: The userID of the current user.
    /// - Parameter completion: The block invoked on completion. It contains a metric request ready to be sent to the backend if successfull
    func parseLog(at logURL: URL, projectName: String, isCI: Bool, userID: String, completion: @escaping (Result<UploadBuildMetricsRequest, Swift.Error>) -> Void)

    /// Parse flat BuildSteps and returns Protobuf objects that can be sent to the backend service for processing and storage.
    /// - Parameter buildSteps: array of raw BuildSteps to parse.
    /// - Parameter projectName: The name of the project for the logs.
    /// - Parameter userID: The userID of the current user.
    func parseBuildSteps(_ buildSteps: [BuildStep], projectName: String, isCI: Bool, userID: String) -> UploadBuildMetricsRequest
}

class LogParserImplementation: LogParser {

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

    // This defines the current version of the log format.
    // In the future, we may introduce some new fields and update the backend service to conditionally do some actions
    // based on the version of the payload.
    private let logVersion = 1
    private let machineNameReader: MachineNameReader
    private let dispatchQueue = DispatchQueue(label: "com.spotify.xcmetricsapp.logparser", qos: .default, attributes: [.concurrent])

    init(machineNameReader: MachineNameReader = HashedMacOSMachineNameReader()) {
        self.machineNameReader = machineNameReader
    }

    func parseLog(at logURL: URL, projectName: String, isCI: Bool, userID: String, completion: @escaping (Result<UploadBuildMetricsRequest, Swift.Error>) -> Void) {
        dispatchQueue.async {
            do {
                let activityLog = try ActivityParser().parseActivityLogInURL(logURL, redacted: true, withoutBuildSpecificInformation: true)
                let buildSteps = try ParserBuildSteps(machineName: self.machineNameReader.machineName,
                                                      omitWarningsDetails: false,
                                                      omitNotesDetails: false)
                    .parse(activityLog: activityLog).flatten()
                let uploadRequest = self.parseBuildSteps(buildSteps, projectName: projectName, isCI: isCI, userID: userID)
                completion(.success(uploadRequest))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func parseBuildSteps(_ buildSteps: [BuildStep], projectName: String, isCI: Bool, userID: String) -> UploadBuildMetricsRequest {
        let buildBuilder = BuildBuilder()
            .withBuildStep(buildSteps[0])
            .withProjectName(projectName)
            .withIsCi(isCI)
            .withUserID(userID.md5())
            .withUserID256(userID.sha256())

        let targets = buildSteps.filter { $0.type == .target }
        let steps = buildSteps.filter { $0.type == .detail && $0.detailStepType != .swiftAggregatedCompilation }

        let targetsBuilder = targets.map { TargetBuilder().withBuildStep($0) }

        let detailsBuild = steps.filter { $0.detailStepType != .swiftCompilation }.map {
            StepBuilder()
                .withBuildIdentifier(buildSteps[0].identifier)
                .withTargetIdentifier($0.parentIdentifier)
                .withBuildStep($0)
                .build()
        }

        var stepsBuild = detailsBuild + parseSwiftSteps(buildSteps: buildSteps, targets: targets, steps: steps)

        // Categorize build based on all build steps in the build log except non-compilation or linking phases.
        // Some tasks are ran by Xcode always, even on noop builds, so we want to filter them out and only
        // consider the compilation and linking steps for our categorisation.
        let buildCategorisation = parseBuildCategory(
            with: targetsBuilder,
            stepsBuild: stepsBuild.filter { $0.type != "other" && $0.type != "scriptExecution" && $0.type != "copySwiftLibs" }
        )
        let targetsBuild = targetsBuilder.map { target -> TargetBuild in
            let category = buildCategorisation.targetsCategory[target.identifier]?.rawValue
            let count = buildCategorisation.targetsCompiledCount[target.identifier]
            if let category = category, let count = count {
                return target
                    .withCategory(category)
                    .withCompiledCount(count)
                    .build()
            } else if let category = category {
                return target
                    .withCategory(category)
                    .build()
            } else if let count = count {
                return target
                    .withCompiledCount(count)
                    .build()
            } else {
                return target.build()
            }
        }

        let build = buildBuilder
            .withWasSuspended(buildBuilder.startTimestamp < HardwareFactsFetcherImplementation().sleepTime)
            .withCategory(buildCategorisation.buildCategory.rawValue)
            .withCompiledCount(buildCategorisation.buildCompiledCount)
            .build()

        stepsBuild.sort {
            if $0.targetIdentifier == $1.targetIdentifier {
                return $0.startTimestamp > $1.startTimestamp
            }
            return $0.targetIdentifier > $1.targetIdentifier
        }

        let warnings = parseWarnings(buildSteps: buildSteps, targets: targets, steps: steps)
        let errors = parseErrors(buildSteps: buildSteps, targets: targets, steps: steps)
        let notes = parseNotes(buildSteps: buildSteps, targets: targets, steps: steps)

        let functionBuildTimes = steps.compactMap { step in
            step.swiftFunctionTimes?.map {
                FunctionBuilder()
                    .withBuildIdentifier(build.identifier)
                    .withStepIdentifier(step.identifier)
                    .withFunctionTime($0)
                    .build()
            }
        }.joined()

        let typeChecks = steps.compactMap { step in
            step.swiftTypeCheckTimes?.map {
                SwiftTypeCheckBuilder()
                    .withBuildIdentifier(build.identifier)
                    .withStepIdentifier(step.identifier)
                    .withTypeCheck($0)
                    .build()
            }
        }.joined()

        return XCMetricsBuilder()
            .withVersion(logVersion)
            .withBuild(build)
            .withTargets(targetsBuild)
            .withSteps(stepsBuild)
            .withFunctions(Array(functionBuildTimes))
            .withErrors(errors)
            .withWarnings(warnings)
            .withNotes(notes)
            .withSwiftTypeChecks(Array(typeChecks))
            .build()
    }

    private func parseSwiftSteps(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [StepBuild] {
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
            .compactMap { step -> StepBuild? in
                var targetId = step.parentIdentifier
                // A swift step can have either a target as a parent or a swiftAggregatedCompilation
                if targetsIds[step.parentIdentifier] == nil {
                    // If the parent is a swiftAggregatedCompilation we use the target id from that parent step
                    guard let swiftTargetId = swiftAggregatedStepsIds[step.parentIdentifier] else {
                        return nil
                    }
                    targetId = swiftTargetId
                }
                return StepBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withTargetIdentifier(targetId)
                    .withBuildStep(step)
                    .build()
        }
    }

    private func parseWarnings(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [WarningBuild] {
        let buildIdentifier = buildSteps[0].identifier
        let buildWarnings = buildSteps[0].warnings?.map {
            WarningBuilder()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
                .build()
        }

        let targetWarnings = targets.compactMap { target in
            target.warnings?.map {
                WarningBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()

        let stepsWarnings = steps.compactMap { step in
            step.warnings?.map {
                WarningBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()
        return (buildWarnings ?? []) + targetWarnings + stepsWarnings
    }

    private func parseErrors(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [ErrorBuild] {
        let buildIdentifier = buildSteps[0].identifier

        let buildErrors = buildSteps[0].errors?.map {
            ErrorBuilder()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
                .build()
        }

        let targetErrors = targets.compactMap { target in
            target.errors?.map {
                ErrorBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()

        let stepsErrors = steps.compactMap { step in
            step.errors?.map {
                ErrorBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()
        return (buildErrors ?? []) + targetErrors + stepsErrors
    }

    private func parseNotes(
        buildSteps: [BuildStep],
        targets: [BuildStep],
        steps: [BuildStep]
    ) -> [NoteBuild] {
        let buildIdentifier = buildSteps[0].identifier

        let buildNotes = buildSteps[0].notes?.map {
            NoteBuilder()
                .withBuildIdentifier(buildIdentifier)
                .withParentIdentifier(buildIdentifier)
                .withParentType(NoteType.main.rawValue)
                .withNotice($0)
                .build()
        }

        let targetNotes = targets.compactMap { target in
            target.notes?.map {
                NoteBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(target.identifier)
                    .withParentType(NoteType.target.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()

        let stepsNotes = steps.compactMap { step in
            step.notes?.map {
                NoteBuilder()
                    .withBuildIdentifier(buildIdentifier)
                    .withParentIdentifier(step.identifier)
                    .withParentType(NoteType.step.rawValue)
                    .withNotice($0)
                    .build()
            }
        }.joined()
        return (buildNotes ?? []) + targetNotes + stepsNotes
    }

    private func parseBuildCategory(with targetsBuilders: [TargetBuilder], stepsBuild: [StepBuild]) -> BuildCategorisation {
        var targetsCompiledCount = [String: Int]()
        // Initialize map with all targets identifiers.
        for target in targetsBuilders {
            targetsCompiledCount[target.identifier] = 0
        }
        // Compute how many steps were not fetched from cache for each target.
        for step in stepsBuild {
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
            case stepsBuild.filter { $0.targetIdentifier == target }.count: targetsCategory[target] = .clean
            default: targetsCategory[target] = .incremental
            }
        }

        // If all targets are noop, we categorise the build as noop.
        let isNoopBuild = Array<BuildCategoryType>(targetsCategory.values).allSatisfy { $0 == .noop }
        // If at least 50% of the targets are clean, we categorise the build as clean.
        let isCleanBuild = Array<BuildCategoryType>(targetsCategory.values).filter { $0 == .clean }.count > targetsBuilders.count / 2
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
}

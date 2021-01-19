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

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_Build
class BuildBuilder {

    var startTimestamp: Int64 {
        xcmetricsBuild.startTimestamp
    }

    private var xcmetricsBuild = Build()

    func withProjectName(_ projectName: String) -> BuildBuilder {
        xcmetricsBuild.projectName = projectName
        return self
    }

    func withUserID(_ userID: String) -> BuildBuilder {
        xcmetricsBuild.userid = userID
        return self
    }

    func withUserID256(_ userID256: String) -> BuildBuilder {
        xcmetricsBuild.userid256 = userID256
        return self
    }

    func withIsCi(_ isCi: Bool) -> BuildBuilder {
        xcmetricsBuild.isCi = isCi
        return self
    }

    func withCategory(_ category: String) -> BuildBuilder {
        xcmetricsBuild.category = category
        return self
    }

    func withCompiledCount(_ compiledCount: Int) -> BuildBuilder {
        xcmetricsBuild.compiledCount = Int32(compiledCount)
        return self
    }

    func withWasSuspended(_ wasSuspended: Bool) -> BuildBuilder {
        xcmetricsBuild.wasSuspended = wasSuspended
        return self
    }

    func withBuildStep(_ buildStep: BuildStep) -> BuildBuilder {
        xcmetricsBuild.identifier = buildStep.identifier
        xcmetricsBuild.machineName = buildStep.machineName
        xcmetricsBuild.schema = buildStep.schema
        xcmetricsBuild.startTimestamp = Int64(round(buildStep.startTimestamp))
        xcmetricsBuild.endTimestamp = Int64(round(buildStep.endTimestamp))
        xcmetricsBuild.startTimestampMicroseconds = buildStep.startTimestamp
        xcmetricsBuild.endTimestampMicroseconds = buildStep.endTimestamp
        xcmetricsBuild.duration = buildStep.duration.roundToDecimal(9)
        xcmetricsBuild.buildStatus = buildStep.buildStatus
        xcmetricsBuild.warningCount = Int32(buildStep.warningCount)
        xcmetricsBuild.errorCount = Int32(buildStep.errorCount)
        xcmetricsBuild.compilationEndTimestamp = Int64(round(buildStep.compilationEndTimestamp))
        xcmetricsBuild.compilationEndTimestampMicroseconds = buildStep.compilationEndTimestamp
        xcmetricsBuild.compilationDuration = buildStep.compilationDuration.roundToDecimal(9)
        return self
    }

    func build() -> Build {
        return xcmetricsBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_TargetBuild
class TargetBuilder {

    var fetchedFromCache: Bool {
        return targetBuild.fetchedFromCache
    }

    var identifier: String {
        return targetBuild.identifier
    }

    private var targetBuild = TargetBuild()

    func withCategory(_ category: String) -> TargetBuilder {
        targetBuild.category = category
        return self
    }

    func withCompiledCount(_ compiledCount: Int) -> TargetBuilder {
        targetBuild.compiledCount = Int32(compiledCount)
        return self
    }

    func withBuildStep(_ buildStep: BuildStep) -> TargetBuilder {
        targetBuild.identifier = buildStep.identifier
        targetBuild.buildIdentifier = buildStep.parentIdentifier
        targetBuild.name = buildStep.title.replacingOccurrences(of: "Build target ", with: "")
        targetBuild.startTimestamp = Int64(round(buildStep.startTimestamp))
        targetBuild.endTimestamp = Int64(round(buildStep.endTimestamp))
        targetBuild.startTimestampMicroseconds = buildStep.startTimestamp
        targetBuild.endTimestampMicroseconds = buildStep.endTimestamp
        targetBuild.duration = buildStep.duration.roundToDecimal(9)
        targetBuild.warningCount = Int32(buildStep.warningCount)
        targetBuild.errorCount = Int32(buildStep.errorCount)
        targetBuild.fetchedFromCache = buildStep.fetchedFromCache
        targetBuild.compilationEndTimestamp = Int64(round(buildStep.compilationEndTimestamp))
        targetBuild.compilationEndTimestampMicroseconds = buildStep.compilationEndTimestamp
        targetBuild.compilationDuration = buildStep.compilationDuration.roundToDecimal(9)
        return self
    }

    func build() -> TargetBuild {
        return targetBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_StepBuild
class StepBuilder {

    private var stepBuild = StepBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> StepBuilder {
        stepBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withTargetIdentifier(_ targetIdentifier: String) -> StepBuilder {
        stepBuild.targetIdentifier = targetIdentifier
        return self
    }

    func withBuildStep(_ buildStep: BuildStep) -> StepBuilder {
        stepBuild.identifier = buildStep.identifier
        stepBuild.title = buildStep.title
        stepBuild.signature = buildStep.signature
        stepBuild.type = buildStep.detailStepType.rawValue
        stepBuild.architecture = buildStep.architecture
        stepBuild.documentURL = buildStep.documentURL
        stepBuild.startTimestamp = Int64(round(buildStep.startTimestamp))
        stepBuild.endTimestamp = Int64(round(buildStep.endTimestamp))
        stepBuild.startTimestampMicroseconds = buildStep.startTimestamp
        stepBuild.endTimestampMicroseconds = buildStep.endTimestamp
        stepBuild.duration = buildStep.duration.roundToDecimal(9)
        stepBuild.warningCount = Int32(buildStep.warningCount)
        stepBuild.errorCount = Int32(buildStep.errorCount)
        stepBuild.fetchedFromCache = buildStep.fetchedFromCache
        return self
    }

    func build() -> StepBuild {
        return stepBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_FunctionBuild
class FunctionBuilder {

    private var functionBuild = FunctionBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> FunctionBuilder {
        functionBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withStepIdentifier(_ stepIdentifier: String) -> FunctionBuilder {
        functionBuild.stepIdentifier = stepIdentifier
        return self
    }

    func withFunctionTime(_ functionTime: SwiftFunctionTime) -> FunctionBuilder {
        functionBuild.file = functionTime.file
        functionBuild.startingLine = Int32(functionTime.startingLine)
        functionBuild.startingColumn = Int32(functionTime.startingColumn)
        functionBuild.signature = functionTime.signature
        functionBuild.duration = functionTime.durationMS
        functionBuild.occurrences = Int32(functionTime.occurrences)
        return self
    }

    func build() -> FunctionBuild {
        return functionBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_WarningBuild
class WarningBuilder {

    private var warningBuild = WarningBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> WarningBuilder {
        warningBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withParentIdentifier(_ parentIdentifier: String) -> WarningBuilder {
        warningBuild.parentIdentifier = parentIdentifier
        return self
    }

    func withParentType(_ parentType: String) -> WarningBuilder {
        warningBuild.parentType = parentType
        return self
    }

    func withNotice(_ notice: Notice) -> WarningBuilder {
        warningBuild.title = notice.title
        warningBuild.type = notice.type.rawValue
        warningBuild.documentURL = notice.documentURL
        warningBuild.clangFlag = notice.clangFlag ?? ""
        warningBuild.severity = Int32(notice.severity)
        warningBuild.startingLine = Int32.fromUInt64(notice.startingLineNumber)
        warningBuild.endingLine = Int32.fromUInt64(notice.endingLineNumber)
        warningBuild.startingColumn = Int32.fromUInt64(notice.startingColumnNumber)
        warningBuild.endingColumn = Int32.fromUInt64(notice.endingColumnNumber)
        warningBuild.characterRangeStart = Int32.fromUInt64(notice.characterRangeStart)
        warningBuild.characterRangeEnd = Int32.fromUInt64(notice.characterRangeEnd)
        return self
    }

    func build() -> WarningBuild {
        return warningBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_ErrorBuild
class ErrorBuilder {

    private var errorBuild = ErrorBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> ErrorBuilder {
        errorBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withParentIdentifier(_ parentIdentifier: String) -> ErrorBuilder {
        errorBuild.parentIdentifier = parentIdentifier
        return self
    }

    func withParentType(_ parentType: String) -> ErrorBuilder {
        errorBuild.parentType = parentType
        return self
    }


    func withNotice(_ notice: Notice) -> ErrorBuilder {
        errorBuild.title = notice.title
        errorBuild.type = notice.type.rawValue
        errorBuild.documentURL = notice.documentURL
        errorBuild.severity = Int32(notice.severity)
        errorBuild.startingLine = Int32.fromUInt64(notice.startingLineNumber)
        errorBuild.endingLine = Int32.fromUInt64(notice.endingLineNumber)
        errorBuild.startingColumn = Int32.fromUInt64(notice.startingColumnNumber)
        errorBuild.endingColumn = Int32.fromUInt64(notice.endingColumnNumber)
        errorBuild.endingColumn = Int32.fromUInt64(notice.endingColumnNumber)
        errorBuild.characterRangeStart = Int32.fromUInt64(notice.characterRangeStart)
        errorBuild.characterRangeEnd = Int32.fromUInt64(notice.characterRangeEnd)
        return self
    }

    func build() -> ErrorBuild {
        return errorBuild
    }

}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_NoteBuild
class NoteBuilder {

    private var noteBuild = NoteBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> NoteBuilder {
        noteBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withParentIdentifier(_ parentIdentifier: String) -> NoteBuilder {
        noteBuild.parentIdentifier = parentIdentifier
        return self
    }

    func withParentType(_ parentType: String) -> NoteBuilder {
        noteBuild.parentType = parentType
        return self
    }

    func withNotice(_ notice: Notice) -> NoteBuilder {
        noteBuild.title = notice.title
        noteBuild.documentURL = notice.documentURL
        noteBuild.severity = Int32(notice.severity)
        noteBuild.startingLine = Int32.fromUInt64(notice.startingLineNumber)
        noteBuild.endingLine = Int32.fromUInt64(notice.endingLineNumber)
        noteBuild.startingColumn = Int32.fromUInt64(notice.startingColumnNumber)
        noteBuild.endingColumn = Int32.fromUInt64(notice.endingColumnNumber)
        noteBuild.characterRangeStart = Int32.fromUInt64(notice.characterRangeStart)
        noteBuild.characterRangeEnd = Int32.fromUInt64(notice.characterRangeEnd)
        return self
    }

    func build() -> NoteBuild {
        return noteBuild
    }

}

class XCMetricsBuilder {

    private var request = UploadBuildMetricsRequest()

    func withVersion(_ version: Int) -> XCMetricsBuilder {
        request.version = Int32(version)
        return self
    }

    func withBuild(_ build: Build) -> XCMetricsBuilder {
        request.build = build
        return self
    }

    func withTargets(_ targets: [TargetBuild]) -> XCMetricsBuilder {
        request.targets = targets
        return self
    }

    func withSteps(_ steps: [StepBuild]) -> XCMetricsBuilder {
        request.steps = steps
        return self
    }

    func withFunctions(_ functions: [FunctionBuild]) -> XCMetricsBuilder {
        request.functions = functions
        return self
    }

    func withWarnings(_ warnings: [WarningBuild]) -> XCMetricsBuilder {
        request.warnings = warnings
        return self
    }

    func withErrors(_ errors: [ErrorBuild]) -> XCMetricsBuilder {
        request.errors = errors
        return self
    }

    func withNotes(_ notes: [NoteBuild]) -> XCMetricsBuilder {
        request.notes = notes
        return self
    }

    func withBuildHost(_ buildHost: BuildHost) -> XCMetricsBuilder {
        request.buildHost = buildHost
        return self
    }

    func withXcodeVersion(_ xcodeVersion: XcodeVersion) -> XCMetricsBuilder {
        request.xcodeVersion = xcodeVersion
        return self
    }

    func withBuildMetadata(_ buildMetadata: BuildMetadata) -> XCMetricsBuilder {
        request.buildMetadata = buildMetadata
        return self
    }

    func withSwiftTypeChecks(_ swiftTypeChecks: [SwiftTypeCheckBuild]) -> XCMetricsBuilder {
        request.typeChecks = swiftTypeChecks
        return self
    }

    func withOtherMetrics(_ other: UploadBuildMetricsRequest) -> XCMetricsBuilder {
        request.build = other.build
        request.errors = other.errors
        request.functions = other.functions
        request.buildHost = other.buildHost
        request.notes = other.notes
        request.buildMetadata = other.buildMetadata
        request.steps = other.steps
        request.targets = other.targets
        request.warnings = other.warnings
        request.version = other.version
        request.typeChecks = other.typeChecks
        return self
    }

    func build() -> UploadBuildMetricsRequest {
        return request
    }
}

/// Builder for the generated protobuf class Com_Spotify_Xcmetrics_TypeCheckBuild
class SwiftTypeCheckBuilder {

    private var swiftTypeCheckBuild = SwiftTypeCheckBuild()

    func withBuildIdentifier(_ buildIdentifier: String) -> SwiftTypeCheckBuilder {
        swiftTypeCheckBuild.buildIdentifier = buildIdentifier
        return self
    }

    func withStepIdentifier(_ stepIdentifier: String) -> SwiftTypeCheckBuilder {
        swiftTypeCheckBuild.stepIdentifier = stepIdentifier
        return self
    }

    func withTypeCheck(_ typeCheck: SwiftTypeCheck) -> SwiftTypeCheckBuilder {
        swiftTypeCheckBuild.file = typeCheck.file
        swiftTypeCheckBuild.startingLine = Int32(typeCheck.startingLine)
        swiftTypeCheckBuild.startingColumn = Int32(typeCheck.startingColumn)
        swiftTypeCheckBuild.duration = typeCheck.durationMS
        swiftTypeCheckBuild.occurrences = Int32(typeCheck.occurrences)
        return self
    }

    func build() -> SwiftTypeCheckBuild {
        return swiftTypeCheckBuild
    }

}

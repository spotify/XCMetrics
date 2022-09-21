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

import XCLogParser

extension BuildStep {
    func with(type: BuildStepType? = nil, machineName: String? = nil,
              buildIdentifier: String? = nil,
              identifier: String? = nil,
              parentIdentifier: String? = nil,
              domain: String? = nil,
              title: String? = nil,
              signature: String? = nil,
              startDate: String? = nil,
              endDate: String? = nil,
              startTimestamp: Double? = nil,
              endTimestamp: Double? = nil,
              duration: Double? = nil,
              detailStepType:DetailStepType? = nil,
              buildStatus: String? = nil,
              schema: String? = nil,
              subSteps : [BuildStep]? = nil,
              warningCount: Int? = nil,
              errorCount: Int? = nil,
              architecture: String? = nil,
              documentURL: String? = nil,
              warnings: [Notice]? = nil,
              errors: [Notice]? = nil,
              notes: [Notice]? = nil,
              swiftFunctionTimes: [SwiftFunctionTime]? = nil,
              fetchedFromCache: Bool? = nil,
              compilationEndTimestamp: Double? = nil,
              compilationDuration: Double? = nil) -> BuildStep {
        return BuildStep(type: type ?? self.type,
                         machineName: machineName ?? self.machineName,
                         buildIdentifier: buildIdentifier ?? self.buildIdentifier,
                         identifier: identifier ?? self.identifier,
                         parentIdentifier: parentIdentifier ?? self.parentIdentifier,
                         domain: domain ?? self.domain,
                         title: title ?? self.title,
                         signature: signature ?? self.signature,
                         startDate: startDate ?? self.startDate,
                         endDate: endDate ?? self.endDate,
                         startTimestamp: startTimestamp ?? self.startTimestamp,
                         endTimestamp: endTimestamp ?? self.endTimestamp,
                         duration: duration ?? self.duration,
                         detailStepType: detailStepType ?? self.detailStepType,
                         buildStatus: buildStatus ?? self.buildStatus,
                         schema: schema ?? self.schema,
                         subSteps: subSteps ?? self.subSteps,
                         warningCount: warningCount ?? self.warningCount,
                         errorCount: errorCount ?? self.errorCount,
                         architecture: architecture ?? self.architecture,
                         documentURL: documentURL ?? self.documentURL,
                         warnings: warnings ?? self.warnings,
                         errors: errors ?? self.errors,
                         notes: notes ?? self.notes,
                         swiftFunctionTimes: swiftFunctionTimes ?? self.swiftFunctionTimes,
                         fetchedFromCache: fetchedFromCache ?? self.fetchedFromCache,
                         compilationEndTimestamp: compilationEndTimestamp ?? self.compilationEndTimestamp,
                         compilationDuration: compilationDuration ?? self.compilationDuration,
                         clangTimeTraceFile: nil,
                         linkerStatistics: nil,
                         swiftTypeCheckTimes: nil)
    }
}

extension Notice {
    func with(type: NoticeType? = nil,
              title: String? = nil,
              clangFlag: String? = nil,
              documentURL: String? = nil,
              severity: Int? = nil,
              startingLineNumber: UInt64? = nil,
              endingLineNumber: UInt64? = nil,
              startingColumnNumber: UInt64? = nil,
              endingColumnNumber: UInt64? = nil,
              characterRangeEnd: UInt64? = nil,
              characterRangeStart: UInt64? = nil,
              interfaceBuilderIdentifier: String? = nil) -> Notice {
        return Notice(
            type: type ?? self.type,
            title: title ?? self.title,
            clangFlag: clangFlag ?? self.clangFlag,
            documentURL: documentURL ?? self.documentURL,
            severity: severity ?? self.severity,
            startingLineNumber: startingLineNumber ?? self.startingLineNumber,
            endingLineNumber: endingLineNumber ?? self.endingLineNumber,
            startingColumnNumber: startingColumnNumber ?? self.startingColumnNumber,
            endingColumnNumber: endingColumnNumber ?? self.endingColumnNumber,
            characterRangeEnd: characterRangeEnd ?? self.characterRangeEnd,
            characterRangeStart: characterRangeStart ?? self.characterRangeStart,
            interfaceBuilderIdentifier: interfaceBuilderIdentifier ?? self.interfaceBuilderIdentifier
        )
    }
}

extension BuildHost {
    func with (buildIdentifier: String? = nil,
               hostOs: String? = nil,
               hostArchitecture: String? = nil,
               hostModel: String? = nil,
               hostOsFamily: String? = nil,
               hostOsVersion: String? = nil,
               cpuModel: String? = nil,
               cpuCount: Int32? = nil,
               cpuSpeedGhz: Float? = nil,
               memoryTotalMb: Double? = nil,
               memoryFreeMb: Double? = nil,
               swapTotalMb: Double? = nil,
               swapFreeMb: Double? = nil,
               uptimeSeconds: Int64? = nil,
               timezone: String? = nil,
               isVirtual: Bool? = nil) -> BuildHost {
        var newFacts = BuildHost()
        newFacts.buildIdentifier = buildIdentifier ?? self.buildIdentifier
        newFacts.hostOs = hostOs ?? self.hostOs
        newFacts.hostArchitecture = hostArchitecture ?? self.hostArchitecture
        newFacts.hostModel = hostModel ?? self.hostModel
        newFacts.hostOsFamily = hostOsFamily ?? self.hostOsFamily
        newFacts.hostOsVersion = hostOsVersion ?? self.hostOsVersion
        newFacts.cpuModel = cpuModel ?? self.cpuModel
        newFacts.cpuCount = cpuCount ?? self.cpuCount
        newFacts.cpuSpeedGhz = cpuSpeedGhz ?? self.cpuSpeedGhz
        newFacts.memoryTotalMb = memoryTotalMb ?? self.memoryTotalMb
        newFacts.memoryFreeMb = memoryFreeMb ?? self.memoryFreeMb
        newFacts.swapTotalMb = swapTotalMb ?? self.swapTotalMb
        newFacts.swapFreeMb = swapFreeMb ?? self.swapFreeMb
        newFacts.uptimeSeconds = uptimeSeconds ?? self.uptimeSeconds
        newFacts.timezone = timezone ?? self.timezone
        newFacts.isVirtual = isVirtual ?? self.isVirtual

        return newFacts
    }
}

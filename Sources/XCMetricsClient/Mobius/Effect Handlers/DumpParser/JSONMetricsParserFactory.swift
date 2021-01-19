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

enum MetricsParserError: Error {
    case invalidFormat
    case missingKey(String)
}

struct BuildInfo {
    let step: BuildStep
    let projectName: String?
    let userID: String?
}
struct NoticeInfo {
    let notice: Notice
    let parentIdentifier: String
}

protocol MetricsParserFactory {
    func buildBuildStepParser(with: BuildStepType) -> (Data) throws -> BuildInfo
    func buildNoticeParser(defaultType: NoticeType) -> (Data) throws -> NoticeInfo
}

class JSONMetricsParserFactory: MetricsParserFactory {
    private typealias JSONRawRepresentation = [AnyHashable: Any]

    private static func parseJSON(_ data: Data) throws -> JSONRawRepresentation {
        guard let dict = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? JSONRawRepresentation
            else {
                throw MetricsParserError.invalidFormat
        }
        return dict
    }

    func buildBuildStepParser(with type: BuildStepType) -> (Data) throws -> BuildInfo {
        return { data in
            let representation = try JSONMetricsParserFactory.parseJSON(data)
            guard representation["identifier"] != nil else {
                throw MetricsParserError.missingKey("identifier")
            }
            
            let startTimestamp: Double = representation.fetch("startTimestampMicroseconds")
            let endTimestamp: Double = representation.fetch("endTimestampMicroseconds")
            let detailType = DetailStepType.init(rawValue: representation.fetch("type")) ?? .other
            // TODO: Parse FunctionTimes as well
            let step = BuildStep(type: type,
                             machineName: representation.fetch("machineName") ,
                             buildIdentifier: representation.fetch("buildIdentifier") ,
                             identifier: representation.fetch("identifier") ,
                             parentIdentifier: representation.fetch("parentIdentifier", "targetIdentifier") ,
                             domain: representation.fetch("domain") ,
                             title: representation.fetch("title", "name") ,
                             signature: representation.fetch("signature") ,
                             startDate: representation.fetch("startDate") ,
                             endDate: representation.fetch("endDate") ,
                             startTimestamp: startTimestamp,
                             endTimestamp: endTimestamp,
                             duration: endTimestamp - startTimestamp,
                             detailStepType: detailType,
                             buildStatus: representation.fetch("buildStatus"),
                             schema: representation.fetch("schema"),
                             subSteps: [],
                             warningCount: representation.fetch("warningCount"),
                             errorCount: representation.fetch("errorCount"),
                             architecture: representation.fetch("architecture"),
                             documentURL: representation.fetch("documentURL"),
                             warnings: [],
                             errors: [],
                             notes: [],
                             swiftFunctionTimes: nil,
                             fetchedFromCache: representation.fetch("fetchedFromCache"),
                             compilationEndTimestamp: representation.fetch("compilationEndTimestamp"),
                             compilationDuration: representation.fetch("compilationDuration"),
                             clangTimeTraceFile: nil,
                             linkerStatistics: nil)
            return BuildInfo(step: step,
                             projectName: representation.fetch("projectName"),
                             userID: representation.fetch("userID"))
        }
    }

    func buildNoticeParser(defaultType: NoticeType) -> (Data) throws -> NoticeInfo {
        return { data in

            let representation = try JSONMetricsParserFactory.parseJSON(data)
            guard representation["buildIdentifier"] != nil else {
                throw MetricsParserError.missingKey("buildIdentifier")
            }

            let notice = Notice(
                type: NoticeType(rawValue: representation.fetch("type")) ?? defaultType,
                title: representation.fetch("title"),
                clangFlag: representation.fetch("clangFlag"),
                documentURL: representation.fetch("documentURL"),
                severity: representation.fetch("severity"),
                startingLineNumber: representation.fetch("startingLine"),
                endingLineNumber: representation.fetch("endingLine"),
                startingColumnNumber: representation.fetch("startingColumn"),
                endingColumnNumber: representation.fetch("endingColumn"),
                characterRangeEnd: representation.fetch("characterRangeStart"),
                characterRangeStart: representation.fetch("characterRangeEnd"),
                interfaceBuilderIdentifier: representation.fetch("interfaceBuilderIdentifier")
            )
            let parentIdentifier: String = representation.fetch("parentIdentifier")
            return NoticeInfo(notice: notice,
                              parentIdentifier: parentIdentifier)
        }
    }
}

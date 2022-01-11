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

import MobiusCore
import MobiusTest
import TSCBasic
import TSCUtility
import XCTest
@testable import XCMetricsClient

extension TemporaryFile: Equatable {
    public static func == (lhs: TemporaryFile, rhs: TemporaryFile) -> Bool {
        return lhs.path == rhs.path
    }
}

extension TemporaryFile: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

let projectName = "Project Name"
let serviceURL = URL(string: "https://example.com/v1/metrics")!
let additionalHeaders = ["key": "value"]

class MetricsUploaderLogicTests: XCTestCase {

    private let spec = UpdateSpec(MetricsUploaderLogic.update)
    private let initial = MetricsUploaderModel(buildDirectory: "BUILD_DIR",
                                               projectName: projectName,
                                               serviceURL: serviceURL,
                                               additionalHeaders: additionalHeaders,
                                               timeout: 1,
                                               isCI: false,
                                               plugins: [],
                                               skipNotes: false,
                                               truncLargeIssues: false,
                                               uploadCurrentLogOnly: false)

    func testInitiator() {
        let initEffect = MetricsUploaderEffect.findLogs(buildDirectory: initial.buildDirectory, timeout: 1)
        let first = MetricsUploaderLogic.buildInitiator(with: initEffect)(initial)
        let expectedFirst = First(model: initial, effects: [initEffect])
        XCTAssertEqual(first.model, expectedFirst.model)
        XCTAssertEqual(first.effects, expectedFirst.effects)
    }

    func testFindLogs() {
        let currentLog = try! TemporaryFile.newFile(prefix: "log5", suffix: ".xcactivitylog").url
        let xcodeLog = try! TemporaryFile.newFile(prefix: "log1", suffix: ".xcactivitylog").url
        let cacheLog = try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog").url

        let xcodeLogs = Set(arrayLiteral: xcodeLog)
        let cacheLogs = Set(arrayLiteral: cacheLog)
        spec.given(initial)
            .when(.logsFound(currentLog: currentLog, xcodeLogs: xcodeLogs, cachedLogs: cacheLogs))
            .then(assertThatNext(
                hasNoModel(),
                hasEffects([MetricsUploaderEffect.cacheLogs(currentLog: currentLog, previousLogs: xcodeLogs, cachedLogs: cacheLogs, projectName: projectName)])))
    }

    func testCacheLogs() {
        let cachedLog = try! TemporaryFile.newFile(prefix: "log15", suffix: ".xcactivitylog").url
        let expectedModel = initial.withChanged(awaitingParsingLogResponses: 0)
        spec.given(initial)
            .when(.logsCached(currentLog: nil, previousLogs: Set(arrayLiteral: cachedLog), cachedUploadRequests: []))
            .then(assertThatNext(
                hasModel(expectedModel),
                hasEffects([
                    .uploadLogs(
                        serviceURL: serviceURL,
                        additionalHeaders: additionalHeaders,
                        projectName: projectName,
                        isCI: false,
                        skipNotes: false,
                        truncLargeIssues: false,
                        logs: Set([MetricsUploadRequest(fileURL: cachedLog, request: UploadBuildMetricsRequest())])
                    )
                ])
            )
        )
    }

    func testCacheLogsWithCurrentLog() {
        let cachedCurrentLog = try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog").url
        let cachedLog = try! TemporaryFile.newFile(prefix: "log15", suffix: ".xcactivitylog").url

        let expectedModel = initial.withChanged(awaitingParsingLogResponses: 0)
        spec.given(initial)
            .when(.logsCached(currentLog: cachedCurrentLog, previousLogs: [cachedLog], cachedUploadRequests: []))
            .then(assertThatNext(
                hasModel(expectedModel),
                hasEffects([
                    .appendMetadata(
                        request: MetricsUploadRequest(
                            fileURL: cachedCurrentLog,
                            request: UploadBuildMetricsRequest())
                    ),
                    .uploadLogs(
                        serviceURL: serviceURL,
                        additionalHeaders: additionalHeaders,
                        projectName: projectName,
                        isCI: false,
                        skipNotes: false,
                        truncLargeIssues: false,
                        logs: Set([
                            MetricsUploadRequest(fileURL: cachedLog, request: UploadBuildMetricsRequest())
                        ])
                    )
                ])
            )
        )
    }

    func testCacheLogsWithCurrentLogAndReturnMaximumNumberOfLogs() {
        let cachedCurrentLog = try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog").url
        let cachedLogs = Set([
            try! TemporaryFile.newFile(prefix: "log15", suffix: ".xcactivitylog").url,
            try! TemporaryFile.newFile(prefix: "log16", suffix: ".xcactivitylog").url,
            try! TemporaryFile.newFile(prefix: "log17", suffix: ".xcactivitylog").url,
            try! TemporaryFile.newFile(prefix: "log18", suffix: ".xcactivitylog").url,
        ])
        let uploadRequests = Set([
            try! MetricsUploadRequest(fileURL: URL(fileURLWithPath: "1"), request: UploadBuildMetricsRequest(jsonString: "{}")),
            try! MetricsUploadRequest(fileURL: URL(fileURLWithPath: "2"), request: UploadBuildMetricsRequest(jsonString: "{}")),
            try! MetricsUploadRequest(fileURL: URL(fileURLWithPath: "3"), request: UploadBuildMetricsRequest(jsonString: "{}")),
            try! MetricsUploadRequest(fileURL: URL(fileURLWithPath: "4"), request: UploadBuildMetricsRequest(jsonString: "{}")),
            try! MetricsUploadRequest(fileURL: URL(fileURLWithPath: "5"), request: UploadBuildMetricsRequest(jsonString: "{}"))
        ])

        let expectedModel = initial.withChanged(parsedRequests: Set(uploadRequests.prefix(3)), awaitingParsingLogResponses: 0)
        let next = MetricsUploaderLogic
            .update(model: initial, event: .logsCached(currentLog: cachedCurrentLog, previousLogs: cachedLogs, cachedUploadRequests: uploadRequests))
        XCTAssertEqual(next.model, expectedModel)
        XCTAssertEqual(next.effects.count, 2)
    }

    func testUploadLogs() {
        let uploadedLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog").url
        )
        spec.given(initial)
            .when(.logsUploaded(logs: uploadedLogs))
            .then(assertThatNext(hasEffects([.tagLogsAsUploaded(logs: uploadedLogs)])))
    }

    func testTagLogsAsUploaded() {
        let taggedLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log10_UPLOADED", suffix: ".xcactivitylog").url
        )
        spec.given(initial)
            .when(.logsTaggedAsUploaded(logs: taggedLogs))
            .then(assertThatNext(hasEffects([.cleanUpLogs])))
    }

    func testCleanUpLogs() {
        // Make sure loop completes.
        expectation(forNotification: .mobiusLoopCompleted, object: nil, handler: nil)
        let cleanedUpLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog").url
        )
        spec.given(initial)
            .when(.cleanedUpLogs(logs: cleanedUpLogs), .savedUploadRequests)
            .then(assertThatNext(hasNoEffects()))
        waitForExpectations(timeout: 5.0, handler: nil)
    }
}

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

import Basic
import MobiusCore
import Utility
import XCTest
@testable import XCMetricsClient

typealias URL = Foundation.URL

final class LogsFinderEffectHandlerTests: XCTestCase {

    struct MockLogManager: LogManager {
        var xcodeLogsURL: Set<URL> {
            return Set(xcodeLogs.map {
                URL(fileURLWithPath: $0.path.asString)
            })
        }

        var lastXcodeLogURL: URL? {
            return URL(fileURLWithPath: lastXcodeLog.path.asString)
        }

        var cachedLogsURL: Set<URL> {
            return Set(cachedLogs.map {
                URL(fileURLWithPath: $0.path.asString)
            })
        }

        private let xcodeLogs = Set(arrayLiteral:
            try! TemporaryFile(prefix: "log1", suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: "log2", suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: "log3", suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: "log4", suffix: ".xcactivitylog")
        )

        private var lastXcodeLog = try! TemporaryFile(prefix: "log5", suffix: ".xcactivitylog")

        private let cachedLogs = Set(arrayLiteral:
            try! TemporaryFile(prefix: "log10", suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: "log20", suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: "log30", suffix: ".xcactivitylog")
        )

        func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>) {
            return (lastXcodeLogURL, xcodeLogsURL)
        }

        func retrieveCachedLogs() throws -> Set<URL> {
            return cachedLogsURL
        }

        func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL> {
            return []
        }

        func retrieveLogsToUpload(cachedLogs: Set<URL>) -> [URL: URL] {
            return [:]
        }

        func evictLogs() throws -> Set<URL> {
            return []
        }

        func retrieveCachedLogsInLegacyDirectory() throws -> Set<URL> {
            []
        }

        func saveFailedRequest(url: URL, data: Data) throws -> URL {
            fatalError()
        }

        func removeUploadedFailedRequest(url: URL) throws {
        }

        func tagLogAsUploaded(logURL: URL) throws -> URL {
            fatalError()
        }

        func retrieveLogRequestsToUpload() throws -> [URL] {
            return []
        }
    }

    private var effectHandler: LogsFinderEffectHandler!
    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?

    private var mockLogManager = MockLogManager()

    override func setUp() {
        super.setUp()

        effectHandler = LogsFinderEffectHandler(logManager: mockLogManager)
        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testHandleFindLogsWithLastLogAdded() {
        send = { event in
            if case .logsFound(let currentLog, let xcodeLogs, let cachedLogs) = event {
                XCTAssertEqual(currentLog, self.mockLogManager.lastXcodeLogURL)
                XCTAssertEqual(Set(xcodeLogs), Set(self.mockLogManager.xcodeLogsURL))
                XCTAssertEqual(Set(cachedLogs), Set(self.mockLogManager.cachedLogsURL))
            } else {
                XCTFail("Expected .logsFound, got: \(event)")
            }
        }
        _ = effectHandler.handle((buildDirectory: "BUILD_DIR", timeout: 1), effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }
}

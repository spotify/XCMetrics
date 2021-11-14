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

final class UploadedLogTaggerEffectHandlerTests: XCTestCase {

    struct MockLogManager: LogManager {

        var evictedLogsURL: Set<URL> {
            return Set(evictedLogs.map {
                URL(fileURLWithPath: $0.path.pathString)
            })
        }

        private let evictedLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log20", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log30", suffix: ".xcactivitylog")
        )

        func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>) {
            return (nil,[])
        }

        func waitUntilLogExists(in buildDirectory: String) throws -> String {
            return ""
        }

        func retrieveLogsToUpload(cachedLogs: Set<URL>) -> [URL: URL] {
            return [:]
        }

        func retrieveCachedLogs() throws -> Set<URL> {
            return []
        }

        func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL> {
            return []
        }

        func evictLogs() throws -> Set<URL> {
            return evictedLogsURL
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

    private var effectHandler: UploadedLogTaggerEffectHandler!
    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?
    private var mockLogManager = MockLogManager()

    override func setUp() {
        super.setUp()

        effectHandler = UploadedLogTaggerEffectHandler(logManager: mockLogManager)
        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testTagLogsAsUploaded() {
        send = { event in
            if case .cleanedUpLogs(let cleanedUpLogs) = event {
                XCTAssertEqual(cleanedUpLogs, self.mockLogManager.evictedLogsURL)
            } else {
                XCTFail("Expected .logsTaggedAsUploaded, got: \(event)")
            }
        }
        _ = effectHandler.handle((), effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }
}

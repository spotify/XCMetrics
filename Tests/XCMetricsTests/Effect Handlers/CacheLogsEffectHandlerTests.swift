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
import XCLogParser
import XCTest
import TSCBasic
import TSCUtility
@testable import XCMetricsClient

final class CacheLogsEffectHandlerTests: XCTestCase {

    final class MockLogManager: LogManager {

        var xcodeLogsURL: Set<URL> {
            return Set(xcodeLogs.map {
                URL(fileURLWithPath: $0.path.pathString)
            })
        }

        var cachedLogsURL: Set<URL> {
            return Set(cachedLogs.map {
                URL(fileURLWithPath: $0.path.pathString)
            })
        }

        var newlyCachedLogsURL: Set<URL> {
            return Set(newlyCachedLogs.map {
                URL(fileURLWithPath: $0.path.pathString)
            })
        }

        private let xcodeLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log1", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log2", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log3", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log4", suffix: ".xcactivitylog")
        )

        private let cachedLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log10", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log20", suffix: ".xcactivitylog"),
            try! TemporaryFile.newFile(prefix: "log30", suffix: ".xcactivitylog")
        )

        private let newlyCachedLogs = Set(arrayLiteral:
            try! TemporaryFile.newFile(prefix: "log100", suffix: ".xcactivitylog")
        )

        func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>) {
            return (nil, xcodeLogsURL)
        }

        func retrieveCachedLogs() throws -> Set<URL> {
            return cachedLogsURL
        }

        func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL> {
            return xcodeLogs.subtracting(cachedLogs)
        }

        var cachedLogsInLegacyDirectory = Set<URL>()
        func retrieveCachedLogsInLegacyDirectory() throws -> Set<URL> {
            return cachedLogsInLegacyDirectory
        }

        func evictLogs() throws -> Set<URL> {
            return []
        }

        func saveFailedRequest(url: URL, data: Data) throws -> URL {
            fatalError()
        }

        func removeUploadedFailedRequest(url: URL) throws {
        }

        func tagLogAsUploaded(logURL: URL) throws -> URL {
            fatalError()
        }
        var logsToUploadToReturn = [URL]()
        func retrieveLogRequestsToUpload() throws -> [URL] {
            return logsToUploadToReturn
        }
    }

    private var effectHandler: CacheLogsEffectHandler!
    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?

    private var mockLogManager = MockLogManager()

    override func setUp() {
        super.setUp()

        effectHandler = CacheLogsEffectHandler(logManager: mockLogManager, uploadCurrentLogOnly: false)
        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testCacheLogsCachesPreviousLogs() {
        send = { event in
            if case .logsCached(let currentLog, let previousLogs, _) = event {
                XCTAssertNil(currentLog)
                XCTAssertEqual(previousLogs, self.mockLogManager.xcodeLogsURL)
            } else {
                XCTFail("Expected .logsCached, got: \(event)")
            }
        }
        _ = effectHandler.handle((currentLog: nil, previousLogs: mockLogManager.xcodeLogsURL, cachedLogs: mockLogManager.cachedLogsURL, projectName: "Project Name"), effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }

    func testCacheLogsNotCachesPreviousLogsIfUploadCurrentLogOnly() {
        effectHandler = CacheLogsEffectHandler(logManager: mockLogManager, uploadCurrentLogOnly: true)
        send = { event in
            if case .logsCached(let currentLog, let previousLogs, _) = event {
                XCTAssertNil(currentLog)
                XCTAssertEqual(previousLogs, [])
            } else {
                XCTFail("Expected .logsCached, got: \(event)")
            }
        }
        _ = effectHandler.handle((currentLog: nil, previousLogs: mockLogManager.xcodeLogsURL, cachedLogs: mockLogManager.cachedLogsURL, projectName: "Project Name"), effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }

    func testCacheLogsCachesCurrentLog() {
        let currentLogURL = try! TemporaryFile.newFile(prefix: "log1", suffix: ".xcactivitylog").url
        var receivedEvent: MetricsUploaderEvent?
        send = { receivedEvent = $0 }

        _ = effectHandler.handle((currentLog: currentLogURL, previousLogs: [], cachedLogs: mockLogManager.cachedLogsURL, projectName: "Project Name"), effectCallback)

        if case .some(.logsCached(let currentLog, let otherLogs, _)) = receivedEvent {
            XCTAssertEqual(currentLog, currentLogURL)
            XCTAssertEqual(otherLogs, [])
        } else {
            XCTFail("Expected .logsCached")
        }
        XCTAssertTrue(effectCallback.ended)
    }

    func testCacheLogsReportsNotAlreadyCachedLog() {
        let alreadyCachedLogURL = try! TemporaryFile.newFile(prefix: "log1", suffix: ".xcactivitylog").url
        let uploadRequestFileURL = alreadyCachedLogURL
            .deletingLastPathComponent()
            .appendingPathComponent(LogManagerImplementation.failedRequestsDirectoryName)
            .appendingPathComponent(alreadyCachedLogURL.lastPathComponent)

        let fakeRequest = UploadBuildMetricsRequest()
        try! FileManager.default.createDirectory(
            at: uploadRequestFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [:]
        )
        try! fakeRequest.serializedData().write(to: uploadRequestFileURL)

        mockLogManager.logsToUploadToReturn = [uploadRequestFileURL]
        var receivedEvent: MetricsUploaderEvent?
        send = { receivedEvent = $0 }

        _ = effectHandler.handle((currentLog: nil, previousLogs: [], cachedLogs: mockLogManager.cachedLogsURL, projectName: "Project Name"), effectCallback)

        if case .some(.logsCached(let currentLog, let otherLogs, let uploadRequests)) = receivedEvent {
            XCTAssertNil(currentLog)
            XCTAssertEqual(otherLogs, [])
            XCTAssertEqual(uploadRequests, [MetricsUploadRequest(fileURL: uploadRequestFileURL, request: fakeRequest)])
        } else {
            XCTFail("Expected .logsCached ")
        }
        XCTAssertTrue(effectCallback.ended)
    }
}

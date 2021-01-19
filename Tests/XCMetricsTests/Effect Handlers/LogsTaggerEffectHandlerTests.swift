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
import MobiusTest
import Utility
import XCTest
@testable import XCMetricsClient

final class LogsTaggerEffectHandlerTests: XCTestCase {

    final class MockLogManager: LogManager {

        func retrieveXcodeLogs(in buildDirectory: String, timeout: Int) throws -> (currentLog: URL?, otherLogs: Set<URL>) {
            fatalError()
        }

        func retrieveCachedLogs() throws -> Set<URL> {
            fatalError()
        }

        func cacheLogs(_ xcodeLogs: Set<URL>, cachedLogs: Set<URL>, retries: Int) throws -> Set<URL> {
            fatalError()
        }

        func retrieveLogsToUpload(cachedLogs: Set<URL>) -> [URL: URL] {
            fatalError()
        }

        func retrieveCachedLogsInLegacyDirectory() throws -> Set<URL> {
            fatalError()
        }

        func evictLogs() throws -> Set<URL> {
            fatalError()
        }

        func saveFailedRequest(url: URL, data: Data) throws -> URL {
            fatalError()
        }

        func removeUploadedFailedRequest(url: URL) throws {
        }
        var taggedLogsToReturn = [URL: URL]()
        func tagLogAsUploaded(logURL: URL) throws -> URL {
            return taggedLogsToReturn[logURL]!
        }

        func retrieveLogRequestsToUpload() throws -> [URL] {
            return []
        }
    }

    private var mockLogManager = MockLogManager()
    private var effectHandler: LogsTaggerEffectHandler!
    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?

    private var uploadedLogsURL: Set<URL> {
        return Set(uploadedLogs.map { $0.url })
    }

    private var uploadedLogs = [TemporaryFile]()
    private var uploadedTaggedLogs = [URL]()

    override func setUp() {
        super.setUp()

        uploadedLogs = [
            try! TemporaryFile(prefix: UUID().uuidString, suffix: ".xcactivitylog"),
            try! TemporaryFile(prefix: UUID().uuidString, suffix: ".xcactivitylog")
        ]

        uploadedTaggedLogs = [
            URL(fileURLWithPath: uploadedLogs[0].url.deletingPathExtension().path + "_UPLOADED.xcactivitylog"),
            URL(fileURLWithPath: uploadedLogs[1].url.deletingPathExtension().path + "_UPLOADED.xcactivitylog"),
        ]

        effectHandler = LogsTaggerEffectHandler(logManager: mockLogManager)
        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testTagLogsAsUploaded() {
        mockLogManager.taggedLogsToReturn = [
            uploadedLogs[0].url: uploadedTaggedLogs[0],
            uploadedLogs[1].url: uploadedTaggedLogs[1]
        ]
        send = { event in
            if case .logsTaggedAsUploaded(let taggedLogs) = event {
                for uploadedLog in self.uploadedLogsURL {
                    guard let range = uploadedLog.path.range(of: ".xcactivitylog") else {
                        return XCTFail("File is not a .xcactivitylog.")
                    }
                    // Split log path before extension to insert "_UPLOADED" in order to assert that the log was renamed.
                    // i.e: 52713245-14DB-4C8E-9759-494DA3DB899A.yhJxvf.xcactivitylog
                    //      52713245-14DB-4C8E-9759-494DA3DB899A.yhJxvf_UPLOADED.xcactivitylog
                    let leftSide = uploadedLog.path[uploadedLog.path.startIndex..<range.lowerBound]
                    let rightSide = uploadedLog.path[range.lowerBound..<range.upperBound]
                    let expectedPath = leftSide + "_UPLOADED" + rightSide
                    XCTAssertTrue(taggedLogs.contains(URL(fileURLWithPath: String(expectedPath))))
                }
            } else {
                XCTFail("Expected .logsTaggedAsUploaded, got: \(event)")
            }
        }
        _ = effectHandler.handle(uploadedLogsURL, effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }
}

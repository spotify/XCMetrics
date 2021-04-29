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

final class MockMetricsPublisher: MetricsPublisherService {

    func uploadMetrics(
        serviceURL: URL,
        projectName: String,
        isCI: Bool,
        skipNotes: Bool,
        uploadRequests: Set<MetricsUploadRequest>,
        completion: @escaping (Set<URL>, [URL : Data]) -> Void
    ) {
        let filesURL = Set(uploadRequests.map {
            $0.fileURL
        })
        completion(filesURL, [:])
    }
}

final class UploadMetricsEffectHandlerTests: XCTestCase {

    private var effectHandler: UploadMetricsEffectHandler!
    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?

    private var mockMetricsPublisher = MockMetricsPublisher()

    override func setUp() {
        super.setUp()

        effectHandler = UploadMetricsEffectHandler(metricsPublisher: mockMetricsPublisher)
        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testHandleFindLogsWithLastLogAdded() {
        let uploadRequests = Set(arrayLiteral:
            MetricsUploadRequest(fileURL: URL(string: "strings")!, request: try! UploadBuildMetricsRequest(jsonString: "{}"))
        )
        send = { event in
            if case .logsUploaded(let uploadedLogs) = event {
                XCTAssertEqual(uploadedLogs.first!, uploadRequests.first!.fileURL)
            } else if case .logsUploadFailed(let failedLogs) = event {
                XCTAssertEqual(failedLogs, [:])
            } else {
                XCTFail("Expected .logsUploaded or , got: \(event)")
            }
        }
        _ = effectHandler.handle((serviceURL: serviceURL, projectName: projectName, isCI: false, skipNotes: false, logs: uploadRequests),
                                 effectCallback)
        XCTAssertTrue(effectCallback.ended)
    }
}

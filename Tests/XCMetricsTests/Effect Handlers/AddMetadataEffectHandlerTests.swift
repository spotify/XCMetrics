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
import XCTest
@testable import XCMetricsClient

final class AddMetadataEffectHandlerTests: XCTestCase {

    private var effectCallback: EffectCallback<MetricsUploaderEvent>!
    private var send: ((MetricsUploaderEvent) -> Void)?

    override func setUp() {
        super.setUp()

        effectCallback = EffectCallback<MetricsUploaderEvent>(
            onSend: { event in
                if let send = self.send {
                    send(event)
                }
        }, onEnd: {})
    }

    func testAppendsTagFromContext() throws {
        let request = try UploadBuildMetricsRequest(jsonString: "{}")
        let uploadRequest = MetricsUploadRequest(fileURL: URL(fileURLWithPath: ""), request: request)
        let effectHandler = AddMetadataEffectHandler(environmentContext: ["SPT_XCMETRICS_TAG":"a"])
        var eventsReceived: [MetricsUploaderEvent] = []
        send = { eventsReceived.append($0) }

        _ = effectHandler.handle(uploadRequest, effectCallback)

        XCTAssertEqual(eventsReceived.count, 1)
        guard case .requestMetadataAppended(let updatedRequest) = eventsReceived.first else {
            XCTFail(".requestMetadataAppended expectation failed")
            return
        }
        XCTAssertEqual(updatedRequest.request.build.tag, "a")
        XCTAssertTrue(effectCallback.ended)
    }

    func testLeavesTagEmptyForMissingTagInContext() throws {
        let request = try UploadBuildMetricsRequest(jsonString: "{}")
        let uploadRequest = MetricsUploadRequest(fileURL: URL(fileURLWithPath: ""), request: request)
        let effectHandler = AddMetadataEffectHandler(environmentContext: [:])
        var eventsReceived: [MetricsUploaderEvent] = []
        send = { eventsReceived.append($0) }

        _ = effectHandler.handle(uploadRequest, effectCallback)

        guard case .requestMetadataAppended(let updatedRequest) = eventsReceived.first else {
            XCTFail(".requestMetadataAppended expectation failed")
            return
        }
        XCTAssertEqual(updatedRequest.request.build.tag, "")
        XCTAssertTrue(effectCallback.ended)
    }
}

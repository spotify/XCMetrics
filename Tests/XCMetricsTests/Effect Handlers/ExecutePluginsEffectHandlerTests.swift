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

final class ExecutePluginsEffectHandlerTests: XCTestCase {

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

    func testExecutePlugins() throws {
        let plugins = [XCMetricsPlugin(name: "Test Plugin", body: { (_) -> [String : String] in
            return ["My Test Key": "My Test Value"]
        })]
        let request = try UploadBuildMetricsRequest(jsonString: "{}")
        let uploadRequest = MetricsUploadRequest(fileURL: URL(fileURLWithPath: ""), request: request)
        let effectHandler = ExecutePluginsEffectHandler(environmentContext: [:])
        var eventsReceived: [MetricsUploaderEvent] = []
        send = { eventsReceived.append($0) }

        _ = effectHandler.handle((uploadRequest, plugins), effectCallback)

        XCTAssertEqual(eventsReceived.count, 1)
        guard case .pluginsExecuted(let updatedRequest) = eventsReceived.first else {
            XCTFail(".pluginsExecuted expectation failed")
            return
        }
        XCTAssertEqual(updatedRequest.request.buildMetadata.metadata["My Test Key"], "My Test Value")
        XCTAssertTrue(effectCallback.ended)
    }
}

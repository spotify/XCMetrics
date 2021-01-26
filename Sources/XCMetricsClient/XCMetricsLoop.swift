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
import MobiusCore
import XCMetricsUtils

class XCMetricsLoop {
    private let group = DispatchGroup()
    private var mobiusController: MobiusController<MetricsUploaderModel, MetricsUploaderEvent, MetricsUploaderEffect>!

    func startLoop(with command: Command, plugins: [XCMetricsPlugin] = []) {
        setUpCompletedNotificationListener()
        group.enter()
        let start = Date()
        mobiusController = ControllerFactory.createController(with: command, plugins: plugins)
        mobiusController.start()
        group.wait()
        let completed = Date()
        log("Loop completed and took \(completed.timeIntervalSince(start)).")
    }

    private func setUpCompletedNotificationListener() {
        NotificationCenter.default.addObserver(forName: .mobiusLoopCompleted, object: nil, queue: nil) { _ in
            log("leaving group")
            self.group.leave()
        }
    }
}

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
import MobiusExtras

struct LogsFinderEffectHandler: EffectHandler {

    private let logManager: LogManager

    init(logManager: LogManager) {
        self.logManager = logManager
    }

    func handle(_ effectParameters: (buildDirectory: String, timeout: Int),
                _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        do {
            let xcodeLogs = try logManager.retrieveXcodeLogs(in: effectParameters.buildDirectory,
                                                             timeout: effectParameters.timeout)
            let cachedLogs = try logManager.retrieveCachedLogs()
            callback.end(with: .logsFound(currentLog: xcodeLogs.currentLog, xcodeLogs: xcodeLogs.otherLogs, cachedLogs: cachedLogs))
            log("Successfully found logs, Xcode: \(xcodeLogs) / Cache: \(cachedLogs)")
        } catch {
            exit(1, error.localizedDescription)
        }
        return AnonymousDisposable {}
    }
}

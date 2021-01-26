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
import XCMetricsUtils

struct UploadedLogTaggerEffectHandler: EffectHandler {

    private let logManager: LogManager

    init(logManager: LogManager) {
        self.logManager = logManager
    }

    func handle(_ input: Void, _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        do {
            let evictedLogs = try logManager.evictLogs()
            log("Successfully evicted logs: \(evictedLogs))")
            callback.end(with: .cleanedUpLogs(logs: evictedLogs))
        } catch {
            log("Error (\(error.localizedDescription)) in evicting logs.")
        }
        return AnonymousDisposable {}
    }
}

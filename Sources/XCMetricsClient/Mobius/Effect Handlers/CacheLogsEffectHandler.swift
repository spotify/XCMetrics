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

struct CacheLogsEffectHandler: EffectHandler {

    private let logManager: LogManager
    private let logCopyRetries = 5
    private let uploadCurrentLogOnly: Bool

    init(logManager: LogManager, uploadCurrentLogOnly: Bool) {
        self.logManager = logManager
        self.uploadCurrentLogOnly = uploadCurrentLogOnly
    }

    func handle(_ effectParameters: (currentLog: URL?, previousLogs: Set<URL>, cachedLogs: Set<URL>, projectName: String),
                _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        do {
            var cachedLogsURLs: Set<URL> = []
            if (!uploadCurrentLogOnly) {
              // Cache other logs that Xcode produced.
              cachedLogsURLs = try logManager.cacheLogs(effectParameters.previousLogs, cachedLogs: effectParameters.cachedLogs, retries: 0)
            }
            // Cache currentLog separately, to keep track of its cached location.
            var cachedCurrentLogURLs: Set<URL> = []
            if let currentLog = effectParameters.currentLog {
                cachedCurrentLogURLs = try logManager.cacheLogs(Set([currentLog]),
                                                                cachedLogs: cachedLogsURLs.union(effectParameters.cachedLogs),
                                                                retries: logCopyRetries)
                cachedLogsURLs = cachedLogsURLs.union(cachedCurrentLogURLs)
            }
            log("Successfully cached logs: \(cachedLogsURLs)")
            // Retrieve requests that previously failed to upload.
            let requestsToRetry = try logManager.retrieveLogRequestsToUpload()
            // Transforms the contents of the cached logs into an actual MetricsUploadRequest.
            let cachedUploadRequests: Set<MetricsUploadRequest> = Set(requestsToRetry.map {
                MetricsUploadRequest(fileURL: $0)
            })
            log("Successfully fetched requests that failed to upload previously: \(requestsToRetry))")

            callback.end(
                with: .logsCached(
                    currentLog: cachedCurrentLogURLs.first,
                    previousLogs: cachedLogsURLs.subtracting(cachedCurrentLogURLs),
                    cachedUploadRequests: cachedUploadRequests
                )
            )
        } catch {
            exit(1, error.localizedDescription)
        }
        return AnonymousDisposable {}
    }
}

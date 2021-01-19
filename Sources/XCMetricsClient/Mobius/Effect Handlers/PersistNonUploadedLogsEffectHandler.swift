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

struct PersistNonUploadedLogsEffectHandler: EffectHandler {

    private let logManager: LogManager

    init(logManager: LogManager) {
        self.logManager = logManager
    }
    
    func handle(_ nonUploadedLogs: [URL: Data], _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        log("Started writing metadata to disk.")
        for (url, data) in nonUploadedLogs {
            do {
                // Save failed request on disk.
                let savedURL = try logManager.saveFailedRequest(url: url, data: data)
                // Mark failed log as if it was uploaded in order not to retry uploading it, since it will be treated
                // as a failed request from now on.
                _ = try logManager.tagLogAsUploaded(logURL: url)
                log("Saved failed request on disk to \(savedURL).")
            } catch {
                log("Failed to save metadata on disk for \(url) with error: \(error).")
            }
        }
        callback.end(with: .savedUploadRequests)
        return AnonymousDisposable {}
    }
}

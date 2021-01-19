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

struct LogsTaggerEffectHandler: EffectHandler {

    private let logManager: LogManager

    init(logManager: LogManager) {
        self.logManager = logManager
    }

    func handle(_ logs: Set<URL>, _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        // Mark newly uploaded logs as uploaded.
        let taggedUploadedLogs = logs.filter { url in
            !url.isRequestFile
        }.compactMap { url in
            try? logManager.tagLogAsUploaded(logURL: url)
        }

        // Remove previously uploaded log requests.
        logs.filter { url in
            url.isRequestFile
        }.forEach { url in
            try? logManager.removeUploadedFailedRequest(url: url)
        }

        callback.end(with: .logsTaggedAsUploaded(logs: Set(taggedUploadedLogs)))
        return AnonymousDisposable {}
    }
}

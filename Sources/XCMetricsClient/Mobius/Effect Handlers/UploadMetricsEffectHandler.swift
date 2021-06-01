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

struct UploadMetricsEffectHandler: EffectHandler {

    private let metricsPublisher: MetricsPublisherService

    init(metricsPublisher: MetricsPublisherService = MetricsPublisherServiceHTTP()) {
        self.metricsPublisher = metricsPublisher
    }

    func handle(_ effectParameters: (serviceURL: URL, additionalHeaders: [String: String], projectName: String, isCI: Bool, skipNotes: Bool, logs: Set<MetricsUploadRequest>), _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        log("Started uploading metrics.")
        metricsPublisher.uploadMetrics(
            serviceURL: effectParameters.serviceURL,
            additionalHeaders: effectParameters.additionalHeaders,
            projectName: effectParameters.projectName,
            isCI: effectParameters.isCI,
            skipNotes: effectParameters.skipNotes,
            uploadRequests: effectParameters.logs
        ) { successfulURLs, failedURLs in
            callback.end(with: [
                .logsUploadFailed(logs: failedURLs),
                .logsUploaded(logs: successfulURLs)
            ])
        }
        return AnonymousDisposable {}
    }
}

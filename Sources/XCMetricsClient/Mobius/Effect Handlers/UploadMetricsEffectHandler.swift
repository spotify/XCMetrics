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

struct UploadMetricsEffectHandler: EffectHandler {

    private let metricsPublisher: MetricsPublisherService

    init(metricsPublisher: MetricsPublisherService = MetricsPublisherServiceHTTP()) {
        self.metricsPublisher = metricsPublisher
    }

    func handle(_ effectParameters: (serviceURL: URL, projectName: String, isCI: Bool, logs: Set<MetricsUploadRequest>), _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        log("Started uploading metrics.")
        metricsPublisher.uploadMetrics(
            serviceURL: effectParameters.serviceURL,
            projectName: effectParameters.projectName,
            isCI: effectParameters.isCI,
            uploadRequests: effectParameters.logs) { successfulURLs, failedURLs in
            var effects = [MetricsUploaderEvent]()
            // Handle failed log uploads. Skip if empty.
            if !failedURLs.isEmpty {
                effects.append(.logsUploadFailed(logs: failedURLs))
            }
            // Handle successful log uploads.
            effects.append(.logsUploaded(logs: successfulURLs))

            callback.end(with: effects)
        }
        return AnonymousDisposable {}
    }
}

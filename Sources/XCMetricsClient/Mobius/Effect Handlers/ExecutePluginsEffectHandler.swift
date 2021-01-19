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

struct ExecutePluginsEffectHandler: EffectHandler {

    typealias EnvironmentContext = [String: String]

    private let environmentContext: EnvironmentContext

    init(environmentContext: EnvironmentContext = ProcessInfo.processInfo.environment) {
        self.environmentContext = environmentContext
    }

    func handle(
        _ effectParameters: (request: MetricsUploadRequest, plugins: [XCMetricsPlugin]),
        _ callback: EffectCallback<MetricsUploaderEvent>
    ) -> Disposable {
        let request = effectParameters.request
        let plugins = effectParameters.plugins
        var buildMetadata = BuildMetadata()

        for plugin in plugins {
            log("Started appending plugin \(plugin.name) to the request: \(request.request.build.identifier).")
            let dictionary = plugin.body(environmentContext)
            for (key, value) in dictionary {
                buildMetadata.metadata[key] = value
            }
        }
        var newRequest = request.request
        newRequest.buildMetadata = buildMetadata

        let updatedRequest = MetricsUploadRequest(fileURL: request.fileURL, request: newRequest)
        callback.end(with: .pluginsExecuted(currentRequest: updatedRequest))

        return AnonymousDisposable {}
    }
}

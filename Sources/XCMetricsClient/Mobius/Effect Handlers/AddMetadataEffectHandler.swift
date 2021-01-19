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

enum EnvironmentVariable {
    static var TAG_KEY = "SPT_XCMETRICS_TAG"
    static var XCODE_BUILD_NUMBER_KEY = "XCODE_PRODUCT_BUILD_VERSION"
    static var XCODE_VERSION_KEY = "XCODE_VERSION_ACTUAL"
}

struct AddMetadataEffectHandler: EffectHandler {
    typealias EnvironmentContext = [String: String]

    private let hardwareFetcher: HardwareFactsFetcher
    private let environmentContext: EnvironmentContext

    init(hardwareFetcher: HardwareFactsFetcher = HardwareFactsFetcherImplementation(),
         environmentContext: EnvironmentContext = ProcessInfo.processInfo.environment) {
        self.hardwareFetcher = hardwareFetcher
        self.environmentContext = environmentContext
    }

    func handle(_ request: MetricsUploadRequest, _ callback: EffectCallback<MetricsUploaderEvent>) -> Disposable {
        log("Started appending metadata to the request: \(request.request.build.identifier).")
        var metricsBuilder = XCMetricsBuilder().withOtherMetrics(request.request)
        appendHardwareFacts(to: &metricsBuilder, request: request)
        appendXcodeVersion(to: &metricsBuilder, request: request)
        appendTag(to: &metricsBuilder, request: request)

        let updatedRequest = MetricsUploadRequest(fileURL: request.fileURL, request: metricsBuilder.build())
        callback.end(with: .requestMetadataAppended(currentRequest: updatedRequest))

        return AnonymousDisposable {}
    }

    private func appendHardwareFacts(to metricsBuilder: inout XCMetricsBuilder, request: MetricsUploadRequest) {
        log("Started appending Hardware Facts")
        do {
            var hardwareFacts = try hardwareFetcher.fetch()
            hardwareFacts.buildIdentifier = request.request.build.identifier
            metricsBuilder = metricsBuilder.withBuildHost(hardwareFacts)
        } catch {
            log("Error: Hardware facts could not be fetched \(error.localizedDescription)")
        }
    }

    private func appendXcodeVersion(to metricsBuilder: inout XCMetricsBuilder, request: MetricsUploadRequest)  {
        guard let buildNumber = environmentContext[EnvironmentVariable.XCODE_BUILD_NUMBER_KEY],
            let version = environmentContext[EnvironmentVariable.XCODE_VERSION_KEY] else {
            return
        }

        log("Started appending Xcode build number \"\(buildNumber)\" and version \"\(version)\"")
        var xcodeVersion = XcodeVersion()
        xcodeVersion.buildNumber = buildNumber
        xcodeVersion.version = version
        xcodeVersion.buildIdentifier = request.request.build.identifier
        metricsBuilder = metricsBuilder.withXcodeVersion(xcodeVersion)
    }

    private func appendTag(to metricsBuilder: inout XCMetricsBuilder, request: MetricsUploadRequest) {
        guard let tag = environmentContext[EnvironmentVariable.TAG_KEY] else {
            return
        }
        log("Started appending a tag \"\(tag)\"")
        var build = request.request.build
        build.tag = tag
        metricsBuilder = metricsBuilder.withBuild(build)
    }
}

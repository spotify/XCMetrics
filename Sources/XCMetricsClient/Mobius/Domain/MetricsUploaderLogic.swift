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

/// To avoid using too much CPU in case the user has many logs to parse and upload,
/// we set a maximum number of logs to parse and send at each invocation. Other logs
/// will be parsed and sent in future invocations.
private let maximumNumberOfLogsToParseAndSend = 3
/// To avoid spending too much time uploading requests, we at most upload this value of requests previously saved.
private let maximumNumberOfParsedRequestsToSend = 3
/// We have to wait for both `cleanedUpLogs` and `savedUploadRequests` events to happpen before finishing executing.
private var expectedRequests = 2
/// Lock that manages read/write access to `expectedRequests`.
private let expectedRequestsLock = NSLock()

enum MetricsUploaderLogic {

    static func buildInitiator(with initEffect: MetricsUploaderEffect) -> (MetricsUploaderModel) -> First<MetricsUploaderModel, MetricsUploaderEffect> {
        return { model in
            return First(
                model: model,
                effects: [initEffect]
            )
        }
    }

    static func update(model: MetricsUploaderModel, event: MetricsUploaderEvent) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        switch event {
        case .logsFound(let currentLog, let xcodeLogs, let cachedLogs):
            return onLogsFound(model, currentLog, xcodeLogs, cachedLogs)
        case .logsCached(let cachedCurrentLog, let cachedLogs, let cachedUploadRequest):
            return onLogsCached(model, cachedCurrentLog, cachedLogs, cachedUploadRequest)
        case .requestMetadataAppended(let currentRequest):
            return onRequestMetadataAppended(model, currentRequest)
        case .pluginsExecuted(let currentRequest):
            return onPluginsExecuted(model, currentRequest)
        case .logsUploaded(let uploadedLogs):
            return onLogsUploaded(model, uploadedLogs)
        case .logsTaggedAsUploaded(let taggedLogs):
            return onLogsTaggedAsUploaded(model, taggedLogs)
        case .cleanedUpLogs(let cleanedUpLogs):
            return onCleanedUpLogs(model, cleanedUpLogs)
        case .logsUploadFailed(let failedLogs):
            return onLogsUploadFailed(model, failedLogs)
        case .savedUploadRequests:
            return onSavedUploadRequests(model)
        }
    }

    private static func onLogsFound(_ model: MetricsUploaderModel, _ currentLog: URL?, _ xcodeLogs: Set<URL>, _ cachedLogs: Set<URL>) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        return .dispatchEffects([.cacheLogs(currentLog: currentLog, previousLogs: xcodeLogs, cachedLogs: cachedLogs, projectName: model.projectName)])
    }

    private static func onLogsCached(_ model: MetricsUploaderModel, _ cachedCurrentLog: URL?, _ cachedLogs: Set<URL>, _ cachedUploadRequest: Set<MetricsUploadRequest>) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        var effects: [MetricsUploaderEffect] = []
        if let cachedCurrentLog = cachedCurrentLog {
            effects.append(.appendMetadata(request: MetricsUploadRequest(fileURL: cachedCurrentLog,
                                                                         request: UploadBuildMetricsRequest())))
        }

        // TODO(patrickb): maybe only send maximumNumberOfLogsToParseAndSend logs
        let uploadRequests = Set(cachedLogs.map {
            MetricsUploadRequest(fileURL: $0)
        })

        if !uploadRequests.isEmpty {
            effects.append(.uploadLogs(serviceURL: model.serviceURL, projectName: model.projectName, isCI: model.isCI, logs: uploadRequests))
        }
        let updatedModel = model.withChanged(
            parsedRequests: model.parsedRequests.union(cachedUploadRequest.prefix(maximumNumberOfParsedRequestsToSend)),
            awaitingParsingLogResponses: 0
        )
        // If no log to parse has been found, skip directly to upload cached logs if any.
        if effects.isEmpty {
            return .next(updatedModel, effects: [.uploadLogs(
                serviceURL: model.serviceURL,
                projectName: model.projectName,
                isCI: model.isCI,
                logs: updatedModel.parsedRequests
            )])
        }
        return .next(updatedModel, effects: effects)
    }

    private static func onRequestMetadataAppended(_ model: MetricsUploaderModel, _ request: MetricsUploadRequest) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        return .dispatchEffects([.executePlugins(request: request, plugins: model.plugins)])
    }

    private static func onPluginsExecuted(_ model: MetricsUploaderModel, _ request: MetricsUploadRequest) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        let updatedModel = model.withChanged(parsedRequests: model.parsedRequests.union([request]))
        return .next(updatedModel, effects: [
            .uploadLogs(
                serviceURL: model.serviceURL,
                projectName: model.projectName,
                isCI: model.isCI,
                logs: updatedModel.parsedRequests
            )
        ])
    }

    private static func onLogsUploaded(_ model: MetricsUploaderModel, _ uploadedLogs: Set<URL>) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        if uploadedLogs.isEmpty {
            return .dispatchEffects([.cleanUpLogs])
        }
        
        return .dispatchEffects([.tagLogsAsUploaded(logs: uploadedLogs)])
    }

    private static func onLogsTaggedAsUploaded(_ model: MetricsUploaderModel, _ taggedLogs: Set<URL>) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        return .dispatchEffects([.cleanUpLogs])
    }

    private static func onLogsUploadFailed(_ model: MetricsUploaderModel, _ failedLogs: [URL: Data]) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        return .dispatchEffects([.persistNonUploadedLogs(logs: failedLogs)])
    }

    private static func onCleanedUpLogs(_ model: MetricsUploaderModel, _ cleandUpLogs: Set<URL>) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        expectedRequestsLock.lock()
        defer { expectedRequestsLock.unlock() }
        expectedRequests -= 1
        if expectedRequests == 0 {
            NotificationCenter.default.post(name: .mobiusLoopCompleted, object: nil)
        }
        return .noChange
    }

    private static func onSavedUploadRequests(_ model: MetricsUploaderModel) -> Next<MetricsUploaderModel, MetricsUploaderEffect> {
        expectedRequestsLock.lock()
        defer { expectedRequestsLock.unlock() }
        expectedRequests -= 1
        if expectedRequests == 0 {
            NotificationCenter.default.post(name: .mobiusLoopCompleted, object: nil)
        }
        return .noChange
    }
}

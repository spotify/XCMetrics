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

enum ControllerFactory {

    static func createController(with command: Command, plugins: [XCMetricsPlugin]) -> MobiusController<MetricsUploaderModel, MetricsUploaderEvent, MetricsUploaderEffect> {
        guard let serviceURL = URL(string: command.serviceURL) else {
            fatalError("The provided serviceURL is invalid.")
        }

        let model = MetricsUploaderModel(
            buildDirectory: command.buildDirectory,
            projectName: command.projectName,
            serviceURL: serviceURL,
            additionalHeaders: command.additionalHeaders,
            timeout: command.timeout,
            isCI: command.isCI,
            plugins: plugins,
            skipNotes: command.skipNotes,
            truncLargeIssues: command.truncLargeIssues
        )
        let initEffect = MetricsUploaderEffect.findLogs(buildDirectory: model.buildDirectory, timeout: model.timeout)
        let logManager = LogManagerImplementation(projectName: model.projectName)

        let effectRouter = EffectRouter<MetricsUploaderEffect, MetricsUploaderEvent>()
            .routeCase(MetricsUploaderEffect.findLogs).to(LogsFinderEffectHandler(logManager: logManager))
            .routeCase(MetricsUploaderEffect.cacheLogs).to(CacheLogsEffectHandler(logManager: logManager))
            .routeCase(MetricsUploaderEffect.appendMetadata).to(AddMetadataEffectHandler())
            .routeCase(MetricsUploaderEffect.executePlugins).to(ExecutePluginsEffectHandler())
            .routeCase(MetricsUploaderEffect.uploadLogs).to(UploadMetricsEffectHandler())
            .routeCase(MetricsUploaderEffect.persistNonUploadedLogs).to(PersistNonUploadedLogsEffectHandler(logManager: logManager))
            .routeCase(MetricsUploaderEffect.tagLogsAsUploaded).to(LogsTaggerEffectHandler(logManager: logManager))
            .routeCase(MetricsUploaderEffect.cleanUpLogs).to(UploadedLogTaggerEffectHandler(logManager: logManager))
            .asConnectable

        return Mobius.loop(update: MetricsUploaderLogic.update, effectHandler: effectRouter)
            .withLogger(MetricsUploaderLogger())
            .makeController(from: model, initiate: MetricsUploaderLogic.buildInitiator(with: initEffect))
    }
}

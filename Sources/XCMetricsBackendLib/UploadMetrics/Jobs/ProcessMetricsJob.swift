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
import CryptoSwift
import Queues

/// Job that parses the uploaded xcactivitylog and inserts it into a Repository
class ProcessMetricsJob: Job {

    typealias Payload = UploadMetricsRequest

    let logFileRepository: LogFileRepository

    let metricsRepository: MetricsRepository

    /// If true, the user data (userId, machineName) will be hashed and the
    /// User data will be redacted from the log
    let redactUserData: Bool

    /// Queue in which the logs will be processed
    let queue = DispatchQueue(label: "process.metrics.queue", qos: .userInitiated)

    /// Set concurrent processing of logs up to the number of cores
    let semaphore = DispatchSemaphore(value: ProcessInfo.processInfo.processorCount)

    init(logFileRepository: LogFileRepository, metricsRepository: MetricsRepository, redactUserData: Bool) {
        self.logFileRepository = logFileRepository
        self.metricsRepository = metricsRepository
        self.redactUserData = redactUserData
    }

    func dequeue(_ context: QueueContext, _ payload: UploadMetricsRequest) -> EventLoopFuture<Void> {
        logWithTimestamp(context.logger, msg: "[ProcessMetricsJob] message dequeued")

        let eventLoop = context.application.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: Void.self)

        /// parsing is a blocking call, we execute it in a Dispatch Queue to not block the eventloop
        queue.async {
            self.semaphore.wait()

            defer {
                self.semaphore.signal()
            }

            do {
                logWithTimestamp(context.logger, msg: "[ProcessMetricsJob] fetching log from \(payload.logURL)")
                let localURL = try self.logFileRepository.get(logURL: payload.logURL)

                logWithTimestamp(context.logger, msg: "[ProcessMetricsJob] log fetched to \(localURL)")
                let buildMetrics = try MetricsProcessor.process(metricsRequest: payload,
                                                                logURL: localURL,
                                                                redactUserData: self.redactUserData)
                let metricsWithRequestData = self.addBuildRequest(buildMetrics: buildMetrics, payload: payload)
                logWithTimestamp(context.logger, msg: "[ProcessMetricsJob] log parsed \(payload.logURL)")
                _ = self.metricsRepository.insertBuildMetrics(metricsWithRequestData, using: eventLoop)
                    .flatMap { _ -> EventLoopFuture<Void> in
                        context.logger.info("[ProcessMetricsJob] metrics inserted for \(payload.logURL)")
                        return self.removeLocalLog(from: localURL, using: eventLoop)
                    }
                    .map { _ -> Void in
                        context.logger.info("[ProcessMetricsJob] finished processing \(payload.logURL)")
                        promise.succeed(())
                        return ()
                    }
            } catch {
                context.logger.error("[ProcessMetricsJob] error processing \(payload.logURL) \(error)")
                promise.fail(error)
            }
        }
        return promise.futureResult
    }

    private func addBuildRequest(buildMetrics: BuildMetrics, payload: UploadMetricsRequest) -> BuildMetrics {
        guard let buildIdentifier = buildMetrics.build.id else {
            return buildMetrics
        }
        return buildMetrics.withHost(payload.buildHost.withBuildIdentifier(buildIdentifier))
            .withBuildMetadata(payload.buildMetadata?.withBuildIdentifier(buildIdentifier))
            .withXcodeVersion(payload.xcodeVersion?.withBuildIdentifier(buildIdentifier))
    }

    private func removeLocalLog(from url: URL, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.submit { () -> Void in
            try? FileManager.default.removeItem(at: url)
        }
    }
}

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

import Vapor

struct UploadMetricsController: RouteCollection {

    /// 100 mb
    static let MAX_PAYLOAD_SIZE: ByteCount = 104857600

    let fileLogRepository: LogFileRepository
    let redactUserData: Bool
    let metricsRepository: MetricsRepository
    let useAsyncProcessing: Bool

    init(fileLogRepository: LogFileRepository, redactUserData: Bool, metricsRepository: MetricsRepository, useAsyncProcessing: Bool) {
        self.fileLogRepository = fileLogRepository
        self.redactUserData = redactUserData
        self.metricsRepository = metricsRepository
        self.useAsyncProcessing = useAsyncProcessing
    }

    func boot(routes: RoutesBuilder) throws {
        let builds = routes.grouped("v1")
        if useAsyncProcessing {
            builds.on(.PUT, "metrics", body: .collect(maxSize: Self.MAX_PAYLOAD_SIZE), use: create)
        }
        builds.on(.PUT, "metrics-sync", body: .collect(maxSize: Self.MAX_PAYLOAD_SIZE), use: createSync)
    }

    /// Gets a Request to process a Log and enqueues it to be processed by `ProcessMetricsJob` asynchronously.
    /// Basically acts as a Fire & Forget endpoint, which is faster that the Sync option.
    /// If the Backend is started with the option `XCMETRICS_USE_ASYNC_LOG_PROCESSING` turned off,
    /// this endpoint will not be available (Returns a `404`
    /// - Parameter req: Request with a valid`UploadMetricsPayload`
    /// - Throws: If the request is not a valid `UploadMetricsPayload` or there was an error storing the log
    /// - Returns: `200` HTTP Status if everything is ok. `400` if the request is not an `UploadMetricsPayload`,
    /// `404` if Async processing was turned off (`XCMETRICS_USE_ASYNC_LOG_PROCESSING`=0)
    /// `500` if there was an unexpected error
    func create(req: Request) throws -> EventLoopFuture<HTTPStatus> {

        // The request contains a Multipart Nested request: one field of type Octect-stream with the actual log
        // and several of type `json`. Vapor lacks support for this type of content [Issue-1925](https://github.com/vapor/vapor/issues/1925)
        // We need to decode it as raw data and do the parsing manually

        // 1. Decode request as raw data
        let payload = try req.content.decode(UploadMetricsPayload.self)

        // Storing the log and decoding the request are blocking, we execute them in a background thread
        // to not block the eventloop
        return req.application.threadPool.runIfActive(eventLoop: req.eventLoop) { () -> UploadMetricsRequest in
            // 2. Store the log
            let logURL = try self.fileLogRepository.put(logFile: payload.log)

            // 3. Decode the JSON documents into `Codable` types
            guard let metricsRequest = try UploadMetricsRequest(logURL: logURL, payload: payload) else {
                throw Abort(.badRequest)
            }
            return metricsRequest
        }.flatMap { metricsRequest -> EventLoopFuture<HTTPStatus> in
            return req.queue.dispatch(ProcessMetricsJob.self,
                                      metricsRequest,
                                      maxRetryCount: 3)
                .transform(to: HTTPStatus.ok)
        }
    }

    /// Inserts the build metrics Synchronously which can be slow. Use only if the Async method is not available
    /// for instance, if running in CloudRun
    /// - Parameter req: Request with a valid`UploadMetricsPayload`
    /// - Throws: If the request is not a valid `UploadMetricsPayload` or there was an error parsing the Logs or inserting them in the database
    /// - Returns: `201` HTTP Status if everything is ok. `400` if the request is not an `UploadMetricsPayload`, `500` if there was an unexpected error
    func createSync(req: Request) throws -> EventLoopFuture<HTTPStatus> {

        // The request contains a Multipart Nested request: one field of type Octect-stream with the actual log
        // and several of type `json`. Vapor lacks support for this type of content [Issue-1925](https://github.com/vapor/vapor/issues/1925)
        // We need to decode it as raw data and do the parsing manually

        // 1. Decode request as raw data
        let payload = try req.content.decode(UploadMetricsPayload.self)

        // Storing the log and decoding the request are blocking, we execute them in a background thread
        // to not block the eventloop
        return req.application.threadPool.runIfActive(eventLoop: req.eventLoop) { () -> BuildMetrics in
            // 2. Store the log
            let logURL = try self.fileLogRepository.put(logFile: payload.log)

            // 3. Decode the JSON documents into `Codable` types
            guard let metricsRequest = try UploadMetricsRequest(logURL: logURL, payload: payload) else {
                throw Abort(.badRequest)
            }

            // 4. Parse an process the metrics
            let localURL = try self.fileLogRepository.get(logURL: logURL)
            return try MetricsProcessor.process(metricsRequest: metricsRequest,
                                                logURL: localURL,
                                                redactUserData: self.redactUserData)
        }.flatMap { buildMetrics -> EventLoopFuture<HTTPStatus> in
            self.metricsRepository.insertBuildMetrics(buildMetrics, using: req.application.eventLoopGroup.next())
                .transform(to: HTTPStatus.created)
        }
    }

}

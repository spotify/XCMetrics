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
import Core
import Storage

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    // Configuration
    let config = Configuration()

    // Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .any([config.corsAllowed]),
        allowedMethods: [.GET, .OPTIONS, .HEAD],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors)

    // Log File Repository
    let logFileRepository = LogFileRepositoryFactory.makeWithConfiguration(config: config, logger: app.logger)

    // Controllers
    try app.register(collection: BuildController())
    try app.register(collection: UploadMetricsController(fileLogRepository: logFileRepository,
                                                         redactUserData: config.redactUserData,
                                                         metricsRepository: PostgreSQLMetricsRepository(db: app.db, logger: app.logger),
                                                         useAsyncProcessing: config.useAsyncLogProcessing))
    try app.register(collection: JobLogController(repository: PostgreSQLJobLogRepository(db: app.db)))
    try app.register(collection: StatisticsController(repository: SQLStatisticsRepository(db: app.db)))

    if app.environment != .testing {
        let healthChecker = JobHealthCheckerImpl(queue: app.queues.queue)
        try app.register(collection: HealthCheckController(healthChecker: healthChecker))
    }

    // Run Job queues
    if config.useAsyncLogProcessing {
        app.queues.add(ProcessMetricsJob(logFileRepository: logFileRepository,
                                         metricsRepository: PostgreSQLMetricsRepository(db: app.db, logger: app.logger),
                                         redactUserData: config.redactUserData))
        app.queues.add(HealthCheckJob())

        if config.startAsyncJobsInSameInstance {
            try app.queues.startInProcessJobs(on: .default)
        }
    }

}

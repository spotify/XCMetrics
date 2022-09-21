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
import Vapor

struct LogFileRepositoryFactory {

    static func makeWithConfiguration(config: Configuration, logger: Logger) -> LogFileRepository {
        if config.useGCSLogRepository {
            logger.info("Initializing GCS LogFileRepository")
            guard let gcsRepository = LogFileGCSRepository(config: config, logger: logger) else {
                preconditionFailure("GOOGLE_APPLICATION_CREDENTIALS, XCMETRICS_GOOGLE_PROJECT and XCMETRICS_GCS_BUCKET are " +
                    "required when XCMETRICS_USE_GCS_REPOSITORY is used")
            }
            return gcsRepository
        }
        if config.useS3LogRepository {
            logger.info("Initializing S3 LogFileRepository")
            guard let s3Repository = LogFileS3Repository(config: config) else {
                preconditionFailure("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY_ID, XCMETRICS_S3_BUCKET and " +
                    "XCMETRICS_S3_REGION are required when XCMETRICS_USE_S3_REPOSITORY is used")
            }
            return s3Repository
        }
        return LocalLogFileRepository()
    }

}

// Copyright (c) 2021 Spotify AB.
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
import NIO

class Configuration {

    /// If "1", the logs will be processed Asynchronously, it will need a `REDIS_HOST` to be defined
    /// Turn it off in environments where Async processing is not available like in Cloud Run
    lazy var useAsyncLogProcessing: Bool = {        
        return (Environment.get("XCMETRICS_USE_ASYNC_LOG_PROCESSING") ?? "1" ) == "1"
    }()

    /// Use Google Cloud Storage to store the logs. This should be 1 if you're using
    /// Some intances as Endpoints and others as Jobs. See de Deployment documentation for more info.
    lazy var useGCSLogRepository: Bool = {
        return (Environment.get("XCMETRICS_USE_GCS_REPOSITORY") ?? "0") == "1"
    }()

    /// Default to true. It will start the Job to process the logs in the same process as the Controllers
    /// For better performance, you can deploy N versions of the Jobs separately in which case you
    /// need to turn this flag off (more information in the documentation)
    lazy var startAsyncJobsInSameInstance: Bool = {
        return (Environment.get("XCMETRICS_START_JOBS_SAME_INSTANCE") ?? "1") == "1"
    }()

    /// If "1", a job for collecting and storing statistics (build count, error count etc.) from the
    /// previous day will be scheduled to run every day at midnight
    lazy var scheduleStatisticsJobs: Bool = {
        return (Environment.get("XCMETRICS_SCHEDULE_STATISTICS_JOBS") ?? "0") == "1"
    }()

    /// Connect to CloudSQL using Sockets. This is the preferred way to connect to it when running in CloudSQL
    lazy var useCloudSQLSocket: Bool = {
        return (Environment.get("XCMETRICS_USE_CLOUDSQL_SOCKET") ?? "0") == "1"
    }()

    lazy var cloudSQLConnectionName: String? = {
        return Environment.get("XCMETRICS_CLOUDSQL_CONNECTION_NAME")
    }()

    lazy var databaseHost: String = {
        return Environment.get("DB_HOST") ?? "localhost"
    }()

    lazy var databasePort: Int = {
        return Int(Environment.get("DB_PORT") ?? "5432") ?? 5432
    }()

    lazy var databaseName: String = {
        return Environment.get("DB_NAME") ?? "xcmetrics-dev"
    }()

    lazy var databaseUser: String = {
        return Environment.get("DB_USER") ?? "xcmetrics-dev"
    }()

    lazy var databasePassword: String = {
        return Environment.get("DB_PASSWORD") ?? "xcmetrics-dev"
    }()

    lazy var redisHost: String = {
        return Environment.get("REDIS_HOST") ?? "127.0.0.1"
    }()

    lazy var redisPort: Int = {
        return Int(Environment.get("REDIS_PORT") ?? "6379") ?? 6379
    }()

    lazy var redisPassword: String? = {
        return Environment.get("REDIS_PASSWORD")
    }()

    ///  Connection Timeout for Redis in Seconds
    ///  Default value: 3 seconds
    lazy var redisConnectionTimeout: TimeAmount = {
        let seconds = Int64(Environment.get("REDIS_CONNECTION_RETRY_TIMEOUT") ?? "3") ?? 3
        return .seconds(seconds)
    }()

    lazy var redactUserData: Bool = {
        return (Environment.get("XCMETRICS_REDACT_USER_DATA") ?? "0") == "1"
    }()

    lazy var googleProject: String? = {
        return Environment.get("XCMETRICS_GOOGLE_PROJECT")
    }()

    lazy var gcsBucket: String? = {
        return Environment.get("XCMETRICS_GCS_BUCKET")
    }()

    lazy var googleCredentialsFile: String? = {
        return Environment.get("GOOGLE_APPLICATION_CREDENTIALS")
    }()

    /// URL of the site allowed to make CORS requests (usually the web client)
    /// Defaults to http://localhost:3000
    lazy var corsAllowed: String = {
        return Environment.get("XCMETRICS_CORS_ALLOWED") ?? "http://localhost:3000"
    }()

    /// Use Amazon S3 to store the logs.
    lazy var useS3LogRepository: Bool = {
        return (Environment.get("XCMETRICS_USE_S3_REPOSITORY") ?? "0") == "1"
    }()

    /// Amazon AWS Access Key of an account with permissions to write and read to an S3's bucket
    lazy var awsAccessKeyId: String? = {
        return Environment.get("AWS_ACCESS_KEY_ID")
    }()

    /// Amazon AWS Secret Access Key of an account with permissions to write and read to an S3's bucket
    lazy var awsSecretAccessKey: String? = {
        return Environment.get("AWS_SECRET_ACCESS_KEY")
    }()

    /// Name of the S3 Bucket to use to store logs
    lazy var s3Bucket: String? = {
        return Environment.get("XCMETRICS_S3_BUCKET")
    }()

    /// Name of the S3 region where the Bucket is located. i.e. `eu-west-1`
    /// Use the name listed in the `region` column [here](https://docs.aws.amazon.com/general/latest/gr/s3.html)
    lazy var s3Region: String? = {
        return Environment.get("XCMETRICS_S3_REGION")
    }()

    /// The Bazel BES Server endpoint to proxy metrics to
    lazy var besTarget: String? = {
        return Environment.get("XCMETRICS_BES_TARGET")
    }()

    /// The auth token to pass as Authorization header to BES endpoint
    lazy var besAuthToken: String? = {
        Environment.get("XCMETRICS_BES_AUTH_TOKEN")
    }()

    /// The optional BES Project ID
    lazy var besProjectId: String? = {
        Environment.get("XCMETRICS_BES_PROJECT_ID")
    }()

    /// Optional keywords for BES
    lazy var besKeywords: String? = {
        Environment.get("XCMETRICS_BES_KEYWORDS")
    }()
}

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

import Fluent
import Foundation

/// Status of a Log
enum JobLogStatus: String, Codable {
    case pending
    case running
    case successful
    case failed
}

/// Represents an entry for a log that holds all the logs received data
public final class JobLogEntry: Model {

    public static let schema = "job_log_entries"

    /// Id, we use the name of the `xcactivity` log file as identifier.
    @ID(custom: .id, generatedBy: IDProperty.Generator.user)
    public var id: String?


    @Field(key: "log_file")
    var logFile: String

    /// URL where the log was stored in the backend.
    @OptionalField(key: "log_url")
    var logURL: String?

    /// Status of the log.
    @Enum(key: "status")
    var status: JobLogStatus

    /// String with the last known error.
    @OptionalField(key: "error")
    var error: String?

    /// The date the Log was queued at.
    @Field(key: "queued_at")
    var queuedAt: Date

    /// The date the Log was dequeued at.
    @OptionalField(key: "dequeued_at")
    var dequeuedAt: Date?

    /// The date the log was processed either successfully or with an error.
    @OptionalField(key: "finished_at")
    var finishedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    public init() {}

    init(id: String, logFile: String, logURL: String?, status: JobLogStatus, error: String?,
         queuedAt: Date, dequeuedAt: Date?, finishedAt: Date?) {
        self.id = id
        self.logFile = logFile
        self.logURL = logURL
        self.status = status
        self.error = error
        self.queuedAt = queuedAt
        self.dequeuedAt = dequeuedAt
        self.finishedAt = finishedAt
    }
}

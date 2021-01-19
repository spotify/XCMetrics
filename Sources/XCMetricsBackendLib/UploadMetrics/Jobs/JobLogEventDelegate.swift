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
import Queues
import Vapor

/// Logs the Job status to a Repository
struct JobLogEventDelegate: JobEventDelegate {

    let logger: Logger
    let repository: JobLogRepository

    func dispatched(job: JobEventData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        if job.xcm_isProcessMetricsJob() {
            guard let request = try? JSONDecoder().decode(UploadMetricsRequest.self, from: Data(job.payload)) else {
                logger.error("Couldn't decode UploadMetricsRequest in JobLogEventDelegate")
                return eventLoop.future()
            }
            let entry = JobLogEntry(id: job.id,
                                    logFile: request.logURL.lastPathComponent,
                                    logURL: request.logURL.absoluteString,
                                    status: .pending,
                                    error: nil,
                                    queuedAt: job.queuedAt,
                                    dequeuedAt: nil,
                                    finishedAt: nil)
            return repository.create(entry, using: eventLoop.next())
        }
        return eventLoop.future()
    }

    func didDequeue(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return repository.update(jobId, status: .running, error: nil, using: eventLoop.next())
    }

    func success(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return repository.update(jobId, status: .successful, error: nil, using: eventLoop.next())
    }

    func error(jobId: String, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return repository.update(jobId, status: .failed, error: error, using: eventLoop.next())
    }

}

extension JobEventData {

    func xcm_isProcessMetricsJob() -> Bool {
        return jobName == String(describing: ProcessMetricsJob.self)
    }
}

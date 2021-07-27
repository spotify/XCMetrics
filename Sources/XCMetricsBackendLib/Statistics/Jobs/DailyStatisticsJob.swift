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

import Vapor
import Fluent
import FluentSQL
import Queues

struct DailyStatisticsJob: ScheduledJob {

    let repository: StatisticsRepository;

    init(repository: StatisticsRepository) {
        self.repository = repository;
    }

    func run(context: QueueContext) -> EventLoopFuture<Void> {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return repository.createDayCount(day: yesterday, using: context.eventLoop)
            .and(repository.createDayBuildTime(day: yesterday, using: context.eventLoop))
            .transform(to: context.eventLoop.makeSucceededFuture(()))
    }
}

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

/// Struct that holds Time Series data
public struct ChartTimeSeries: Content {
    var key: String
    var value: Double
}

/// Info about the Jobs
public struct JobDashboard: Content {

    /// Starting date used to get the data.
    var from: Date

    /// End date used to get the data.
    var to: Date

    /// Number of successful logs processed between the dates.
    var successful: Int

    /// Number of logs that are running between the dates.
    var running: Int

    /// Number of failed jobs between the dates.
    var failed: Int

    /// Number of pending jobs found between the given dates.
    var pending: Int

    /// Average processing time during the given dates.
    var averageTime: Double

    /// TimeSeries with the average processing time per hour.
    var averageTimes: [ChartTimeSeries] = []

    /// TimeSeries with the througput per hour.
    var throughput: [ChartTimeSeries] = []

}

extension JobDashboard {

    func with(averageTime newAverageTime: Double?) -> JobDashboard {
        return JobDashboard(from: self.from,
                            to: self.to,
                            successful: self.successful,
                            running: self.running,
                            failed: self.failed,
                            pending: self.pending,
                            averageTime: newAverageTime ?? self.averageTime,
                            averageTimes: self.averageTimes,
                            throughput: self.throughput)
    }

    func with(averageTimes newAverageTimes: [ChartTimeSeries], throughput newThroughput: [ChartTimeSeries]) -> JobDashboard {
        return JobDashboard(from: self.from,
                            to: self.to,
                            successful: self.successful,
                            running: self.running,
                            failed: self.failed,
                            pending: self.pending,
                            averageTime: self.averageTime,
                            averageTimes: newAverageTimes,
                            throughput: newThroughput)
    }
}

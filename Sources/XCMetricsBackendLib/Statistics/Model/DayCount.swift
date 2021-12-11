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

public final class DayCount: DayData {

    public static let schema = "statistics_day_counts";

    @ID(custom: "day")
    public var id: Date?;

    @Field(key: "build_count")
    var builds: Int;

    @Field(key: "error_count")
    var errors: Int;

    public convenience init() {
        self.init(day: Date().xcm_truncateTime())
    }

    public convenience init(day: Date) {
        self.init(day: day, builds: 0, errors: 0)
    }

    init(day: Date, builds: Int = 0, errors: Int = 0) {        
        self.id = day;
        self.builds = builds;
        self.errors = errors;
    }
}

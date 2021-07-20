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

extension Date {

    /// Returns the `Date` represented by a String in the format used by the Partitioned tables
    /// - Parameter day: String with a day in format yyyyMMdd, example: `20201231`
    /// - Returns: A `Date` if the `day` could be parsed, `nil` if not
    static func xcm_fromPartitionDay(_ day: String) -> Date? {
        let parser = xcm_getPartitionedTableFormatter()
        return parser.date(from: day)
    }

    /// Returns the date formatted with the format
    /// used to create the Day-sharding tables in Postgres
    /// - Returns: A `String` with the date formatted with format yyyyMMdd
    func xcm_toPartitionedTableFormat() -> String {
        return Self.xcm_getPartitionedTableFormatter().string(from: self)
    }

    /// Sets the time components of a date to 0, with no regards to time zone
    /// which can be useful when comparing to database dates (with no time information)
    /// - Returns: A `Date` with time components at 0
    func xcm_truncateTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        components.timeZone = TimeZone(abbreviation: "UTC")
        return Calendar.current.date(from: components)!
    }

    private static func xcm_getPartitionedTableFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }

}

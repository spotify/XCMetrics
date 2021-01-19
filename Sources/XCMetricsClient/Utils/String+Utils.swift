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

extension String {
    static let xcactivitylog = "xcactivitylog"

    var isUploadedFilePath: Bool {
        return hasSuffix(Constants.uploadedFileNameSuffix)
    }

    var isUploadLogFilePath: Bool {
        return !isUploadedFilePath
    }

    /// Returns a String with the first match of the regular expression
    /// - parameter pattern: A valid Regexp pattern
    /// - returns: `nil` if the pattern is invalid or not found. A `String` with the first match of the pattern if
    /// there is at least one match.
    public func firstMatchOfPattern(_ pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
            guard
                let match = matches.first,
                let swiftRange = Range(match.range(at: 1), in: self) else {
                    return nil
            }
            return String(self[swiftRange])
        } catch {
            return nil
        }
    }

    /// Parses a string that contains a date in ISO8601 format
    ///
    /// The format is the one used by git: 2019-11-18 10:48:43 +0100
    /// - Returns: The date representation as TimeInterval since 1970 or nil
    /// if the date couldn't be parsed
    public func getTimeIntervalFromISODate() -> TimeInterval? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear,
                                   .withMonth,
                                   .withDay,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime,
                                   .withSpaceBetweenDateAndTime,
                                   .withInternetDateTime]
        return formatter.date(from: self)?.timeIntervalSince1970
    }
}

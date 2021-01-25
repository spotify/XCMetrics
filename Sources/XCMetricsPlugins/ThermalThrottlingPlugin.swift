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
import XCMetricsClient
import XCMetricsUtils

public struct ThermalThrottlingPlugin {

    private let shell: ShellOutFunction

    public init(shell: @escaping ShellOutFunction = shellGetStdout) {
        self.shell = shell
    }

    public func create() -> XCMetricsPlugin {
        return XCMetricsPlugin(name: "Thermal Throttling", body: { _ -> [String : String] in
            let captureGroup = "cpuspeed"
            let regex = "[.\n]*CPU_Speed_Limit \t= (?<\(captureGroup)>[0-9]*)"

            guard let thermStdout = try? shell("pmset", ["-g", "therm"], nil, nil) else { return [:] }
            let nsrange = NSRange(thermStdout.startIndex..<thermStdout.endIndex, in: thermStdout)
            let reg = try! NSRegularExpression(pattern: regex, options: [])
            var cpuSpeedLimit: String?
            reg.enumerateMatches(in: thermStdout, options: [], range: nsrange) { match, _, stop in
                guard let match = match else { return }
                let matchRange = match.range(withName: captureGroup)
                if matchRange.location != NSNotFound, let range = Range(matchRange, in: thermStdout) {
                    cpuSpeedLimit = String(thermStdout[range])
                }
            }
            if let value = cpuSpeedLimit {
                return ["CPU_Speed_Limit": value]
            } else {
                return [:]
            }
        })
    }
}

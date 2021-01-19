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
import XCMetricsUtils
@testable import XCMetricsClient

/// Error thrown by SysctlHelper
enum SysctlHelperError: LocalizedError {
    case sysctlError(String)

    var localizedDescription: String {
        switch self {
        case .sysctlError(let message):
            return message
        }
    }
}

/// Helper to get Host info from the sysctl command line tool
class SysctlHelper {

    /// Path to sysctl utility
    let sysctl_path = "/usr/sbin/sysctl"

    /// Args to print all the values using "=" to separate names from values
    let allValuesArgs = ["-a", "-e"]

    /// Args to print the hardware model. This value is not included when running `sysctl -a`
    let hardwareModelArgs = ["-e", "hw.model"]

    /// Args to print the Swap memory usage
    let swapUsageArgs = ["-n", "vm.swapusage"]

    /// Args to print the uptime
    let uptimeArgs = ["-n", "kern.boottime"]

    /// Returns the output of invoking `sysctl -a -e`
    /// plus some other special values that need to be parsed manually:
    /// the swap usage, the hardware model and the uptime
    /// - returns: A dictionary with the keys and values
    /// - throws: An error if sysctl fails
    func getAllValues() throws -> [String: String] {
        let kernelState = try getKernelState()
        let hardwareModel = try getHardwareModel()
        let swapUsage = try getSwapUsage()
        let uptime = try getUptime()
        return kernelState
               .merging(hardwareModel) { (_, new) in new }
               .merging(swapUsage) { (_, new) in new }
               .merging(uptime) { (_, new) in new }
    }

    /// Returns the output of invoking `sysctl -a -e`
    /// - returns: A dictionary with the keys and values
    /// - throws: An error if sysctl fails
    private func getKernelState() throws -> [String: String] {
        return try getSysctlValuesForArgs(allValuesArgs)
    }

    /// Returns the hardware model
    /// - returns: A dictionary with the key "hw.model" and the model in the value
    /// - throws: An error if sysctl fails
    private func getHardwareModel() throws -> [String: String] {
        return try getSysctlValuesForArgs(hardwareModelArgs)
    }

    /// Returns the swap usage data
    /// - returns: A dictionary with the keys `vm.swapusage.total` and `vm.swapusage.free`
    /// - throws: An error is sysctl fails or if the parsing of sysctl's `vm.swapusage` value fails
    private func getSwapUsage() throws -> [String: String] {
        let output = try getSysctlOutputForArgs(swapUsageArgs)

        /// the output has the format total = 1024.00M  used = 357.00M  free = 667.00M  (encrypted)
        /// we get the total and the free to use in out tests
        let totalPattern = "\\s*([\\d\\.]*)M\\s*used"
        guard let totalValue = output.firstMatchOfPattern(totalPattern) else {
            throw SysctlHelperError.sysctlError("The value for total swap is invalid \(output)")
        }
        let freePattern = "free\\s=\\s([\\d\\.]*)M"
        guard let freeValue = output.firstMatchOfPattern(freePattern) else {
            throw SysctlHelperError.sysctlError("The value for free swap is invalid \(output)")
        }
        return ["vm.swapusage.total": totalValue, "vm.swapusage.free": freeValue]
    }

    /// Returns the uptime in seconds
    /// - returns: A dictionary with the key `kern.boottime`
    /// - throws: An error is sysctl fails or if the parsing of sysctl's `kern.boottime` value fails
    private func getUptime() throws -> [String: String] {
        let uptime = try getSysctlOutputForArgs(uptimeArgs)
        // output has this format { sec = 1566199966, usec = 717363 } Mon Aug 19 09:32:46 2019
        // we only need the sec value
        let pattern = "\\ssec = (\\d*)"
        guard let value = uptime.firstMatchOfPattern(pattern) else {
            throw SysctlHelperError.sysctlError("The value for uptime is invalid \(uptime)")
        }
        return ["kern.boottime": value]
    }

    /// Returns the output of `sysctl` as a dictionary
    /// - param args: The params for the `sysctl` command
    /// - returns: A dictionary where the keys are the name of the `sysctl` properties and the values as `String`
    /// - throws: An `SysctlHelperError` if the command fails
    private func getSysctlValuesForArgs(_ args: [String]) throws -> [String: String] {
        let output = try getSysctlOutputForArgs(args)
        return output.components(separatedBy: "\n")
            .filter { $0.isEmpty == false }
            .reduce(into: [String: String]()) { dictionary, line in
                let keyValue = line.components(separatedBy: "=")
                return dictionary[keyValue[0]] = keyValue[1]
        }
    }

    /// Returns the output of `sysctl` as a `String`
    /// - param args: The params for the `sysctl` command
    /// - returns: A `String` with the output of the command
    /// - throws: An `Error` if the command fails
    private func getSysctlOutputForArgs(_ args: [String]) throws -> String {
        return try shellGetStdout(sysctl_path, args: args)        
    }

}

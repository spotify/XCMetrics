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

import XCTest
@testable import XCMetricsClient

class BuildHostFetcherTests: XCTestCase {

    static var sysCtlKernelState: [String: String] = [:]

    static var buildHost: BuildHost!

    override class func setUp() {
        super.setUp()
        let sysCtlHelper = SysctlHelper()
        do {
            self.buildHost = try HardwareFactsFetcherImplementation().fetch()
            self.sysCtlKernelState = try sysCtlHelper.getAllValues()
        } catch {
            XCTFail("Could not get info from sysctl: \(error.localizedDescription)")
        }
    }

    func testCpuModel() {
        XCTAssertEqual(Self.buildHost.cpuModel,
                       Self.sysCtlKernelState[SysctlProperty.cpuModel.rawValue],
                       "The CPU model does not match what sysctl reported")
    }

    func testCpuNumber() {
        guard let cpuNumberValue = Self.sysCtlKernelState[SysctlProperty.cpuCount.rawValue],
            let expectedCpuNumber = Int32(cpuNumberValue) else {
                XCTFail("\(SysctlProperty.cpuCount.rawValue) property not found in sysctl output or is not an UInt32")
                return
        }
        XCTAssertEqual(Self.buildHost.cpuCount,
                       expectedCpuNumber,
                       "The number of CPUs does not match what sysctl reported")
    }

    func testCPUSpeedGhz() {
        guard let cpuSpeedValue = Self.sysCtlKernelState[SysctlProperty.cpuFrequencyMax.rawValue],
        let expectedCpuSpeed = Float(cpuSpeedValue) else {
            XCTFail("\(SysctlProperty.cpuFrequencyMax.rawValue) property not found in sysctl output or is not a Float")
            return
        }
        XCTAssertEqual(Self.buildHost.cpuSpeedGhz,
                       expectedCpuSpeed / 1_000_000_000,
                       "The CPU speed does not match what sysctl reported")
    }

    func testHostArchitecture() {
        XCTAssertFalse(Self.buildHost.hostArchitecture.isEmpty,
                       "The Host architecture can not be empty")
    }

    func testHostModel() {
        XCTAssertEqual(Self.buildHost.hostModel,
                       Self.sysCtlKernelState[SysctlProperty.hardwareModel.rawValue],
                       "The host model does not match what sysctl reported")
    }

    func testHostOSFamily() {
        XCTAssertEqual(Self.buildHost.hostOsFamily,
                       Self.sysCtlKernelState[SysctlProperty.hostOSFamily.rawValue],
                       "The OS family does not match what sysctl reported")
    }

    func testHostOSVersion() {
        XCTAssertEqual(Self.buildHost.hostOsVersion,
                       Self.sysCtlKernelState[SysctlProperty.osVersion.rawValue],
                       "The OS Version does not match what sysctl reported")
    }

    func testMemoryTotalMb() {
        guard let totalMemoryValue = Self.sysCtlKernelState[SysctlProperty.memoryTotal.rawValue],
            let expectedTotalMemory = Double(totalMemoryValue) else {
                XCTFail("\(SysctlProperty.memoryTotal.rawValue) property not found in sysctl output or is not a Double")
                return
        }
        XCTAssertEqual(Self.buildHost.memoryTotalMb,
                       expectedTotalMemory.bytesToMB(),
                       "The total memory does not match what sysctl reported")
    }

    func testMemoryFreeMb() {
        XCTAssertGreaterThan(Self.buildHost.memoryFreeMb,
                             0.0,
                             "The host should have some free memory")
    }

    func testSwapTotalMb() {
        guard let swapMemoryValue = Self
                                .sysCtlKernelState["\(SysctlProperty.swapUsage.rawValue).total"],
            let expectedSwapMemory = Double(swapMemoryValue)
        else {
                XCTFail("\(SysctlProperty.swapUsage.rawValue).total property not found or is not a Double")
                return
        }
        XCTAssertEqual(Self.buildHost.swapTotalMb,
                       expectedSwapMemory,
                       "The total swap memory does not match what sysctl reported")
    }

    func testUptimeSeconds() {
        guard let uptimeValue = Self.sysCtlKernelState[SysctlProperty.uptime.rawValue],
            let expectedUptime = Int64(uptimeValue) else {
                XCTFail("\(SysctlProperty.uptime.rawValue) property not found in sysctl output or is not an UInt32")
                return
        }
        XCTAssertGreaterThanOrEqual(expectedUptime,
                       Self.buildHost.uptimeSeconds,
                       "The uptime does not match what sysctl reported")
    }

    func testTimeZone() {
        XCTAssertFalse(Self.buildHost.timezone.isEmpty, "The timeZone should not be empty")
    }

    func testIsVirtual() {
        guard let hardwareModel = Self.sysCtlKernelState[SysctlProperty.hardwareModel.rawValue]
        else {
            XCTFail("\(SysctlProperty.hardwareModel.rawValue) property not found in sysctl output")
            return
        }
        XCTAssertEqual(hardwareModel.starts(with: "VMware"),
                       Self.buildHost.isVirtual,
                       "Incorrect isVirtual value")
    }

    func testHostOS() throws {
        let expectedProductName = try SwVersHelper.getProductName()
        XCTAssertEqual(expectedProductName, Self.buildHost.hostOs,
                       "The HostOS should be the same reported by sw_vers")
    }

}

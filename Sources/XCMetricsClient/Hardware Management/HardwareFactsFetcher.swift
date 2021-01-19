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
import Darwin

enum HardwareFactsFetcherError: LocalizedError {
    case systemInfoError(String)

    var localizedDescription: String {
        switch self {
        case .systemInfoError(let systemInfoPath):
            return "\(systemInfoPath) file not found in host."
        }
    }
}

/// Enum with the name of some `sysctl` property names
enum SysctlProperty: String {
    case cpuModel = "machdep.cpu.brand_string"
    case cpuCount = "hw.ncpu"
    case cpuFrequencyMax = "hw.cpufrequency_max"
    case hardwareModel = "hw.model"
    case hostOSFamily = "kern.ostype"
    case memoryTotal = "hw.memsize"
    case memoryPageSize = "vm.pagesize"
    case memoryPageFreeCount = "vm.page_free_count"
    case memoryPageSpeculativeCount = "vm.page_speculative_count"
    case swapUsage = "vm.swapusage"
    case uptime = "kern.boottime"
    case osVersion = "kern.osproductversion"
    case sleepTime = "kern.sleeptime"
}

protocol HardwareFactsFetcher {

    /// Fetches the Hardware facts of the current host
    /// - Returns: An instance of `HardwareFacts`
    /// - Throws: An `HardwareFactsFetcherError` if there was an error fetching the facts
    func fetch() throws -> BuildHost

}

/// Gets the Hardware facts for the host, it usually relies on `sysctlbyname` to get them
class HardwareFactsFetcherImplementation: HardwareFactsFetcher {

    private static let systemVersionPath = "/System/Library/CoreServices/SystemVersion.plist"

    func fetch() throws -> BuildHost {
        var facts = BuildHost()
        facts.cpuCount = Int32(self.cpuCount)
        facts.cpuModel = self.cpuModel
        facts.cpuSpeedGhz = self.cpuSpeedGhz
        facts.hostArchitecture = self.hostArchitecture
        facts.hostModel = self.hostModel
        facts.hostOs = try self.getHostOS()
        facts.hostOsFamily = self.hostOSFamily
        facts.hostOsVersion = self.hostOSVersion
        facts.isVirtual = self.isVirtual
        facts.memoryFreeMb = self.memoryFreeMb
        facts.memoryTotalMb = self.memoryTotalMb
        facts.swapFreeMb = self.swapFreeMb
        facts.swapTotalMb = self.swapTotalMb
        facts.timezone = self.timeZone
        facts.uptimeSeconds = Int64(self.uptimeSeconds)
        return facts
    }

    /// Value read from `SystemVersion.plist`. Could be either `Mac OS X` or `Mac OS X Server`
    func getHostOS() throws -> String {
        let systemVersionPath = HardwareFactsFetcherImplementation.systemVersionPath
        guard let systemInfo = NSDictionary(contentsOfFile: systemVersionPath),
            let productName = systemInfo["ProductName"] as? String else {
                throw HardwareFactsFetcherError.systemInfoError(systemVersionPath)
        }
        return productName
    }

    /// Model of the CPU as returned by the `machdep.cpu.brand_string` sysctl property
    lazy var cpuModel: String = {
        return getPropertyStringValue(.cpuModel)
    }()

    /// Number of CPUs as returned by the `hw.ncpu` sysctl property
    lazy var cpuCount: UInt32 = {
        return getPropertyUInt32Value(.cpuCount)
    }()

    /// The architecture used by the host as returned by `utsname.machine`
    lazy var hostArchitecture: String = {
        var utsName = utsname()
        uname(&utsName)
        let machineMirror = Mirror(reflecting: utsName.machine)
        let machine = machineMirror.children.compactMap { child -> String? in
            guard let value = child.value as? Int8, value != 0 else {
                return nil
            }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
        return machine
    }()

    /// The model of the Host as returned by sysctl's `hw.model` property
    lazy var hostModel: String = {
        return getPropertyStringValue(.hardwareModel)
    }()

    /// The family of the Host (Darwin) as returned by sysctl's `kern.ostype` property
    lazy var hostOSFamily: String = {
        return getPropertyStringValue(.hostOSFamily)
    }()

    /// The CPU's frequency in Ghz as returned by sysctl's `hw.cpufrequency_max` property
    lazy var cpuSpeedGhz: Float = {
        let speedHertz = getPropertyUInt32Value(.cpuFrequencyMax)
        return Float(Int64(speedHertz)) / 1_000_000_000
    }()

    lazy var hostOSVersion: String = {
        return getPropertyStringValue(.osVersion)
    }()

    /// The amount of memory in MB the host has, as reported by sysctl's `hw.memsize` property
    lazy var memoryTotalMb: Double = {
        let memoryTotal = getPropertyUInt64Value(.memoryTotal)
        return Double(Int64(memoryTotal)).bytesToMB()
    }()

    /// The amount of free memory in MB that the host has.
    /// uses the same formula
    /// [that Facter uses](https://github.com/puppetlabs/facter/blob/main/lib/src/facts/osx/memory_resolver.cc)
    lazy var memoryFreeMb: Double = {
        let hostInfo = vm_statistics64_t.allocate(capacity: 1)
        var size = hostVMInfo64Count
        _ = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics64(mach_host_self(),
                              HOST_VM_INFO64,
                              $0,
                              &size)
        }
        let data = hostInfo.move()
        hostInfo.deallocate()
        let pageSize = Int64(getPropertyUInt32Value(.memoryPageSize))
        let freePages = Int64(data.free_count)
        let speculativePages = Int64(data.speculative_count)
        return Double((freePages - speculativePages) * pageSize).bytesToMB()
    }()

    /// The amount of Swap memory in MB, as reported by sysctl's `vm.swapusage` property
    lazy var swapTotalMb: Double = {
        var size = getPropertySize(.swapUsage)
        var xswUsage = xsw_usage()
        sysctlbyname(SysctlProperty.swapUsage.rawValue, &xswUsage, &size, nil, 0)
        return Double(Int64(xswUsage.xsu_total)) / 1_048_576
    }()

    /// The amount of Swap memory in MB, as reported by sysctl's `vm.swapusage` property
    lazy var swapFreeMb: Double = {
        var size = getPropertySize(.swapUsage)
        var xswUsage = xsw_usage()
        sysctlbyname(SysctlProperty.swapUsage.rawValue, &xswUsage, &size, nil, 0)
        return Double(Int64(xswUsage.xsu_total - xswUsage.xsu_used)).bytesToMB()
    }()

    /// The uptime in seconds as reported by sysctl's `kern.boottime` property
    lazy var uptimeSeconds: Int = {
        var size = getPropertySize(.uptime)
        var bootTime = timeval()
        sysctlbyname(SysctlProperty.uptime.rawValue, &bootTime, &size, nil, 0)
        return bootTime.tv_sec
    }()

    /// The last time the device went to sleep as reported by sysctl's `kern.sleeptime` property.
    lazy var sleepTime: Int = {
        var size = getPropertySize(.sleepTime)
        var sleepTime = timeval()
        sysctlbyname(SysctlProperty.sleepTime.rawValue, &sleepTime, &size, nil, 0)
        return sleepTime.tv_sec
    }()

    /// The Host's time zone. It will return an abreviation when possible (like CEST), if not, it will
    /// failback to use the whole time zone identifier
    lazy var timeZone: String = {
        return TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }()

    /// True if the host is a VMware instance, false otherwise.
    lazy var isVirtual: Bool = {
        if hostModel.starts(with: "VMware") {
            return true
        }
        //TODO missing support for VirtualBox and Parallels
        return false
    }()

    private let hostVMInfo64Count =
        UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

    /// Get a `sysctl` property as a String
    /// - parameter property: The property to get
    /// - returns: A String with the value of the property.
    /// This don't check that the property type is actually a `String`. Please check the sysctl help to know it.
    private func getPropertyStringValue(_ property: SysctlProperty) -> String {
        var size = getPropertySize(property)
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname(property.rawValue, &value, &size, nil, 0)
        return String(cString: value)
    }

    /// Get a `sysctl` property as a UInt32
    /// - parameter property: The property to get
    /// - returns: A String with the value of the property.
    /// This don't check that the property type is actually a `UInt32`. Please check the sysctl help to know it.
    /// If the property is not a valid UInt32, this function returns 0
    private func getPropertyUInt32Value(_ property: SysctlProperty) -> UInt32 {
        var size = getPropertySize(property)
        var value: UInt32 = 0
        sysctlbyname(property.rawValue, &value, &size, nil, 0)
        return value
    }

    /// Get a `sysctl` property as a UInt64
    /// - parameter property: The property to get
    /// - returns: A String with the value of the property.
    /// This don't check that the property type is actually a `UInt64`. Please check the sysctl help to know it.
    /// If the property is not a valid UInt32, this function returns 0
    private func getPropertyUInt64Value(_ property: SysctlProperty) -> UInt64 {
        var size = getPropertySize(property)
        var value: UInt64 = 0
        sysctlbyname(property.rawValue, &value, &size, nil, 0)
        return value
    }

    /// Get the size of a `sysctl` property
    /// - parameter property: A valid `SysctlProperty`
    /// - returns: An `Int` with the size in bytes of the property value
    private func getPropertySize(_ property: SysctlProperty) -> Int {
        var size: Int = 0
        sysctlbyname(property.rawValue, nil, &size, nil, 0)
        return size
    }

}

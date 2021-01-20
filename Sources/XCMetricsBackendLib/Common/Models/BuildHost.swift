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

import Fluent
import Vapor

public final class BuildHost: Model, Content, PartitionedByDay {

    public static let schema = "build_hosts"

    public init() { }

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "build_identifier")
    var buildIdentifier: String

    @Field(key: "host_os")
    var hostOs: String

    @Field(key: "host_architecture")
    var hostArchitecture: String

    @Field(key: "host_model")
    var hostModel: String

    @Field(key: "host_os_family")
    var hostOsFamily: String

    @Field(key: "host_os_version")
    var hostOsVersion: String

    @Field(key: "cpu_model")
    var cpuModel: String

    @Field(key: "cpu_count")
    var cpuCount: Int32

    @Field(key: "cpu_speed_ghz")
    var cpuSpeedGhz: Float

    @Field(key: "memory_total_mb")
    var memoryTotalMb: Double

    @Field(key: "memory_free_mb")
    var memoryFreeMb: Double

    @Field(key: "swap_total_mb")
    var swapTotalMb: Double

    @Field(key: "swap_free_mb")
    var swapFreeMb: Double

    @Field(key: "uptime_seconds")
    var uptimeSeconds: Int64

    @Field(key: "timezone")
    var timezone: String

    @Field(key: "is_virtual")
    var isVirtual: Bool

    @Field(key: "day")
    var day: Date?

}

extension BuildHost {

    convenience init(id: UUID?, buildIdentifier: String, hostOs: String, hostArchitecture: String, hostModel: String,
         hostOsFamily: String, hostOsVersion: String, cpuModel: String, cpuCount: Int32, cpuSpeedGhz: Float,
         memoryTotalMb: Double, memoryFreeMb: Double, swapTotalMb: Double, swapFreeMb: Double,
         uptimeSeconds: Int64, timezone: String, isVirtual: Bool, day: Date?) {
        self.init()
        self.id = id
        self.buildIdentifier = buildIdentifier
        self.hostOs = hostOs
        self.hostArchitecture = hostArchitecture
        self.hostModel = hostModel
        self.hostOsFamily = hostOsFamily
        self.hostOsVersion = hostOsVersion
        self.cpuCount = cpuCount
        self.cpuModel = cpuModel
        self.cpuSpeedGhz = cpuSpeedGhz
        self.memoryFreeMb = memoryFreeMb
        self.memoryTotalMb = memoryTotalMb
        self.swapFreeMb = swapFreeMb
        self.swapTotalMb = swapTotalMb
        self.uptimeSeconds = uptimeSeconds
        self.timezone = timezone
        self.isVirtual = isVirtual
        self.day = day
    }

    func withBuildIdentifier(_ newBuildIdentifier: String) -> BuildHost {
        return BuildHost(id: id,
                         buildIdentifier: newBuildIdentifier,
                         hostOs: hostOs,
                         hostArchitecture: hostArchitecture,
                         hostModel: hostModel,
                         hostOsFamily: hostOsFamily,
                         hostOsVersion: hostOsVersion,
                         cpuModel: cpuModel,
                         cpuCount: cpuCount,
                         cpuSpeedGhz: cpuSpeedGhz,
                         memoryTotalMb: memoryTotalMb,
                         memoryFreeMb: memoryFreeMb,
                         swapTotalMb: swapTotalMb,
                         swapFreeMb: swapFreeMb,
                         uptimeSeconds: uptimeSeconds,
                         timezone: timezone,
                         isVirtual: isVirtual,
                         day: day)
    }
}

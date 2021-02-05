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

/// Info from the current build that is not in the Log and that is needed by the backend
final class ExtraInfo: Encodable {

    let projectName: String

    let machineName: String

    let user: String

    let isCI: Bool

    let sleepTime: Int

    init(projectName: String, machineName: String, user: String, isCI: Bool, sleepTime: Int) {
        self.projectName = projectName
        self.machineName = machineName
        self.user = user
        self.isCI = isCI
        self.sleepTime = sleepTime
    }
}

extension BuildHost: Encodable {
    enum CodingKeys: String, CodingKey {
        case buildIdentifier
        case hostOs
        case hostArchitecture
        case hostModel
        case hostOsFamily
        case hostOsVersion
        case cpuModel
        case cpuCount
        case cpuSpeedGhz
        case memoryTotalMb
        case memoryFreeMb
        case swapTotalMb
        case swapFreeMb
        case uptimeSeconds
        case timezone
        case isVirtual
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buildIdentifier, forKey: .buildIdentifier)
        try container.encode(hostOs, forKey: .hostOs)
        try container.encode(hostArchitecture, forKey: .hostArchitecture)
        try container.encode(hostModel, forKey: .hostModel)
        try container.encode(hostOsFamily, forKey: .hostOsFamily)
        try container.encode(hostOsVersion, forKey: .hostOsVersion)
        try container.encode(cpuModel, forKey: .cpuModel)
        try container.encode(cpuCount, forKey: .cpuCount)
        try container.encode(cpuSpeedGhz, forKey: .cpuSpeedGhz)
        try container.encode(memoryTotalMb, forKey: .memoryTotalMb)
        try container.encode(memoryFreeMb, forKey: .memoryFreeMb)
        try container.encode(swapTotalMb, forKey: .swapTotalMb)
        try container.encode(swapFreeMb, forKey: .swapFreeMb)
        try container.encode(uptimeSeconds, forKey: .uptimeSeconds)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(isVirtual, forKey: .isVirtual)
    }
}

extension BuildMetadata: Encodable {
    enum CodingKeys: String, CodingKey {
        case buildIdentifier
        case metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buildIdentifier, forKey: .buildIdentifier)
        try container.encode(metadata, forKey: .metadata)
    }
}

extension XcodeVersion: Encodable {
    enum CodingKeys: String, CodingKey {
        case buildIdentifier
        case version
        case buildNumber
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(buildIdentifier, forKey: .buildIdentifier)
        try container.encode(version, forKey: .version)
        try container.encode(buildNumber, forKey: .buildNumber)
    }
}

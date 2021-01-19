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
import XCMetricsProto

/// The Protobuf message describing the upload of a build.
public typealias UploadBuildMetricsRequest = Spotify_Xcmetrics_UploadBuildMetricsRequest
/// The Protobuf message describing a build.
public typealias Build = Spotify_Xcmetrics_Build
/// The Protobuf message describing a target in a build.
public typealias TargetBuild = Spotify_Xcmetrics_TargetBuild
/// The Protobuf message describing a note in a build.
public typealias NoteBuild = Spotify_Xcmetrics_NoteBuild
/// The Protobuf message describing a note in a build.
public typealias ErrorBuild = Spotify_Xcmetrics_ErrorBuild
/// The Protobuf message describing a warning in a build.
public typealias WarningBuild = Spotify_Xcmetrics_WarningBuild
/// The Protobuf message describing a step in a build.
public typealias StepBuild = Spotify_Xcmetrics_StepBuild
/// The Protobuf message describing the location and duration of a function compilation in a build.
public typealias FunctionBuild = Spotify_Xcmetrics_FunctionBuild
/// The Protobuf message describing the build host of a build.
public typealias BuildHost = Spotify_Xcmetrics_BuildHost
/// The Protobuf message describing the Xcode version of a build.
public typealias XcodeVersion = Spotify_Xcmetrics_XcodeVersion
/// The Protobuf message describing the build metadata of a build.
public typealias BuildMetadata = Spotify_Xcmetrics_BuildMetadata
/// The Protobuf message describing the Swift type check in a build.
public typealias SwiftTypeCheckBuild = Spotify_Xcmetrics_SwiftTypeCheckBuild

typealias MetricsServiceClient = Spotify_Xcmetrics_XCMetricsServiceClient

/// Describes the upload request managed by XCMetrics. This could either be a previously failed to upload request or a
/// newly produced request.
public struct MetricsUploadRequest: Equatable, Hashable {
    /// URL either pointing to an xcactivitylog or to an encoded request stored on disk which failed to upload previously.
    public let fileURL: URL
    /// A request object that will be populated with data.
    public let request: UploadBuildMetricsRequest

    init(fileURL: URL, request: UploadBuildMetricsRequest = UploadBuildMetricsRequest()) {
        self.fileURL = fileURL
        self.request = request
    }
}

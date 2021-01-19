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
import Vapor

/// Content of a Multipart request to upload Metrics
final class UploadMetricsPayload: Content {

    /// .xcactivitylog file
    let log: File

    /// Extra data needed in JSON format
    let extraInfo: Data

    /// Build host information in JSON format
    let buildHost: Data

    /// Xcode used during the build in JSON format
    let xcodeVersion: Data?

    /// Metadata from the plugins used in JSON format
    let buildMetadata: Data?
}


/// Request to upload Metrics sent to the UploadMetricsJob
final class UploadMetricsRequest: Codable {

    /// URL to the log file. Can be local or remote depending on the `LogFileRepository` configured
    let logURL: URL

    /// Extra data needed
    let extraInfo: ExtraInfo

    /// Build host information
    let buildHost: BuildHost

    /// Xcode used during the build
    let xcodeVersion: XcodeVersion?

    /// Metadata from the plugins used
    let buildMetadata: BuildMetadata?

    init(logURL : URL,
         extraInfo: ExtraInfo,
         buildHost: BuildHost,
         xcodeVersion: XcodeVersion?,
         buildMetadata: BuildMetadata?) {
        self.logURL = logURL
        self.extraInfo = extraInfo
        self.buildHost = buildHost
        self.xcodeVersion = xcodeVersion
        self.buildMetadata = buildMetadata
    }

    /// Transforms a `UploadMetricsPayload` to a `UploadMetricsRequest` by decoding the JSON content to domain models
    /// - Parameters:
    ///   - logURL: URL where the .xcactivitylog was stored by a `LogFileRepository`
    ///   - requestPayload: a `UploadMetricsRequest`
    /// - Throws: If the `requestPayload` does not contain valid JSON documents
    convenience init?(logURL: URL, payload: UploadMetricsPayload) throws {
        let decoder = JSONDecoder()

        let extraInfo = try decoder.decode(ExtraInfo.self, from: payload.extraInfo.xcm_onlyJsonContent())
        let buildHost = try decoder.decode(BuildHost.self, from: payload.buildHost.xcm_onlyJsonContent())
        let xcodeVersion: XcodeVersion?
        if let xcodeVersionData = payload.xcodeVersion?.xcm_onlyJsonContent() {
            xcodeVersion = try decoder.decode(XcodeVersion.self, from: xcodeVersionData)
        } else {
            xcodeVersion = nil
        }
        let buildMetadata: BuildMetadata?
        if let buildMetadataData = payload.buildMetadata?.xcm_onlyJsonContent() {
            buildMetadata = try decoder.decode(BuildMetadata.self, from: buildMetadataData)
        } else {
            buildMetadata = nil
        }
        self.init(logURL: logURL,
                  extraInfo: extraInfo,
                  buildHost: buildHost,
                  xcodeVersion: xcodeVersion,
                  buildMetadata: buildMetadata)

    }
}

/// Data needed from the client that did the build
final class ExtraInfo: Codable {

    /// Name of the Xcode project
    let projectName: String

    /// Name of the host where the build was done
    let machineName: String

    /// Name of the user that did the build
    let user: String

    /// True if the build was performed on a continuous integration machine, false otherwise.
    let isCI: Bool
}

extension ByteBuffer {

    /// Removes the Content-Type part of an `octet-stream` request content, leaving only the actual file content
    /// - Returns: The `ByteBuffer` removing the Content-Type part
    func xcm_onlyFileData() -> ByteBuffer {
        guard let contentType = "Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8) else {
            return self
        }
        var logData = self
        logData.moveReaderIndex(to: contentType.count)
        logData.discardReadBytes()
        return logData
    }

}

extension Data {
    /// Removes the Content-Type part of a `json` request content, leaving only the actual JSON document
    /// - Returns: The `Data` removing the Content-Type part
    func xcm_onlyJsonContent() -> Data {
        guard let contentType = "Content-Type: application/json\r\n\r\n".data(using: .utf8) else {
            return self
        }
        return self.advanced(by: contentType.count)
    }
}

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
import XCMetricsCommon

/// Creates a Nested Multipart Request to send the
/// `xcactivitylog` and the Metadata associated to it as `JSON` documents
/// in a single request
class MultipartRequestBuilder {

    public let request: MetricsUploadRequest
    public let url: URL
    public let additionalHeaders: [String: String]
    public let machineName: String
    public let projectName: String
    public let isCI: Bool
    public let skipNotes: Bool

    public init(request: MetricsUploadRequest,
                url: URL,
                additionalHeaders: [String: String],
                machineName: String,
                projectName: String,
                isCI: Bool,
                skipNotes: Bool) {
        self.request = request
        self.url = url
        self.additionalHeaders = additionalHeaders
        self.machineName = machineName
        self.projectName = projectName
        self.isCI = isCI
        self.skipNotes = skipNotes
    }

    public func build() throws -> URLRequest {
        // Use the file name UUID as the boundary.
        let uuid = self.request.fileURL.deletingPathExtension().lastPathComponent
        let boundary = "Boundary-\(uuid)"
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        additionalHeaders.forEach { request.addValue($1, forHTTPHeaderField: $0) }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // If this is a retry for a previously failed request, simply set the body. Otherwise compute it.
        let body: Data
        if self.request.fileURL.isRequestFile {
            body = try Data(contentsOf: self.request.fileURL)
        } else {
            body = try getBody(boundary: boundary)
        }
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = body

        return request
    }

    private func getBody(boundary: String) throws -> Data {
        let httpBody = NSMutableData()
        if let logData = try toBinaryFormField(
            named: "log",
            fileURL: request.fileURL,
            using: boundary
        ) {
            httpBody.append(logData)
        }

        let jsonEncoder = JSONEncoder()
        /// Backend will decide if the username will be stored hashed or not based on its configuration
        let user = MacOSUsernameReader().userID ?? "unknown"
        let sleepTime = HardwareFactsFetcherImplementation().sleepTime
        let extraInfo = UploadRequestExtraInfo(projectName: projectName,
                                               machineName: machineName,
                                               user: user,
                                               isCI: isCI,
                                               sleepTime: sleepTime,
                                               skipNotes: skipNotes,
                                               tag: request.request.build.tag)
        let extraJson = try jsonEncoder.encode(extraInfo)
        if let extraData = toJSONFormField(named: "extraInfo", jsonData: extraJson, using: boundary) {
          httpBody.append(extraData)
        }
        let buildHostJson = try jsonEncoder.encode(request.request.buildHost)
        if let buildHostData = toJSONFormField(named: "buildHost", jsonData: buildHostJson, using: boundary) {
            httpBody.append(buildHostData)
        }
        if !request.request.xcodeVersion.buildNumber.isEmpty {
            let jsonData = try jsonEncoder.encode(request.request.xcodeVersion)
            if let xcodeVersionData = toJSONFormField(named: "xcodeVersion",
                                               jsonData: jsonData,
                                               using: boundary) {
                httpBody.append(xcodeVersionData)
            }
        }
        if !request.request.buildMetadata.metadata.isEmpty {
            let jsonData = try jsonEncoder.encode(request.request.buildMetadata)
            if let buildMetadataData = toJSONFormField(named: "buildMetadata", jsonData: jsonData, using: boundary) {
                httpBody.append(buildMetadataData)
            }
        }
        if let end = "--\(boundary)--\r\n".data(using: .utf8) {
            httpBody.append(end)
        }
        return httpBody as Data
    }

    private func toJSONFormField(named name: String, jsonData: Data, using boundary: String) -> Data?  {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "\r\n"
        fieldString += "Content-Type: application/json\r\n\r\n"
        guard let fieldsData = fieldString.data(using: .utf8), let separator = "\r\n".data(using: .utf8) else {
            return nil
        }
        let data = NSMutableData()
        data.append(fieldsData)
        data.append(jsonData)
        data.append(separator)
        return data as Data
    }

    private func toBinaryFormField(named name: String, fileURL: URL, using boundary: String) throws -> Data?  {
        let fileData = try Data(contentsOf: fileURL)
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
        fieldString += "\r\n"
        fieldString += "Content-Type: application/octet-stream\r\n\r\n"
        guard let fieldsData = fieldString.data(using: .utf8), let separator = "\r\n".data(using: .utf8) else {
            return nil
        }
        let data = NSMutableData()
        data.append(fieldsData)
        data.append(fileData)

        data.append(separator)
        return data as Data
    }

}

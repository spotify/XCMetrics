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
import GRPC
import NIO
import NIOHPACK
import XCMetricsProto

/// Defines the required methods for a publisher service.
protocol MetricsPublisherService {
    /// Upload the given metrics and returns the result in a completion block.
    /// - Parameter serviceURL: The URL of the backend service where the metrics will be sent.
    /// - Parameter authorizationHeader: An authorization header to be sent with the request.
    /// - Parameter uploadRequests: The upload requests to be sent to the backend service.
    /// - Parameter completion: The result is successful if no error occurred. The .success enum case contains the URLs of the uploaded metrics.
    /// - Parameter projectName: The name of the project
    func uploadMetrics(
        serviceURL: URL,
        authorizationHeader: String?,
        projectName: String,
        isCI: Bool,
        uploadRequests: Set<MetricsUploadRequest>,
        completion: @escaping (_ successfulURLs: Set<URL>, _ failedURLs: [URL: Data]) -> Void
    )
}

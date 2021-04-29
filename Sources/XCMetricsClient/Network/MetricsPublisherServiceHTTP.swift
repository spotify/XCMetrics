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

enum UploadError: Error {
    case responseError(statusCode: Int)
}

struct LogUploadError: Error {
    let error: Error
    let body: Data?
}

/// An implementation for a publisher service that transports the build metrics via HTTP.
public class MetricsPublisherServiceHTTP: MetricsPublisherService {

    let dispatchGroup = DispatchGroup()
    let dispatchQueue = DispatchQueue(label: "com.spotify.xcmetricsapp.publisherservice", qos: .default, attributes: [.concurrent])

    func uploadMetrics(
        serviceURL: URL,
        projectName: String,
        isCI: Bool,
        skipNotes: Bool,
        uploadRequests: Set<MetricsUploadRequest>,
        completion: @escaping (_ successfulURLs: Set<URL>, _ failedURLs: [URL: Data]) -> Void
    ) {
        var successfulURLs = Set<URL>()
        var failedURLs = [URL: Data]()
        let successfulURLsLock = NSLock()
        let failedURLsLock = NSLock()
        for uploadRequest in uploadRequests {
            self.dispatchGroup.enter()

            self.uploadLog(uploadRequest, to: serviceURL, projectName: projectName, isCI: isCI, skipNotes: skipNotes) { (result: Result<Void, LogUploadError>) in
                switch result {
                case .success:
                    successfulURLsLock.lock()
                    successfulURLs.insert(uploadRequest.fileURL)
                    successfulURLsLock.unlock()
                case .failure(let error):
                    // If the failed request was for an already failed request, skip writing it to disk since it's
                    // already saved.
                    guard uploadRequest.fileURL.isRequestFile == false else {
                        return
                    }
                    log("Error (\(error.error)) in uploading metrics.")
                    failedURLsLock.lock()
                    failedURLs[uploadRequest.fileURL] = error.body
                    failedURLsLock.unlock()
                }
            }
        }
        dispatchGroup.wait()

        dispatchGroup.notify(queue: dispatchQueue) {
            log("Completed uploading metrics with \(successfulURLs.count) successful and \(failedURLs.count) failed uploads.")
            completion(successfulURLs, failedURLs)
        }
    }

    private func uploadLog(
        _ uploadRequest: MetricsUploadRequest,
        to requestUrl: URL,
        projectName: String,
        isCI: Bool,
        skipNotes: Bool,
        completion: @escaping (Result<Void, LogUploadError>) -> Void
    ) {
        /// We send the unencrypted machine name, the backend will decide if is going to store it encrypted or not
        /// based on its configuration
        let machineName = HashedMacOSMachineNameReader(encrypted: false).machineName ?? "none"
        do {
            let request = try MultipartRequestBuilder(request: uploadRequest,
                           url: requestUrl,
                           machineName: machineName,
                           projectName: projectName,
                           isCI: isCI,
                           skipNotes: skipNotes).build()

            getURLSession().dataTask(with: request) { (data, response, error) in
                defer {
                    self.dispatchGroup.leave()
                }

                if let error = error {
                    log("Failed to upload log with error: \(error)")
                    return completion(.failure(LogUploadError(error: error, body: request.httpBody)))
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 200 || httpResponse.statusCode > 299 {
                    log("Failed to upload log with status code: \(httpResponse.statusCode)")
                    return completion(
                        .failure(
                            LogUploadError(
                                error: UploadError.responseError(statusCode: httpResponse.statusCode),
                                body: request.httpBody
                            )
                        )
                    )
                }
                completion(.success(()))
            }.resume()
        } catch {
            completion(.failure(LogUploadError(error: error, body: nil)))
        }
    }

    private func getURLSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 120.0
        sessionConfig.timeoutIntervalForResource = 120.0
        return URLSession(configuration: sessionConfig)
    }

}

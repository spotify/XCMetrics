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
import Core
import Storage
import Vapor

/// `LogFileRepository` that stores and fetches logs from Google Cloud Storage
struct LogFileGCSRepository: LogFileRepository {

    let credentialsConfiguration: GoogleCloudCredentialsConfiguration
    let cloudStorageConfiguration: GoogleCloudStorageConfiguration    
    let bucketName: String
    let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let logger: Logger

    init(bucketName: String, credentialsConfiguration: GoogleCloudCredentialsConfiguration,
         cloudStorageConfiguration: GoogleCloudStorageConfiguration, logger: Logger) {
        self.bucketName = bucketName
        self.credentialsConfiguration = credentialsConfiguration
        self.cloudStorageConfiguration = cloudStorageConfiguration
        self.logger = logger
    }

    init?(config: Configuration, logger: Logger) {
        guard let gcProject = config.googleProject, let bucket = config.gcsBucket else {
            return nil
        }
        let credentialsConfiguration: GoogleCloudCredentialsConfiguration?
        if let credentials = config.googleCredentialsFile {
           credentialsConfiguration = try? GoogleCloudCredentialsConfiguration(projectId: gcProject,
                                                                               credentialsFile: credentials)
        } else {
            credentialsConfiguration = try? GoogleCloudCredentialsConfiguration(projectId: gcProject)
        }
        guard let credentialsConf = credentialsConfiguration else {
            return nil
        }
        self.init(bucketName: bucket,
                  credentialsConfiguration: credentialsConf,
                  cloudStorageConfiguration: GoogleCloudStorageConfiguration.default(),
                  logger: logger)
    }

    func put(logFile: File) throws -> URL {
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(group))
        defer {
            try? httpClient.syncShutdown()
        }
        let groupEventLoop = group.next()
        let gcs = try GoogleCloudStorageClient(credentials: credentialsConfiguration,
                                               storageConfig: cloudStorageConfiguration,
                                               httpClient: httpClient,
                                               eventLoop: groupEventLoop)
        let mediaLink = try gcs.object.createSimpleUpload(bucket: bucketName,
                                                          body: .byteBuffer(logFile.data.xcm_onlyFileData()),
                                                          name: logFile.filename,
                                      contentType: "application/octet-stream")
            .flatMap { uploadedObject -> EventLoopFuture<String> in
                if let mediaLink = uploadedObject.mediaLink {
                    return groupEventLoop.makeSucceededFuture(mediaLink)
                } else {
                    return groupEventLoop.future(error: RepositoryError.unexpected(message: "No link"))
                }
        }.wait()
        guard let fileURL = URL(string: mediaLink) else {
            throw RepositoryError.unexpected(message: "Malformed URL \(mediaLink)")
        }
        return fileURL
    }

    func get(logURL: URL) throws -> URL {
        logger.info("[LogFileGCSRepository] get \(logURL), bucket: \(bucketName), object: \(logURL.lastPathComponent)")
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(group))
        defer {
            try? httpClient.syncShutdown()
        }
        let groupEventLoop = group.next()
        let gcs = try GoogleCloudStorageClient(credentials: credentialsConfiguration,
                                               storageConfig: cloudStorageConfiguration,
                                               httpClient: httpClient,
                                               eventLoop: groupEventLoop)

        let localURL = try gcs.object.getMedia(bucket: bucketName, object: logURL.lastPathComponent).flatMap { gcsObject -> EventLoopFuture<URL> in
            guard let data = gcsObject.data else {
                self.logger.error("[LogFileGCSRepository] file not found")
                return groupEventLoop.makeFailedFuture(RepositoryError.unexpected(message: "File not found in GCS \(logURL.lastPathComponent)"))
            }
            do {
                self.logger.info("[LogFileGCSRepository] saving file")
                let tmp = try TemporaryFile(creatingTempDirectoryForFilename: "\(UUID().uuidString).xcactivitylog")
                try data.write(to: tmp.fileURL)
                self.logger.info("[LogFileGCSRepository] file saved to \(tmp.fileURL)")
                return groupEventLoop.makeSucceededFuture(tmp.fileURL)
            } catch {
                self.logger.error("[LogFileGCSRepository] error saving log locally \(error)")
                return groupEventLoop.makeFailedFuture(error)
            }
        }.wait()
        return localURL
    }

}

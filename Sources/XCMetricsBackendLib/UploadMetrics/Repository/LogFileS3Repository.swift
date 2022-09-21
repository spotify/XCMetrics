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
import S3

/// `LogFileRepository` that uses Amazon S3 to store and fetch logs
struct LogFileS3Repository: LogFileRepository {

    let bucketName: String

    let s3: S3

    init(accessKey: String, bucketName: String, regionName: String, secretAccessKey: String) {
        self.bucketName = bucketName
        guard let region = Region(rawValue: regionName) else {
            preconditionFailure("Invalid S3 Region \(regionName)")
        }
        self.s3 = S3(accessKeyId: accessKey, secretAccessKey: secretAccessKey, region: region)
    }

    init?(config: Configuration) {
        guard let bucketName = config.s3Bucket, let accessKey = config.awsAccessKeyId,
              let secretAccessKey = config.awsSecretAccessKey,
              let regionName = config.s3Region else {
            return nil
        }
        self.init(accessKey: accessKey, bucketName: bucketName,
                  regionName: regionName, secretAccessKey: secretAccessKey)
    }

    func put(logFile: File) throws -> URL {
        let data = Data(logFile.data.xcm_onlyFileData().readableBytesView)

        let putObjectRequest = S3.PutObjectRequest(acl: .private,
                                                   body: data,
                                                   bucket: bucketName,
                                                   contentLength: Int64(data.count),
                                                   key: logFile.filename)
        let fileURL = try s3.putObject(putObjectRequest)
            .map { _ -> URL? in
                return URL(string: "s3://\(bucketName)/\(logFile.filename)")
            }.wait()
        guard let url = fileURL else {
            throw RepositoryError.unexpected(message: "Invalid url of \(logFile.filename)")
        }
        return url
    }

    func get(logURL: URL) throws -> LogFile {
        guard let bucket = logURL.host else {
            throw RepositoryError.unexpected(message: "URL is not an S3 url \(logURL)")
        }
        let fileName = logURL.lastPathComponent
        let request = S3.GetObjectRequest(bucket: bucket, key: fileName)
        let fileData = try s3.getObject(request)
            .map { response -> Data? in                
                return response.body
            }.wait()
        guard let data = fileData else {
            throw RepositoryError.unexpected(message: "There was an error downloading file \(logURL)")
        }
        let tmp = try TemporaryFile(creatingTempDirectoryForFilename: "\(UUID().uuidString).xcactivitylog")
        try data.write(to: tmp.fileURL)
        return LogFile(remoteURL: logURL, localURL: tmp.fileURL)
    }

}

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
@testable import XCMetricsClient

class MockFileAccessor: FileAccessor {
    var expectedPath: String?
    var fileExists = false

    func entriesOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> [FileEntry] {
        return []
    }

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        return []
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if expectedPath == path {
            return fileExists
        }
        return false
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
    }
    func copyItem(at srcURL: URL, to dstURL: URL) throws {
    }
    func moveItem(at srcURL: URL, to dstURL: URL) throws {
    }
    func removeItem(at URL: URL) throws {
    }
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        return [:]
    }
    var fileContents: [String:String] = [:]
    var readFileError: Error?
    func readFileContent(atPath path: String) throws -> String {
        if let error = readFileError {
            throw error
        }
        return fileContents[path] ?? ""
    }
}

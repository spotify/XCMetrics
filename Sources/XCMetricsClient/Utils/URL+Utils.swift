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

extension URL {
    
    var modificationDate: Date? {
        return try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    var isRequestFile: Bool {
        return self.deletingLastPathComponent().path.hasSuffix(LogManagerImplementation.failedRequestsDirectoryName)
    }

    static func makeBuildLogsDirectory(for buildDirectory: String) -> URL {
        // When building for debug, BUILD_DIR looks like the following so we have to navigate the Build logs folder:
        // This: /Users/username/Library/Developer/Xcode/DerivedData/Spotify-dndppkxfrrjwnwheckoansdgklfh/Build/Products
        // Becomes: /Users/username/Library/Developer/Xcode/DerivedData/Spotify-dndppkxfrrjwnwheckoansdgklfh/Logs/Build
        return URL(fileURLWithPath: buildDirectory)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Logs")
            .appendingPathComponent("Build")
    }

    static func makeBuildLogsDirectoryWhenArchiving(for buildDirectory: String) -> URL {
        // When archiving, BUILD_DIR looks like the following so we have to navigate the Build logs folder:
        // This: /Users/username/repo-path/build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/Spotify/BuildProductsPath
        // Becomes: /Users/username/repo-path/build/DerivedData/Logs/Build
        return URL(fileURLWithPath: buildDirectory)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Logs")
            .appendingPathComponent("Build")
    }
}

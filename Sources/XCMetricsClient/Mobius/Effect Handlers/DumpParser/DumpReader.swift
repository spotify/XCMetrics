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

/// Single line file stream reader
private class LineStreamReader {
    private let encoding = String.Encoding.utf8
    private let chunkSize = 4096
    private let fileHandle: FileHandle
    private var buffer: Data
    private let delimiter = "\n".data(using: .utf8)!
    private var isEOF = false

    init(url: URL) throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        self.fileHandle = fileHandle
        buffer = Data(capacity: chunkSize)
    }

    deinit {
        fileHandle.closeFile()
    }

    func nextLine() -> Data? {
        if isEOF { return nil }

        repeat {
            if let range = buffer.range(of: delimiter, options: [], in: buffer.startIndex..<buffer.endIndex) {
                let bufferSliceData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.replaceSubrange(buffer.startIndex..<range.upperBound, with: [])
                return bufferSliceData
            } else {
                let tempData = fileHandle.readData(ofLength: chunkSize)
                if tempData.count == 0 {
                    isEOF = true
                    // left state of a buffer
                    return (buffer.count > 0) ? buffer : nil
                }
                buffer.append(tempData)
            }
        } while true
    }
}


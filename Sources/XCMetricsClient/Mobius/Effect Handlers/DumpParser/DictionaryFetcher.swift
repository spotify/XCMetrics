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

protocol Defaultable {
    static var defaultValue: Self {get}
}

extension Dictionary where Key == AnyHashable {
    /// Fetch type-matching value from a set of potential keys
    func fetch<T: Defaultable>(_ potentialKeys: String...) -> T {
        for potentialKey in potentialKeys {
            if let value = self[potentialKey], let typedValue = value as? T {
                return typedValue
            }
        }
        return T.defaultValue
    }
}

// MARK: - Defaultable conformances

extension String: Defaultable {
    static var defaultValue: String = ""
}
extension Bool: Defaultable {
    static var defaultValue: Bool = false
}
extension Double: Defaultable {
    static var defaultValue: Double = 0
}
extension Int: Defaultable {
    static var defaultValue: Int = 0
}
extension UInt64: Defaultable {
    static var defaultValue: UInt64 = 0
}
extension Int64: Defaultable {
    static var defaultValue: Int64 = 0
}
extension Int32: Defaultable {
    static var defaultValue: Int32 = 0
}
extension Float: Defaultable {
    static var defaultValue: Float = 0
}

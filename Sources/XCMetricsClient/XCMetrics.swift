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
import ArgumentParser
import XCLogParser
import MobiusCore
import MobiusExtras

/// A plugin executed by XCMetrics that collects custom metrics.
public struct XCMetricsPlugin: Equatable, Hashable {
    /// The body implementation of a plugin which takes a dictionary of the environment variable provided to it and
    /// should return a dictionary of key-value pairs to be attached to the build metadata of the build.
    public typealias PluginBody = ([String: String]) -> [String: String]
    let name: String
    let body: PluginBody

    /// Initializer for XCMetricsPlugin.
    /// - Parameters:
    ///   - name: A unique name for this plugin.
    ///   - body: The closure that contains the implementation of this plugin.
    public init(name: String, body: @escaping PluginBody) {
        self.name = name
        self.body = body
    }

    /// Equatable implementation for XCMetricsPlugin.
    public static func == (lhs: XCMetricsPlugin, rhs: XCMetricsPlugin) -> Bool {
        return lhs.name == rhs.name
    }
    /// Hashable implementation for XCMetricsPlugin.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// A XCMetrics configuration which describes the plugins to be executed.
public class XCMetricsConfiguration {
    private(set) var plugins = [XCMetricsPlugin]()

    /// Default initializer for `XCMetricsConfiguration`.
    public init() {
    }

    /// Adds a new plugin to the configuration.
    /// - Parameter plugin: The plugin to be added.
    public func add(plugin: XCMetricsPlugin) {
        plugins.append(plugin)
    }
}

struct Command {
    let buildDirectory: String
    let projectName: String
    let timeout: Int
    let serviceURL: String
    let isCI: Bool
    let skipNotes: Bool
    let additionalHeaders: [String: String]
}


/// The entry point for XCMetrics that parses all argument if executed standalone or by another package that depends on it.
public struct XCMetrics: ParsableCommand {

    /// The default configuration for the command.
    public static var configuration = CommandConfiguration(
        abstract: "Sends build metrics to the XCMetricsPublisher backend service."
    )

    /// The value of the Xcode $BUILD_DIR environment variable provided as argument. If not provided directly, XCMetrics will try to fetch it from the environment.
    @Option(name: [.customLong("buildDir"), .customShort("b")], help: "The value of the Xcode $BUILD_DIR environment variable.")
    public var buildDir: String?

    /// The name of the current project provided as argument.
    @Option(name: .shortAndLong, help: "The name of the current project.")
    public var name: String

    /// The timeout to wait for the Xcode's log to appear provided as argument. Default value is 5 seconds.
    @Option(name: .shortAndLong, help: "The timeout to wait for the Xcode's log to appear.")
    public var timeout: Int = 5

    /// The URL of the service where to send metrics to provided as argument. In debug builds, this argument can be ommitted and the default local
    /// URL will be used (http://localhost:8080/v1/metrics) in order to avoid uploading local data to the production service.
    @Option(name: [.customLong("serviceURL"), .customShort("s")], help: "The URL of the service where to send metrics to.")
    public var serviceURL: String?

    /// If the metrics collected are coming from CI or not provided as argument. Default value is false.
    @Option(name: [.customLong("isCI")], help: "If the metrics collected are coming from CI or not.")
    public var isCI: Bool = false

    /// If the Notes found in log should be skipped. Useful when there are thousands of notes to
    /// reduce the size of the Database.
    @Option(name: [.customLong("skipNotes")], help: "Notes found in logs won't be processed")
    public var skipNotes: Bool = false

    /// An optional authorization/token header **key** to be included in the upload request. Must be used in conjunction with `authorizationValue.`
    @Option(name: [.customLong("authorizationKey"), .customShort("k")], help: "An optional authorization header key to be included in the upload request e.g 'Authorization' or 'x-api-key' etc. Must be used in conjunction with `authorizationValue`")
    public var authorizationKey: String?

    /// An optional authorization/token header **value** to be included in the upload request. Must be used in conjunction with `authorizationKey.`
    @Option(name: [.customLong("authorizationValue"), .customShort("a")], help: "An optional authorization header value to be included in the upload request e.g 'Basic YWxhZGRpbjpvcGVuc2VzYW1l' or `hYDqG78OIUDIWKLdwjdwhdu8` etc. Must be used in conjunction with `authorizationKey`")
    public var authorizationValue: String?

    private static let loop = XCMetricsLoop()

    /// The default initializer for the `XCMetrics` object.
    public init() {}

    /// Runs XCMetrics with the provided configuration containing the optional custom plugins to be executed.
    /// - Parameter configuration: `XCMetricsConfiguration`
    public func run(with configuration: XCMetricsConfiguration) {
        do {
            let command = try fetchEnvironmentVariablesParameters()
            XCMetrics.loop.startLoop(with: command, plugins: configuration.plugins)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// Runs XCMetrics.
    /// - Throws: Throws an error in case of missing or invalid required arguments.
    public func run() throws {
        let command = try fetchEnvironmentVariablesParameters()
        XCMetrics.loop.startLoop(with: command)
    }

    func argumentError() -> ValidationError {
        return ValidationError("""
        A valid --name, --buildDir and --serviceURL are required.
        If a $BUILD_DIR environment variable is defined, you can omit --buildDir.
        The --timeout argument is optional and defaults to 5 seconds.
        The --isCI argument is optional and defaults to false.
        The --skipNotes argument is optional and defaults to false.
        The --authorizationKey must be used in conjunction with --authorizationValue. One cannot be used without the other.
        Type 'XCMetrics --help' for more information.
        """)
    }

    /// Some parameters can be omitted and should be parsed from the current environment.
    /// This method tries to fetch those values and treat them as if they were provided as normal parameters.
    /// - Throws: A ValidationError in case a required value can be fetched.
    /// - Returns: A Command object that encapsulates all required parameters.
    private func fetchEnvironmentVariablesParameters() throws -> Command {
        let processInfo = ProcessInfo()

        var directoryBuild = ""
        #if DEBUG
        // Use default local debugging URL if one is not provided in debug.
        let serviceURLValue = serviceURL ?? "http://localhost:8080/v1/metrics"
        #else
        guard let serviceURLValue = serviceURL else {
            throw argumentError()
        }
        #endif

        if let buildDirectoryValue = buildDir {
            directoryBuild = buildDirectoryValue
        } else if let buildDirectoryValue = processInfo.buildDir {
            directoryBuild = buildDirectoryValue
        } else {
            throw argumentError()
        }

        let authorization: (String, String)?
        
        switch (self.authorizationKey, self.authorizationValue) {
        case (let .some(authKey), let .some(authValue)):
            authorization = (authKey, authValue)
        case (.none, .none):
            authorization = nil
        default:
            throw argumentError()
        }

        let command = Command(
            buildDirectory: directoryBuild,
            projectName: name,
            timeout: timeout,
            serviceURL: serviceURLValue,
            isCI: isCI,
            skipNotes: skipNotes,
            additionalHeaders: authorization.map { (key, value) in
                [key: value]
            } ?? [:]
        )
        return command
    }
}

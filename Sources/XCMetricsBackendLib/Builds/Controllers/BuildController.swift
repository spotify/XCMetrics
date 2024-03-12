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

import Fluent
import FluentSQL
import Vapor

/// Controller with endpoints that return Builds related data
public struct BuildController: RouteCollection {

    /// Returns the routes supported by this Controller.
    /// All the routes are in the `v1/build` path
    /// - Parameter routes: RoutesBuilder to which the routes will be added
    /// - Throws: An `Error` if something goes wrong
    public func boot(routes: RoutesBuilder) throws {
        routes.get("v1", "build", "error", ":id", use: buildErrors)
        routes.get("v1", "build", "host", ":id", use: buildHost)
        routes.get("v1", "build", "warning", ":id", use: buildWarnings)
        routes.get("v1", "build", "metadata", ":id", use: metadata)
        routes.post("v1", "build", "filter", use: list)
        routes.get("v1", "build", "project", use: projects)
        routes.get("v1", "build", ":id", use: build)
        routes.get("v1", "build", use: index)
        routes.get("v1", "build", "step", ":day", ":id", use: targetSteps)
        routes.post("v1", "build", "metadata", "filter", use: metadataFilter)
    }

    /// Endpoint that returns the paginated list of `Build`
    /// sorted by date from the most recent to the least recent.
    /// - Method: `GET`
    /// - Route: `/v1/build?page=1&per=10`
    /// - Request parameters
    ///     - `page`. Optional. Page number to fetch. Default is `1`
    ///     - `per`. Optional. Number of items to fetch per page. Default is `10`
    /// - Response:
    ///
    /// ```
    /// {
    ///   "metadata": {
    ///       "per": 10,
    ///       "total": 100,
    ///       "page": 2
    ///     },
    ///    "items": [
    ///      {
    ///        "userid": "tim",
    ///        "warningCount": 3,
    ///        "duration": 1.10,
    ///        "isCi": false,
    ///        "startTimestamp": "2020-11-02T16:36:22Z",
    ///        "startTimestampMicroseconds": 1604334982.5824749,
    ///        "category": "noop",
    ///        "endTimestampMicroseconds": 1604334993.6019359,
    ///        "tag": "",
    ///        "compilationEndTimestamp": "2020-11-02T16:36:22Z",
    ///        "compilationDuration": 0,
    ///        "projectName": "MyProject",
    ///        "compilationEndTimestampMicroseconds": 1604334982.5824749,
    ///        "errorCount": 0,
    ///        "buildStatus": "succeeded",
    ///        "day": "2020-11-02T00:00:00Z",
    ///        "id": "MyMac_D682E30D-AF89-4712-A78E-85DC0AAB83C8_1",
    ///        "schema": "App",
    ///        "compiledCount": 0,
    ///        "endTimestamp": "2020-11-02T16:36:33Z",
    ///        "userid256": "c28b6fd9a49bd8c74767501a114784d327336f3ff861873341b5b64900125463",
    ///        "machineName": "MyMac",
    ///        "wasSuspended": false
    ///      },
    ///      ...
    ///      ]
    /// }
    /// ```
    ///
    public func index(req: Request) -> EventLoopFuture<Page<Build>> {
        return Build.query(on: req.db)
            .sort(\.$startTimestampMicroseconds, .descending)
            .paginate(for: req)
    }

    /// Endpoint that returns the paginated list of `Build`
    /// filtered by different criteria, like creation date, build status and project name
    /// - Method: `POST`
    /// - Route: `/v1/build/filter`
    /// - Request body
    ///
    /// ```
    /// {
    ///     "from": "2020-10-23T04:00:00Z",
    ///     "to": "2021-10-24T17:00:00Z",
    ///     "page": 1,
    ///     "per": 5,
    ///     "projectName": "MyProject",
    ///     "status": "failed"
    /// }
    ///  ```
    ///
    ///  - Body Parameters
    ///     - `from`. Lower limit creation date of the `Build`
    ///     - `to`. Upper limit creation date of the `Build`
    ///     - `projectName`. Optional. Name of the project that was built
    ///     - `status`. Optional. Status of the `Build`. Possible values: `succeeded`, `failed` or `stopped`
    ///     - `page`. Optional. Page number to fetch. Default is `1`
    ///     - `per`. Optional. Number of items to fetch per page. Default is `10`
    ///
    /// - Response:
    ///
    /// ```
    /// {
    ///   "metadata": {
    ///      "per": 5,
    ///       "total": 6,
    ///       "page": 1
    ///    },
    ///    "items": [
    ///      {
    ///        "userid": "tim",
    ///        "warningCount": 3,
    ///        "duration": 1.4963999999999999e-05,
    ///        "startTimestamp": "2020-11-02T16:38:40Z",
    ///        "isCi": false,
    ///        "startTimestampMicroseconds": 1604335120.279242,
    ///        "category": "incremental",
    ///        "endTimestampMicroseconds": 1604335135.242979,
    ///        "day": "2020-11-02T00:00:00Z",
    ///        "compilationEndTimestamp": "2020-11-02T16:38:55Z",
    ///        "compilationDuration": 1.4849e-05,
    ///        "projectName": "MyProject",
    ///        "compilationEndTimestampMicroseconds": 1604335135.128335,
    ///        "buildStatus": "failed",
    ///        "id": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///        "tag": "",
    ///        "errorCount": 1,
    ///        "schema": "MyProject",
    ///        "compiledCount": 86,
    ///        "endTimestamp": "2020-11-02T16:38:55Z",
    ///        "userid256": "c28b6fd9a49bd8c74767501a114784d327336f3ff861873341b5b64900125463",
    ///        "machineName": "MyMac",
    ///        "wasSuspended": false
    ///      },
    ///    ...
    ///    ]
    /// }
    /// ```
    ///
    public func list(req: Request) throws -> EventLoopFuture<Page<Build>> {
        let params = try req.content.decode(BuildListParams.self)
        let query = Build.query(on: req.db)
            .filter(\.$startTimestamp >= params.from)
            .filter(\.$startTimestamp <= params.to)
        if params.excludeCI {
            query.filter(\.$isCi == false)
        }
        if let status = params.status {
            query.filter(\.$buildStatus == status)
        }
        if let projectName = params.projectName {
            query.filter(\.$projectName == projectName)
        }
        return query.sort(\.$startTimestampMicroseconds, .descending)
            .paginate(PageRequest(page: params.page, per: params.per))
    }

    /// Endpoint that returns the most relevant information of a `Build`:
    /// `Build` data, Xcode used and list of `Target` that were built.
    /// - Method: `GET`
    /// - Route: `/v1/build/<buildId>`
    /// - Path parameters
    ///     - `buildId`. Mandatory. `Build`'s identifier
    ///
    /// - Response:
    ///
    /// ```
    /// {
    ///     "build": {
    ///       "userid": "tim",
    ///       "warningCount": 3,
    ///       "duration": 1.4,
    ///       "startTimestamp": "2020-11-02T16:38:40Z",
    ///       "isCi": false,
    ///       "startTimestampMicroseconds": 1604335120.279242,
    ///       "category": "incremental",
    ///       "endTimestampMicroseconds": 1604335135.242979,
    ///       "day": "2020-11-02T00:00:00Z",
    ///       "compilationEndTimestamp": "2020-11-02T16:38:55Z",
    ///       "compilationDuration": 1.48,
    ///       "projectName": "MyProject",
    ///       "compilationEndTimestampMicroseconds": 1604335135.128335,
    ///       "buildStatus": "failed",
    ///       "id": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///       "tag": "",
    ///       "errorCount": 1,
    ///       "schema": "App",
    ///       "compiledCount": 86,
    ///       "endTimestamp": "2020-11-02T16:38:55Z",
    ///       "userid256": "c28b6fd9a49bd8c74767501a114784d327336f3ff861873341b5b64900125463",
    ///       "machineName": "MyMac",
    ///       "wasSuspended": false
    ///     },
    ///     "xcode": {
    ///        "buildNumber": "12A7209",
    ///        "id": "6354C87F-0ADC-4354-929C-02EBE545E099",
    ///        "buildIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///        "day": "2020-11-02T00:00:00Z",
    ///        "version": "1200"
    ///     },
    ///     "targets": [
    ///        {
    ///          "id": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1992",
    ///          "category": "noop",
    ///          "startTimestamp": "2020-11-02T10:59:09Z",
    ///          "compilationEndTimestampMicroseconds": 1604314749.2909288,
    ///          "endTimestampMicroseconds": 1604314982.298002,
    ///          "endTimestamp": "2020-11-02T11:03:02Z",
    ///          "fetchedFromCache": true,
    ///          "errorCount": 0,
    ///          "day": "2020-11-02T00:00:00Z",
    ///          "warningCount": 0,
    ///          "compilationEndTimestamp": "2020-11-02T10:59:09Z",
    ///          "compilationDuration": 0,
    ///          "compiledCount": 0,
    ///          "duration": 0.000233007,
    ///          "buildIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///          "name": "Model",
    ///          "startTimestampMicroseconds": 1604314749.2909288
    ///        },
    ///      ...
    ///      ]
    ///   }
    /// ```
    ///
    public func build(req: Request) throws -> EventLoopFuture<BuildResponse> {
        guard let buildId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        return
            Build.query(on: req.db)
            .filter(\.$id == buildId)
            .first()
            .flatMapThrowing({ build -> Build in
                guard let build = build else {
                    throw Abort(.notFound)
                }
                return build
            })
            .flatMap({ build -> EventLoopFuture<([Target], Build)> in
                // Optimization to speed up queries if we're using tables sharded by day
                if let day = build.day, let sql = req.db as? SQLDatabase {
                    return sql.raw("""
                        SELECT * FROM \(raw: Target.schema)_\(raw: day.xcm_toPartitionedTableFormat())
                        WHERE build_identifier = \(literal: buildId)
                        ORDER BY start_timestamp_microseconds,
                        name
                        """)
                        .all(decoding: Target.self)
                        .and(value: build)
                } else {
                    return Target.query(on: req.db)
                           .filter(\.$buildIdentifier == buildId)
                           .sort(\.$startTimestampMicroseconds)
                           .sort(\.$name)
                           .all()
                        .and(value: build)
               }
            })
            .and(
                XcodeVersion.query(on: req.db)
                    .filter(\.$buildIdentifier == buildId)
                    .first()
            )
            .map({ (data, xcode: XcodeVersion?) -> (BuildResponse) in
                let (targets, build) = data
                return BuildResponse(build: build, targets: targets, xcode: xcode)
            })
    }

    /// Endpoint that returns the list of errors of the given `Build`
    /// - Method: `GET`
    /// - Route: `/v1/build/error/<buildId>`
    /// - Path parameters
    ///     - `buildId`. Mandatory. `Build`'s identifier
    ///
    /// - Response:
    ///
    /// ```
    /// [
    ///   {
    ///      "detail": "\/Users\/<redacted>\/myproject\/Sources\/MyClass.m:241:97:// /  error: instance method 'fetch' not found ; did you mean 'fetchIt'?\r
    ///      myclass:[self.myService fetch]\r                                                                                                ^~~~~~~~~~~~~~\r                                                                                                fetch\r
    ///      1 error generated.\r",
    ///      "characterRangeEnd": 13815,
    ///      "id": "3E6EF185-6AC1-4E95-87E8-E305F41916E9",
    ///      "endingColumn": 97,
    ///      "parentIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_8860",
    ///      "day": "2020-11-02T00:00:00Z",
    ///      "type": "clangError",
    ///      "title": "Instance method 'fetch' not found ; did you mean 'fetchIt'?",
    ///      "endingLine": 241,
    ///      "severity": 2,
    ///      "startingLine": 241,
    ///      "parentType": "step",
    ///      "buildIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///      "startingColumn": 97,
    ///      "characterRangeStart": 0,
    ///       "documentURL": "file:\/\/\/Users\/<redacted>\/myproject\/Sources\/MyClass.m"
    ///     }
    /// ]
    /// ```
    ///
    public func buildErrors(req: Request) throws -> EventLoopFuture<[BuildError]> {
        guard let buildId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        return BuildError.query(on: req.db)
                .filter(\.$buildIdentifier == buildId)
                .all()
    }

    /// Endpoint that returns the list of warnings of the given `Build`
    /// - Method: `GET`
    /// - Route: `/v1/build/warning/<buildId>`
    /// - Path parameters
    ///     - `buildId`. Mandatory. `Build`'s identifier
    ///
    /// - Response:
    ///
    /// ```
    /// [
    ///    {
    ///     "detail": null,
    ///     "characterRangeEnd": 9817,
    ///     "documentURL": "file:\/\/\/Users\/<redacted>\/myproject\/Sources\/MyViewController.m",
    ///     "endingColumn": 22,
    ///     "id": "5F2011AC-F87F-4EDC-BBC6-2BBA3D789EB3",
    ///     "parentIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1845",
    ///     "day": "2020-11-02T00:00:00Z",
    ///     "type": "deprecatedWarning",
    ///     "title": "'dimsBackgroundDuringPresentation' is deprecated: first deprecated in iOS 12.0",
    ///     "endingLine": 235,
    ///     "severity": 1,
    ///     "startingLine": 235,
    ///     "parentType": "step",
    ///     "clangFlag": "[-Wdeprecated-declarations]",
    ///     "startingColumn": 22,
    ///     "buildIdentifier": "MyMac_34580469-5792-40F3-BEFB-7C5925996F23_1",
    ///     "characterRangeStart": 0
    ///   }
    /// ]
    /// ```
    ///
    public func buildWarnings(req: Request) throws -> EventLoopFuture<[BuildWarning]> {
        guard let buildId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        return BuildWarning.query(on: req.db)
                .filter(\.$buildIdentifier == buildId)
                .all()
    }

    /// Endpoint that returns the data of the host used in the given `Build`
    /// - Method: `GET`
    /// - Route: `/v1/build/host/<buildId>`
    /// - Path parameters
    ///     - `buildId`. Mandatory. `Build`'s identifier
    ///
    /// - Response:
    ///
    /// ```
    /// {
    ///     "id": "9DD5508D-4AD9-4C1C-AB7C-45BC2183EC51",
    ///     "swapFreeMb": 1615.25,
    ///     "hostOsFamily": "Darwin",
    ///     "isVirtual": false,
    ///     "uptimeSeconds": 1602055187,
    ///     "hostModel": "MacBookPro14,2",
    ///     "hostOsVersion": "10.15.7",
    ///     "day": "2020-10-26T00:00:00Z",
    ///     "cpuCount": 4,
    ///     "swapTotalMb": 7168,
    ///     "hostOs": "Mac OS X",
    ///     "hostArchitecture": "x86_64",
    ///     "memoryTotalMb": 16384,
    ///     "timezone": "CET",
    ///     "cpuModel": "Intel(R) Core(TM) i7-7567U CPU @ 3.50GHz",
    ///     "buildIdentifier": "MyMac_1FE14870-EDF1-4E8C-B1AA-2C2DF484842B_1",
    ///     "memoryFreeMb": 24.5234375,
    ///     "cpuSpeedGhz": 3.5
    /// }
    /// ```
    ///
    public func buildHost(req: Request) throws -> EventLoopFuture<BuildHost> {
        guard let buildId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        return BuildHost.query(on: req.db)
            .filter(\.$buildIdentifier == buildId)
            .first()
            .flatMapThrowing { buildHost -> BuildHost in
                guard let buildHost = buildHost else {
                    throw Abort(.notFound)
                }
                return buildHost
            }
    }

    /// Endpoint that returns the metadata sent using XCMetrics plugins for the given `Build`.
    /// The metadata is returned as a JSON object where each data is a key-value pair of `String`s
    /// - Method: `GET`
    /// - Route: `/v1/build/metadata/<buildId>`
    /// - Path parameters
    ///     - `buildId`. Mandatory. `Build`'s identifier
    ///
    /// - Response:
    ///
    /// ```
    /// {
    ///     "metadata": {
    ///       "anotherKey": "42",
    ///       "thirdKey": "Third value",
    ///       "aKey": "value1"
    ///     },
    ///     "id": "C1CDF2CE-0CC2-49C3-B8A2-481E67020CB8",
    ///     "day": "2020-11-02T00:00:00Z",
    ///     "buildIdentifier": "MyMac_0B9294B4-7E5A-4D40-91AB-5953A5075785_1"
    /// }
    /// ```
    ///
    public func metadata(req: Request) throws -> EventLoopFuture<BuildMetadata> {
        guard let buildId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        return BuildMetadata.query(on: req.db)
            .filter(\.$buildIdentifier == buildId)
            .first()
            .flatMapThrowing { metadata -> BuildMetadata in
                guard let metadata = metadata else {
                    throw Abort(.notFound)
                }
                return metadata
            }
    }

    /// Endpoint that returns the list of projects from which there are `Build` on the database.
    /// Useful if you want the list to filter the build per project using the endpoint
    /// `/v1/build/list`
    /// - Method: `GET`
    /// - Route: `/v1/build/project`
    /// - Response:
    ///
    /// ```
    /// [
    ///     "Project1",
    ///     "MyProject"
    /// ]
    /// ```
    ///
    public func projects(req: Request) throws -> EventLoopFuture<[String]> {
        return Build.query(on: req.db)
                .unique()
                .sort(\.$projectName)
                .all(\.$projectName)
    }

    /// Endpoint that returns the list of `Step`s that were done to build a Target.
    ///
    /// - Method: `GET`
    /// - Route: `/v1/build/step/:day/:targetId` example:
    /// `/v1/build/step/20210129/ash22j3sdba1f0654c3f9e9a_6561690B-DFE4-4EE8-ABEE-99E4D3325E7B_15`
    /// - Path parameters
    ///     - `day`. Mandatory. `Target`'s day as String in UTC. example: `20210129`
    ///     - targetId. Mandatory. `Target`'s id.
    /// - Response:
    ///
    /// ```
    /// [
    ///     {
    ///       "id": "ash22j3sdba1f0654c3f9e9a_6561690B-DFE4-4EE8-ABEE-99E4D3325E7B_16",
    ///       "startTimestamp": "2021-01-29T08:11:41Z",
    ///       "endTimestamp": "2021-01-29T08:11:41Z",
    ///       "errorCount": 0,
    ///       "endTimestampMicroseconds": 1611907901.256928,
    ///       "fetchedFromCache": false,
    ///       "targetIdentifier": "ecba60d222f04c51dba1f0654c3f9e9a_6561690B-DFE8-4EE8-ABEE-99E4D3325E7B_15",
    ///       "day": "2021-01-29T00:00:00Z",
    ///       "type": "other",
    ///       "title": "Create directory SPTAuthAccountsTests.xctest",
    ///       "warningCount": 0,
    ///        "signature": "MkDir \/Users\/<redacted>\/my_project\/build\/DerivedData\/Build\/Products\/Debug-iphonesimulator\/MyProjectTests.xctest",
    ///        "architecture": "",
    ///        "duration": 2.3,
    ///        "documentURL": "",
    ///        "buildIdentifier": "ash22j3sdba1f0654c3f9e9a_6561690B-DFE4-4EE8-ABEE-99E4D3325E7B_1",
    ///        "startTimestampMicroseconds": 1611907901.255825
    ///      },
    ///      ...
    /// ]
    /// ```
    ///
    public func targetSteps(req: Request) throws -> EventLoopFuture<[Step]> {
        guard let day = req.parameters.get("day"),
              let targetId = req.parameters.get("id"),
              Date.xcm_fromPartitionDay(day) != nil else {
            throw Abort(.badRequest)
        }
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.internalServerError)
        }

        return sql.raw("""
                SELECT * FROM \(raw: Step.schema)_\(raw: day)
                WHERE target_identifier = \(literal: targetId)
                ORDER BY start_timestamp_microseconds, title
            """)
            .all(decoding: Step.self)
    }

    /// Endpoint that returns the list of `BuildMetadata`s that were added to a build
    /// filtered by a given key-value pair.
    /// - Method: `POST`
    /// - Route: `/v1/build/metadata/filter`
    /// - Request body
    ///
    /// ```
    /// {
    ///     "key": "aKey",
    ///     "value": "value1"
    /// }
    ///  ```
    ///
    ///  - Body Parameters
    ///     - `key`. `BuildMetadata` metadata dictionary key
    ///     - `value`. `BuildMetadata` metadata dictionary value
    ///
    /// - Response:
    ///
    /// ```
    /// [
    ///     {
    ///       "metadata": {
    ///         "anotherKey": "42",
    ///         "thirdKey": "Third value",
    ///         "aKey": "value1"
    ///       },
    ///       "id": "C1CDF2CE-0CC2-49C3-B8A2-481E67020CB8",
    ///       "day": "2020-11-02T00:00:00Z",
    ///       "buildIdentifier": "MyMac_0B9294B4-7E5A-4D40-91AB-5953A5075785_1"
    ///     },
    ///     ...
    /// ]
    /// ```
    ///
    public func metadataFilter(req: Request) throws -> EventLoopFuture<[BuildMetadata]> {
        let params = try req.content.decode(BuildMetadataFilterParams.self)
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.internalServerError)
        }
                
        return sql.raw("""
                SELECT * FROM \(raw: BuildMetadata.schema)
                WHERE metadata ->> '\(raw: params.key)' = '\(raw: params.value)'
            """)
        .all(decoding: BuildMetadata.self)
    }

}

public struct BuildResponse: Content {
    let build: Build    
    let targets: [Target]
    let xcode: XcodeVersion?

    init(build: Build, targets: [Target], xcode: XcodeVersion?) {
        self.build = build
        self.targets = targets
        self.xcode = xcode
    }
}

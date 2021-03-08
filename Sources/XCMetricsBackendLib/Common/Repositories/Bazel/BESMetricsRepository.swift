//
// Created by Zachary Gray on 2/25/21.
//

import Fluent
import Foundation
import PublishBuildEventProto
import GRPC
import NIO
import NIOHPACK
import SwiftProtobuf

typealias BESClient = Google_Devtools_Build_V1_PublishBuildEventServiceClient
typealias StreamResponse = Google_Devtools_Build_V1_PublishBuildToolEventStreamResponse
typealias StreamCall = BidirectionalStreamingCall<Google_Devtools_Build_V1_PublishBuildToolEventStreamRequest, Google_Devtools_Build_V1_PublishBuildToolEventStreamResponse>
typealias StreamReq = Google_Devtools_Build_V1_PublishBuildToolEventStreamRequest

let toolName = "xcode"

struct BESMetricsRepository : MetricsRepository {
    let logger: Logger
    let besConfig: BESConfiguration
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 4)

    init(logger: Logger, besConfig: BESConfiguration) {
        self.logger = logger
        self.besConfig = besConfig
    }

    /**
     Initializes a gRPC BES client
     - Parameter group:
     - Returns: the configured BESClient (Google_Devtools_Build_V1_PublishBuildEventServiceClient)
     */
    private func initClient(group: EventLoopGroup) -> BESClient? {
        let target: URLComponents
        if besConfig.target == nil {
            return .none
        } else {
            target = besConfig.target!
        }
        do {
            let secure: Bool = target.scheme != nil && target.scheme!.contains("grpcs")
            let ccc = ClientConnection.Configuration(
                    target: .hostAndPort(target.host!, target.port!),
                    eventLoopGroup: group,
                    tls:  secure ? ClientConnection.Configuration.TLS() : nil)
            let cc = ClientConnection(configuration: ccc)
            let hdrs = [
                ("x-flare-buildtool", toolName),
                // additional headers here
            ] + (besConfig.authToken != nil ? [("x-api-key", besConfig.authToken!)] : [])
            let co = CallOptions(customMetadata: HPACKHeaders(hdrs), timeout: try .seconds(5))
            return .some(BESClient(connection: cc, defaultCallOptions: co))
        } catch {
            logger.error("Error creating server connection: \(error)")
        }
        return .none
    }

    func insertBuildMetrics(_ buildMetrics: BuildMetrics, using eventLoop: EventLoop) -> EventLoopFuture<Void> {
        if let rawClient = initClient(group: group) {
            let requests = createRequestsFor(build: buildMetrics)
            requests.forEach { req in logger.debug("BES req: \(req)") }
            let wrappedClient = WrappedClient(client: rawClient, eventLoop: eventLoop, requests: requests, logger: logger)
            let stream = wrappedClient.publishEventStream()
            return stream.sendMessages(requests)
                .flatMap { _ in stream.sendEnd() }
                .flatMap { _ in wrappedClient.done }
                .flatMap { _ in rawClient.connection.close() }
                .flatMapError { e in
                    logger.error("error: \(e.localizedDescription)")
                    return eventLoop.makeFailedFuture(e)
                }
        } else {
            logger.error("no grpc connection!")
            return eventLoop.makeFailedFuture(NSError(domain: "no_grpc_conn", code: 1))
        }
    }

    // MARK: request helpers

    private func createRequestsFor(build: BuildMetrics) -> Array<StreamReq> {
        // use a simple UUID for the buildID field, but align `invocationId` with
        // the visible `build.id` from xcmetrics for correlation
        let invocationId = build.build.id?.components(separatedBy: "_")[1] ?? UUID().uuidString
        let factory = BuildEventRequestFactory(
                buildId: UUID().uuidString,
                invocationId: invocationId,
                logger: logger)
        // massage the data a bit before constructing requests
        let startMillis = Int64(build.build.startTimestampMicroseconds * 1000)
        let finishMillis = Int64(build.build.endTimestampMicroseconds * 1000)
        var logEntries: [LogEntry] = build.errors ?? []
        logEntries += build.warnings ?? []
        logEntries += build.notes ?? []
        logEntries += build.swiftFunctions ?? []
        logEntries.sort { $0.startingLine < $1.startingLine }
        var sorted = build.steps
        sorted.sort { $0.endTimestampMicroseconds < $1.endTimestampMicroseconds }
        logEntries += sorted
        // the build event request sequence:
        return [
            // started event
            [factory.makeBazelEventRequest { ev, req in
                req.projectID = besConfig.projectId ?? build.build.projectName
                req.notificationKeywords = besConfig.keywords
                // populate the started event; set `id` and `payload`
                ev.id = make {
                    $0.started = make { startedId in }
                }
                ev.payload = .started(make {
                    $0.uuid = invocationId
                    $0.startTimeMillis = startMillis
                    $0.workingDirectory = build.build.projectName
                    $0.workspaceDirectory = build.build.projectName
                    $0.buildToolVersion = "xc_\(build.xcodeVersion?.version ?? "0")"
                    $0.command = "build"
                })
                // populate children Ids of the started event, declaring subsequent events
                ev.children = [make {
                    $0.pattern = make {
                        // map project name as the user-specified 'pattern' since we're building everything
                        $0.pattern = [build.build.projectName]
                    }
                }]
            }],
            // workspace_status
            [factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.workspaceStatus = make { _ in }
                }
                ev.payload = .workspaceStatus(make { ws in
                    ws.item = [
                        make { $0.key="BUILD_USER"; $0.value=build.build.userid},
                        make { $0.key="BUILD_HOST"; $0.value=build.build.machineName},
                        make { $0.key="BUILD_TIMESTAMP"; $0.value=String(NSDate().timeIntervalSince1970)},
                    ]
                })
            }],
            // unstructured_command_line (skipped)
            // structured_command_line (skipped)
            // configuration
            [factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.configuration = make { _ in }
                }
                ev.payload = .configuration(make { c in
                    c.cpu = build.host.cpuModel
                    c.platformName = build.host.hostOsFamily
                })
            }],
            // targetConfigured
            build.targets.map { target in
                factory.makeBazelEventRequest { ev, req in
                    ev.id = make {
                        $0.targetConfigured = make { c in
                            c.label = "\(target.name)"
                        }
                    }
                    ev.payload  = .configured(make {
                        $0.targetKind = "xc_\(target.category)"
                    })
                }
            },
            // progress (console output)
            logEntries.map { entry in
                factory.makeBazelEventRequest { ev, req in
                    ev.id = make {
                        $0.progress = make { _ in }
                    }
                    ev.payload = .progress(make { p in
                        var s = "\(entry.title + (entry.detail != nil ? "\r" + entry.detail! : ""))"
                                .replacingOccurrences(of: "\r", with: "\r\n")
                        if !s.hasSuffix("\r\n") {
                            s.append("\r\n")
                        }
                        p.stderr = s
                    })
                }
            },
            // named_set_of_files
            [factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.namedSet = make {
                        $0.id = "0"
                    }
                }
                ev.payload = .namedSetOfFiles(make { n in
                    n.files = getOutputFiles(fromLogEntries: sorted).map { fileName in make { bazelFile in bazelFile.name = fileName }}
                })
            }],
            // targetCompleted
            makeTargetCompletedEvents(for: build, using: factory),
            // buildMetrics
            [factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.buildMetrics = make { _ in }
                }
                ev.payload = .buildMetrics(make { metrics in
                    metrics.actionSummary = make {
                        let s = Int64(build.steps.count)
                        $0.actionsCreated = s
                        $0.actionsExecuted = s
                    }
                    metrics.targetMetrics = make {
                        let t = Int64(build.targets.count)
                        $0.targetsConfigured = t
                        $0.targetsLoaded = t
                    }
                    metrics.timingMetrics = make {
                        $0.wallTimeInMs = startMillis - finishMillis
                    }
                })
            }],
            // buildToolLogs (skipped)
            // build stream finished event (end of bazel stream)
            [factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.buildFinished = BuildEventStream_BuildEventId.BuildFinishedId()
                }
                ev.payload = .finished(make { fin in
                    fin.finishTimeMillis = finishMillis
                    fin.exitCode = make {
                        if build.errors == nil || build.errors!.isEmpty {
                            fin.overallSuccess = true
                            $0.name = "SUCCESS"
                            $0.code = 0
                        } else {
                            fin.overallSuccess = false
                            $0.name = "FAILED"
                            $0.code = 1
                        }
                    }
                })
                ev.lastMessage = true
            }],
            // component stream finished event
            [factory.makeEventRequest { req in
                req.orderedBuildEvent.event.componentStreamFinished = make { finished in }
            }]
        ].flatMap { $0 }
    }

    /**
     Converts steps into filename strings by parsing the `title` for filenames
     - Parameter entries: the steps to process
     - Returns: the set of unique files created by the build
     */
    private func getOutputFiles(fromLogEntries entries: [Step]) -> Set<String> {
        Set(entries.compactMap { (s: Step) -> String? in
            let range = s.title.range(of: #"(\s)(?!.*\s)[^\/]*\.[a-zA-Z]+"#, options: .regularExpression)
            if range == nil { return .none }
            return .some(s.title[range!].trimmingCharacters(in: .whitespacesAndNewlines))
        })
    }

    /**
     Helper function which allows creation of TargetCompleted events from build targets; necessary because
      on the final event, we want to attach an output group referencing the named set of files containing the outputs.
     - Parameters:
       - build: the buildmetrics for which to create reqs
       - factory: the req factory to be used
     - Returns: an array of requests
     */
    private func makeTargetCompletedEvents(for build: BuildMetrics, using factory: BuildEventRequestFactory) -> [StreamReq] {
        var targetIndex = -1
        return build.targets.map { (target: Target) -> StreamReq in
            targetIndex += 1
            return factory.makeBazelEventRequest { ev, req in
                ev.id = make {
                    $0.targetCompleted = make { c in
                        c.label = "\(target.name)"
                    }
                }
                ev.payload = .completed(make {
                    if targetIndex == build.targets.count - 1 {
                        $0.outputGroup = [make {
                            $0.name = "default"
                            $0.fileSets = [make { $0.id = "0" }]
                        }]
                    }
                    $0.success = target.errorCount == 0
                    $0.targetKind = "xc_\(target.category)"
                })
            }
        }
    }
}

private class BuildEventRequestFactory {
    var currentSequenceNumber: Int64 = 0
    let buildId: String
    let invocationId: String
    let logger: Logger

    init(buildId: String, invocationId: String, logger: Logger) {
        self.buildId = buildId
        self.invocationId = invocationId
        self.logger = logger
    }

    /**
     Boilerplate for metadata and stream state which all events should contain
     - Parameter f: the request instantiation closure
     - Returns: a stream request
     */
    func makeEventRequest(f:(inout StreamReq) -> Void) -> StreamReq {
        currentSequenceNumber += 1
        var r: StreamReq = make { req in
            req.orderedBuildEvent = make {
                $0.streamID = make {
                    $0.buildID = buildId
                    $0.invocationID = invocationId
                }
                $0.sequenceNumber = currentSequenceNumber
            }
        }
        f(&r)
        return r
    }

    /**
     Boilerplate for the actual bazel events
     - Parameter f:
     - Returns:
     */
    func makeBazelEventRequest(f:(inout BuildEventStream_BuildEvent, inout StreamReq) -> Void) -> StreamReq {
        var bazelEvent = BuildEventStream_BuildEvent()
        var request: StreamReq = makeEventRequest { req in }
        f(&bazelEvent, &request)
        request.orderedBuildEvent.event = make {
            do {
                $0.bazelEvent = try SwiftProtobuf.Google_Protobuf_Any(message: bazelEvent)
            }
            catch {
                logger.error("failed to cast bazel event to any: \(error)")
            }
        }
        return request
    }
}

/**
 proto initialization DSL
 - Parameter f: initializer function
 - Returns: the proto message with your changes applied
 */
func make<T: Message> (f: (inout T) -> Void) -> T { var t = T.init(); f(&t); return t }

/**
 * Wrapper around the gRPC client which coordinates waiting for server acks while leaving most of the rest of the
 * gRPC client interface intact
 */
private class WrappedClient {
    private let _done: EventLoopPromise<Void>
    private var queue: BuildEventResponseQueue
    private let client: BESClient
    private let logger: Logger

    var done: EventLoopFuture<Void> {
        get { _done.futureResult }
    }

    init(client: BESClient, eventLoop: EventLoop, requests: Array<StreamReq>, logger: Logger) {
        self.client = client
        self.logger = logger

        // initialize internal queue which drives the `done` future used to signal that all acks have been received
        _done = eventLoop.makePromise()
        queue = BuildEventResponseQueue()
        queue.onEmpty = { [weak self] () -> Void in
            self?._done.completeWith(eventLoop.future())
        }
        requests.forEach { queue.enqueue(el: $0.orderedBuildEvent.sequenceNumber) }
    }

    /**
     A wrapper over the gRPC client's publishBuildToolEventStream method which dequeues expected acks
      from the internal queue
     - Returns: A BidirectionalStreamingCall
     */
    func publishEventStream() -> StreamCall {
        client.publishBuildToolEventStream(handler: { ack in
            if let expected = self.queue.dequeue() {
                self.logger.debug("BES Server ack: \(ack)")
                assert(expected == ack.sequenceNumber)
            } else {
                self.logger.warning("warn: bad ack")
            }
        })
    }

    /**
     * A simple queue of expected sequence numbers which invokes the supplied isEmpty closure when drained
     */
    private struct BuildEventResponseQueue {
        var onEmpty: (() -> Void)? = nil
        var items: [Int64] = []
        mutating func enqueue(el: Int64) {
            items.append(el)
        }
        mutating func dequeue() -> Int64? {
            if items.isEmpty {
                return nil
            }
            let tmp = items.first
            items.remove(at: 0)
            if items.isEmpty { onEmpty?() }
            return tmp
        }
    }
}

// quick hack to aggregate and sort items to reconstruct a "log" for output
protocol LogEntry {
    var startingLine: Int32 { get }
    var title: String { get }
    var detail: String? { get }
}
extension BuildError : LogEntry {}
extension Step : LogEntry {
    var startingLine: Int32 { 0 }
    var detail: String? { nil }
}
extension BuildNote : LogEntry {}
extension BuildWarning : LogEntry {}
extension SwiftFunction : LogEntry {
    var title: String { signature }
    var detail: String? { String(duration) }
}
//extension SwiftTypeChecks : LogEntry {
//    var title: String { ??? }
//    var detail: String? { nil }
//}
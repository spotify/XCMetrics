import Foundation
import Queues

final class HealthCheckJob: Job {

    typealias Payload = String

    func dequeue(_ context: QueueContext, _ payload: String) -> EventLoopFuture<Void> {
        let eventLoop = context.application.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: Void.self)
        return promise.futureResult
    }

}

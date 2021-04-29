import Foundation
import Vapor

struct MetricsProcessor {

    static func process(metricsRequest: UploadMetricsRequest,
                 logURL: URL,
                 redactUserData: Bool) throws -> BuildMetrics {
        let machineName = redactUserData ? metricsRequest.extraInfo.machineName.md5() : metricsRequest.extraInfo.machineName
        let userId = redactUserData ? metricsRequest.extraInfo.user.md5() : metricsRequest.extraInfo.user
        let userIdSHA256 = metricsRequest.extraInfo.user.sha256()
        let isCI = metricsRequest.extraInfo.isCI
        return try LogParser.parseFromURL(
            logURL,
            machineName: machineName,
            projectName: metricsRequest.extraInfo.projectName,
            userId: userId,
            userIdSHA256: userIdSHA256,
            isCI: isCI,
            sleepTime: metricsRequest.extraInfo.sleepTime,
            skipNotes: metricsRequest.extraInfo.skipNotes
        )
    }

}

import Foundation
import Vapor

struct MetricsProcessor {

    static func process(metricsRequest: UploadMetricsRequest,
                 logFile: LogFile,
                 redactUserData: Bool) throws -> BuildMetrics {
        let machineName = redactUserData ? metricsRequest.extraInfo.machineName.md5() : metricsRequest.extraInfo.machineName
        let userId = redactUserData ? metricsRequest.extraInfo.user.md5() : metricsRequest.extraInfo.user
        let userIdSHA256 = metricsRequest.extraInfo.user.sha256()
        let isCI = metricsRequest.extraInfo.isCI
        return try LogParser.parseFromURL(
            logFile.localURL,
            metricsRequest: metricsRequest,
            machineName: machineName,
            userId: userId,
            userIdSHA256: userIdSHA256,
            isCI: isCI
        )
    }

}

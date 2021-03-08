//
// Created by Zachary Gray on 2/25/21.
//

import Foundation

struct BESConfiguration {
    let target: URLComponents?
    let authToken: String?
    let projectId: String?
    let keywords: [String]

    init(from config: Configuration) {
        target = URLComponents(string: config.besTarget ?? "")
        authToken = config.besAuthToken
        projectId = config.besProjectId
        keywords = config.besKeywords?.components(separatedBy: ",") ?? []
    }
}

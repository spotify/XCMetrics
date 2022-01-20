import Foundation
import ArgumentParser

final class AdditionalHeaderFactory {
    static func make(authorizationKey: String?,
                     authorizationValue: String?,
                     additionalHeader: [String: String]) throws -> [String: String] {
        switch (authorizationKey, authorizationValue) {
        case let (.some(key), .some(value)):
            var additionalHeader = additionalHeader
            additionalHeader[key] = value
            return additionalHeader
        case (.none, .none):
            return additionalHeader
        case (.none, .some), (.some, .none):
            throw ValidationError("The --authorizationKey must be used in conjunction with --authorizationValue. One cannot be used without the other.")
        }
    }
}

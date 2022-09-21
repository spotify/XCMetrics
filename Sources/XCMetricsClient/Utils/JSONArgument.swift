import Foundation
import ArgumentParser

final class JSONArgument {
    static func transformer(_ value: String) throws -> [String: String] {
        guard let data = value.data(using: .utf8) else { throw ValidationError("Badly encoded string, should be UTF-8") }
        let serializedData = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arguments = serializedData as? [String: Any] else {
            throw ValidationError("Invalid json")
        }
        let mappedArguments = arguments.mapValues(String.init(describing:))
        return mappedArguments
    }
}

import Foundation

public struct HTMLResource: Equatable, Sendable {
    public let identifier: String
    public let contentType: String
    public let data: Data

    public init(identifier: String, contentType: String, data: Data) {
        self.identifier = identifier
        self.contentType = contentType
        self.data = data
    }

    public var url: URL {
        URL(string: "marklens-resource://resource")!.appending(path: identifier)
    }

    public var contentIdentifier: String {
        let encoded = Data(identifier.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "marklens-\(encoded)"
    }
}

import Foundation

public struct HTMLResource: Equatable, Sendable {
    public let identifier: String
    public let contentType: String
    public let data: Data
    public let revision: String

    public init(identifier: String, contentType: String, data: Data) {
        self.identifier = identifier
        self.contentType = contentType
        self.data = data
        self.revision = Self.revision(for: data)
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

    private static func revision(for data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

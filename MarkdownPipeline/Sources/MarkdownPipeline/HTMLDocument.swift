import Foundation

public struct HTMLDocument {
    public let html: String
    public let title: String?
    public let baseURL: URL?

    public init(html: String, title: String?, baseURL: URL?) {
        self.html = html
        self.title = title
        self.baseURL = baseURL
    }

    @discardableResult
    public func write(to url: URL) throws -> URL {
        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func writeToTemporaryFile() throws -> URL {
        let fileName = "markdown-preview-\(UUID().uuidString).html"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        return try write(to: url)
    }
}

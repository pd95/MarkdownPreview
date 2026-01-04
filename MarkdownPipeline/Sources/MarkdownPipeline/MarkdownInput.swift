import Foundation

public enum MarkdownInput {
    case string(String)
    case data(Data, encoding: String.Encoding = .utf8)
    case file(URL, encoding: String.Encoding = .utf8)

    func resolvedString() throws -> String {
        switch self {
        case let .string(value):
            return value
        case let .data(data, encoding):
            guard let value = String(data: data, encoding: encoding) else {
                throw MarkdownPipelineError.invalidStringEncoding
            }
            return value
        case let .file(url, encoding):
            let data = try Data(contentsOf: url)
            guard let value = String(data: data, encoding: encoding) else {
                throw MarkdownPipelineError.invalidStringEncoding
            }
            return value
        }
    }
}

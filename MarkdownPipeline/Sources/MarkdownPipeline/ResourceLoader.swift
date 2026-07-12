import Foundation

enum ResourceLoader {
    static func stringResource(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw MarkdownPipelineError.missingResource(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func dataResource(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw MarkdownPipelineError.missingResource(name)
        }
        return try Data(contentsOf: url)
    }
}

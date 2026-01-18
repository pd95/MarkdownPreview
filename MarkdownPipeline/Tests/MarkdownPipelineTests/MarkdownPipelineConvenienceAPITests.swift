import Foundation
import Testing
@testable import MarkdownPipeline

@Suite("Convenience API")
struct MarkdownPipelineConvenienceAPITests {
    @Test func renderHTMLFromInputProducesHTML() throws {
        let pipeline = MarkdownPipeline.defaultHTML()
        let document = try pipeline.renderHTML(from: .string("# Title"))
        #expect(document.html.contains("<h1 id=\"title\">Title</h1>"))
    }

    @Test func writeToTemporaryFilePersistsHTML() throws {
        let pipeline = MarkdownPipeline.defaultHTML()
        let document = try pipeline.renderHTML(from: .string("# Title"))
        let url = try document.writeToTemporaryFile()
        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("<h1 id=\"title\">Title</h1>"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}

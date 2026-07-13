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

    @Test func composesAHighlightingOnlyPipeline() throws {
        let pipeline = MarkdownPipeline(plugins: [.syntaxHighlighting()])
        let document = try pipeline.renderHTML(from: .string("""
        See [[overview]] and $x$.

        ```mermaid
        graph TD
            A --> B
        ```
        """))

        #expect(document.containsWikiLinks == false)
        #expect(document.resources.isEmpty)
        #expect(document.html.contains("[[overview]]"))
        #expect(document.html.contains("$x$"))
        #expect(document.html.contains("<div class=\"mermaid-block\" data-mermaid-diagram>") == false)
        #expect(document.html.contains(".mermaid-block {") == false)
        #expect(document.html.contains(".katex") == false)
        #expect(document.html.contains("<pre><code"))
    }

    @Test func composesAnEmptyCorePipeline() throws {
        let pipeline = MarkdownPipeline(plugins: [])
        let document = try pipeline.renderHTML(from: .string("See [[overview]] and $x$."))

        #expect(document.containsWikiLinks == false)
        #expect(document.resources.isEmpty)
        #expect(document.html.contains("[[overview]]"))
        #expect(document.html.contains("$x$"))
    }

    @Test func composesAWikiLinkOnlyPipeline() throws {
        let pipeline = MarkdownPipeline(plugins: [.wikiLinks()])
        let document = try pipeline.renderHTML(from: .string("See [[overview]] and $x$."))

        #expect(document.containsWikiLinks)
        #expect(document.resources.isEmpty)
        #expect(document.html.contains("marklens-wikilink://open?target=overview"))
        #expect(document.html.contains("$x$"))
    }

    @Test func pluginOrderDoesNotChangeRenderingOrder() throws {
        let input = "See [[overview]] and $x$."
        let canonical = MarkdownPipeline(
            plugins: [.math(), .wikiLinks(), .mermaid(), .syntaxHighlighting()]
        )
        let reversed = MarkdownPipeline(
            plugins: [.syntaxHighlighting(), .mermaid(), .wikiLinks(), .math()]
        )

        let canonicalDocument = try canonical.renderHTML(from: .string(input))
        let reversedDocument = try reversed.renderHTML(from: .string(input))

        #expect(canonicalDocument.html == reversedDocument.html)
        #expect(canonicalDocument.containsWikiLinks == reversedDocument.containsWikiLinks)
    }

    @Test func latestDuplicatePluginConfigurationWins() throws {
        let pipeline = MarkdownPipeline(plugins: [
            .mermaid(rendering: .rendered),
            .mermaid(rendering: .sourceWithAppHint),
        ])
        let document = try pipeline.renderHTML(from: .string("""
        ```mermaid
        graph TD
            A --> B
        ```
        """))

        #expect(document.html.contains("Quick Look source"))
        #expect(document.html.contains("<div class=\"mermaid-block\" data-mermaid-diagram>") == false)
        #expect(document.html.contains(".mermaid-block {"))
        #expect(document.resources.isEmpty)
    }

    @Test func mermaidSourceFallbackWinsAcrossConfigurationSurfaces() throws {
        let input = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        let pluginFallback = MarkdownPipeline(
            plugins: [.mermaid(rendering: .sourceWithAppHint)]
        )
        let contextFallback = MarkdownPipeline(
            plugins: [.mermaid(rendering: .rendered)]
        )

        let pluginDocument = try pluginFallback.renderHTML(
            from: .string(input),
            context: PipelineContext(mermaidRendering: .rendered)
        )
        let contextDocument = try contextFallback.renderHTML(
            from: .string(input),
            context: PipelineContext(mermaidRendering: .sourceWithAppHint)
        )

        #expect(pluginDocument.html.contains("Quick Look source"))
        #expect(contextDocument.html.contains("Quick Look source"))
        #expect(pluginDocument.resources.isEmpty)
        #expect(contextDocument.resources.isEmpty)
    }

    @Test func resourceRevisionsAreStableAndContentSensitive() {
        let first = HTMLResource(identifier: "asset", contentType: "text/plain", data: Data([1, 2]))
        let same = HTMLResource(identifier: "asset", contentType: "text/plain", data: Data([1, 2]))
        let changed = HTMLResource(identifier: "asset", contentType: "text/plain", data: Data([1, 3]))

        #expect(first.revision == same.revision)
        #expect(first.revision != changed.revision)
    }

    #if canImport(JavaScriptCore)
    @Test func sharedPipelineSupportsConcurrentJavaScriptRendering() async throws {
        let pipeline = MarkdownPipeline(plugins: [.syntaxHighlighting(), .math()])

        try await withThrowingTaskGroup(of: Bool.self) { group in
            for index in 0..<16 {
                group.addTask {
                    let document = try pipeline.renderHTML(from: .string("""
                    Formula $x_\(index)$.

                    ```swift
                    let value = \(index)
                    ```
                    """))
                    return document.html.contains("class=\"math math-inline\"")
                        && document.html.contains("class=\"hljs language-swift\"")
                }
            }

            for try await renderedExpectedFeatures in group {
                #expect(renderedExpectedFeatures)
            }
        }
    }
    #endif
}

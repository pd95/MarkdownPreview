import Testing
@testable import MarkdownPipeline

@Suite("Front Matter")
struct FrontMatterTests {
    @Test func noFrontMatterReturnsOriginal() {
        let input = "# Title\nBody text"
        let result = FrontMatterExtractor().extract(from: input)
        #expect(result.frontMatter == nil)
        #expect(result.bodyMarkdown == input)
        #expect(result.bodyLineOffset == 0)
    }

    @Test func validFrontMatterExtractsValues() {
        let input = """
        ---
        title: Something
        theme: dark
        ---
        # Content
        """
        let result = FrontMatterExtractor().extract(from: input)
        #expect(result.frontMatter?.title == "Something")
        #expect(result.frontMatter?.theme == "dark")
        #expect(result.bodyMarkdown == "# Content")
        #expect(result.bodyLineOffset == 4)
    }

    @Test func malformedFrontMatterIsIgnored() {
        let input = """
        ---
        title: Something
        # Content
        """
        let result = FrontMatterExtractor().extract(from: input)
        #expect(result.frontMatter == nil)
        #expect(result.bodyMarkdown == input)
        #expect(result.bodyLineOffset == 0)
    }

    @Test func windowsLineEndingsKeepLogicalSourceLines() {
        let input = "---\r\ntitle: Windows\r\n---\r\n# Content"
        let result = FrontMatterExtractor().extract(from: input)

        #expect(result.frontMatter?.title == "Windows")
        #expect(result.bodyMarkdown == "# Content")
        #expect(result.bodyLineOffset == 3)
    }
}

@Test func sanitizesDisallowedRawHTML() throws {
    let input = "<script>alert('xss')</script>"
    let pipeline = MarkdownPipeline()
    let document = try pipeline.render(input: .string(input), context: PipelineContext())
    #expect(document.html.contains("&lt;script"))
}

@Test func sanitizesUnsafeLinks() throws {
    let input = "[link](javascript:alert(1))"
    let pipeline = MarkdownPipeline()
    let document = try pipeline.render(input: .string(input), context: PipelineContext())
    #expect(document.html.contains("href=\"#\""))
}

#if canImport(JavaScriptCore)
@Suite("Highlighting")
struct HighlightingTests {
    @Test func highlightsExplicitLanguageBlocks() throws {
        let input = """
        ```swift
        let value = 1
        ```
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("class=\"hljs"))
        #expect(document.html.contains("language-swift"))
    }

    @Test func highlightsAutoLanguageBlocksWithSubset() throws {
        let input = """
        ```
        function greet(name) {
          return "Hello " + name;
        }
        ```
        """
        let pipeline = MarkdownPipeline()
        let context = PipelineContext(highlightLanguageSubset: ["swift", "javascript"])
        let document = try pipeline.render(input: .string(input), context: context)
        #expect(document.html.contains("class=\"hljs"))
        #expect(document.html.contains("language-swift") || document.html.contains("language-javascript"))
    }
}
#endif

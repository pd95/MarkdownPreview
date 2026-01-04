import Testing
@testable import MarkdownPipeline

@Test func noFrontMatterReturnsOriginal() {
    let input = "# Title\nBody text"
    let result = FrontMatterExtractor().extract(from: input)
    #expect(result.frontMatter == nil)
    #expect(result.bodyMarkdown == input)
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
@Test func highlightsCodeBlocksWithHighlightJS() throws {
    let input = """
    ```swift
    let value = 1
    ```
    """
    let pipeline = MarkdownPipeline()
    let document = try pipeline.render(input: .string(input), context: PipelineContext())
    #expect(document.html.contains("class=\"hljs"))
}
#endif

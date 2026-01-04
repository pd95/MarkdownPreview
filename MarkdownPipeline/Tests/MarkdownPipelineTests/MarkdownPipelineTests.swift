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

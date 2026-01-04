import Testing
@testable import MarkdownPipeline

@Suite("HTML Rendering")
struct MarkdownPipelineHTMLRenderingTests {
    @Test func rendersListsAndCheckboxes() throws {
        let input = """
        - First
        - [x] Done
        - [ ] Todo
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<ul>"))
        #expect(document.html.contains("<li>First"))
        #expect(document.html.contains("<input type=\"checkbox\" disabled checked>"))
        #expect(document.html.contains("<input type=\"checkbox\" disabled>"))
    }

    @Test func rendersHeadingAndStrong() throws {
        let input = """
        # Title

        This has **bold** text.
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<h1>Title</h1>"))
        #expect(document.html.contains("<strong>bold</strong>"))
    }

    @Test func rendersBlockQuoteAndRule() throws {
        let input = """
        > Quote line

        ---
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<blockquote>"))
        #expect(document.html.contains("<hr>"))
    }

    @Test func rendersInlineCodeAndLinks() throws {
        let input = "Use `code` and [link](https://example.com)."
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<code>code</code>"))
        #expect(document.html.contains("href=\"https://example.com\""))
    }

    @Test func rendersImagesWithAltText() throws {
        let input = "![Alt text](https://example.com/image.png)"
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<img src=\"https://example.com/image.png\""))
        #expect(document.html.contains("alt=\"Alt text\""))
    }

    @Test func rendersTables() throws {
        let input = """
        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<table>"))
        #expect(document.html.contains("<thead>"))
        #expect(document.html.contains("<tbody>"))
    }
}

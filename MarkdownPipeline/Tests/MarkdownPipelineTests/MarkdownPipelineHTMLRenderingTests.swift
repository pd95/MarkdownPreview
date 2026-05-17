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
        #expect(document.html.contains("<h1 id=\"title\">Title</h1>"))
        #expect(document.html.contains("<strong>bold</strong>"))
    }

    @Test func rendersHeadingAnchorsWithDeduping() throws {
        let input = """
        # Hello World
        ## Hello World
        # Hello, World!
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<h1 id=\"hello-world\">Hello World</h1>"))
        #expect(document.html.contains("<h2 id=\"hello-world-1\">Hello World</h2>"))
        #expect(document.html.contains("<h1 id=\"hello-world-2\">Hello, World!</h1>"))
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

    @Test func rendersCodeBlockWithoutHighlighting() throws {
        let input = """
        ```swift
        let value = 1
        ```
        """
        let pipeline = MarkdownPipeline()
        let context = PipelineContext(enableCodeHighlighting: false)
        let document = try pipeline.render(input: .string(input), context: context)
        #expect(document.html.contains("<pre><code class=\"lang-swift\">"))
        #expect(document.html.contains("class=\"hljs") == false)
    }

    @Test func rendersFencedCodeInsideFencedCodeAsLiteralText() throws {
        let input = """
        ```markdown
        ```swift
        let value = 1
        ```
        ```
        """
        let pipeline = MarkdownPipeline()
        let context = PipelineContext(enableCodeHighlighting: false)
        let document = try pipeline.render(input: .string(input), context: context)
        let preCount = document.html.components(separatedBy: "<pre>").count - 1

        #expect(preCount == 1)
        #expect(document.html.contains("<pre><code class=\"lang-markdown\">"))
        #expect(document.html.contains("```swift"))
        #expect(document.html.contains("let value = 1"))
        #expect(document.html.contains("</code></pre>"))
    }

    @Test func rendersMarkdownCodeBlockContainingBashFenceAsLiteralText() throws {
        let input = """
        ```markdown
        ## Validation

        ```bash
        go test ./...
        go build ./...
        ```

        Done.
        ```
        """
        let pipeline = MarkdownPipeline()
        let context = PipelineContext(enableCodeHighlighting: false)
        let document = try pipeline.render(input: .string(input), context: context)
        let preCount = document.html.components(separatedBy: "<pre>").count - 1

        #expect(preCount == 1)
        #expect(document.html.contains("```bash"))
        #expect(document.html.contains("go test ./..."))
        #expect(document.html.contains("Done."))
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

    @Test func rendersEmbeddedBase64Images() throws {
        let input = "![Alt](data:image/png;base64,aGVsbG8=)"
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("src=\"data:image/png;base64,aGVsbG8=\""))
    }

    @Test func filtersEmbeddedImagesWithDisallowedTypesOrEncoding() throws {
        let input = """
        ![Svg](data:image/svg+xml;base64,PHN2Zy8+)
        ![Plain](data:image/png,hello)
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("<img src=\"data:image/svg+xml") == false)
        #expect(document.html.contains("<img src=\"data:image/png,hello\"") == false)
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

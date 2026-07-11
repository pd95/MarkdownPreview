import Testing
@testable import MarkdownPipeline

@Suite("HTML Rendering")
struct MarkdownPipelineHTMLRenderingTests {
    @Test func rendersWikiLinksAndReportsMetadata() throws {
        let input = "See [[overview]], [[guides/start.md]], and [[open-questions|the backlog]]."
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())

        #expect(document.containsWikiLinks)
        #expect(document.html.contains("href=\"marklens-wikilink://open?target=overview\""))
        #expect(document.html.contains("href=\"marklens-wikilink://open?target=guides/start.md\""))
        #expect(document.html.contains(">the backlog</a>"))
    }

    @Test func leavesUnsupportedWikiLinkFormsAsText() throws {
        let input = "[[../secret]] [[note#Heading]] [[note^block]] [[note|]]"
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())

        #expect(document.containsWikiLinks == false)
        #expect(document.html.contains("[[../secret]]"))
        #expect(document.html.contains("[[note#Heading]]"))
    }

    @Test func doesNotRenderWikiLinksInsideCode() throws {
        let input = "Use `[[inline]]`.\n\n```text\n[[fenced]]\n```"
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())

        #expect(document.containsWikiLinks == false)
        #expect(document.html.contains("<code>[[inline]]</code>"))
        #expect(document.html.contains("[[fenced]]"))
    }

    @Test func escapedWikiLinkRemainsText() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"\[[overview]]"#),
            context: PipelineContext()
        )

        #expect(document.containsWikiLinks == false)
        #expect(document.html.contains("[[overview]]"))
    }

    @Test func escapedBackslashLeavesWikiLinkActive() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"\\[[overview]]"#),
            context: PipelineContext()
        )

        #expect(document.containsWikiLinks)
        #expect(document.html.contains(#"\<a href="marklens-wikilink://open?target=overview""#))
    }

    @Test func oddBackslashRunEscapesWikiLink() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"\\\[[overview]]"#),
            context: PipelineContext()
        )

        #expect(document.containsWikiLinks == false)
        #expect(document.html.contains(#"\[[overview]]"#))
    }

    @Test func wikilinkInsideMarkdownLinkRemainsText() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string("[Outer [[overview]]](https://example.com)"),
            context: PipelineContext()
        )

        #expect(document.containsWikiLinks == false)
        #expect(document.html.contains("<a href=\"https://example.com\">Outer [[overview]]</a>"))
        #expect(document.html.contains("data-marklens-wikilink") == false)
    }

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
        #expect(document.html.contains("data-marklens-local-image") == false)
    }

    @Test func marksOnlyMarkdownLocalImagesForNativeLoading() throws {
        let input = """
        ![Relative](images/example.png)
        ![File](file:///tmp/example.png)
        <img src="images/raw.png">
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        let markerCount = document.html.components(separatedBy: "data-marklens-local-image").count - 1

        #expect(markerCount == 2)
        #expect(document.html.contains("images/raw.png\" data-marklens-local-image") == false)
    }

    @Test func stripsReservedLocalImageCapabilitiesFromRawHTML() throws {
        let input = """
        <img src="images/raw.png" data-marklens-local-image="Zm9yZ2Vk">
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())

        #expect(document.html.contains("data-marklens-local-image") == false)
    }

    @Test func rendersEmbeddedBase64Images() throws {
        let input = "![Alt](data:image/png;base64,aGVsbG8=)"
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())
        #expect(document.html.contains("src=\"data:image/png;base64,aGVsbG8=\""))
        #expect(document.html.contains("data-marklens-local-image") == false)
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

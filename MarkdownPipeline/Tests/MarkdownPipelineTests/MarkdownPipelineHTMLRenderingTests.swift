import Foundation
import Testing
@testable import MarkdownPipeline

@Suite("HTML Rendering")
struct MarkdownPipelineHTMLRenderingTests {
    @Test func recognizesGitHubMathSyntax() throws {
        let input = #"Inline $\rightarrow$ and $`\frac{1}{2}`$."#
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.count == 2)
        #expect(protected.expressions.values.contains { $0.source == #"\rightarrow"# })
        #expect(protected.expressions.values.contains { $0.source == #"\frac{1}{2}"# })
        #expect(protected.expressions.values.allSatisfy { $0.displayMode == false })
    }

    @Test func recognizesMultilineDisplayMath() {
        let input = """
        Before

        $$
        E = mc^2
        $$

        After
        """
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.count == 1)
        #expect(protected.expressions.values.first?.source == "E = mc^2")
        #expect(protected.expressions.values.first?.displayMode == true)
    }

    @Test func ignoresMathSyntaxInCodeAndCurrency() {
        let input = """
        Cost $20 and $30.

        Use `$x$`.

        ```text
        $y$
        ```
        """
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.isEmpty)
        #expect(protected.markdown == input)
    }

    @Test func keepsMathPlaceholdersOutOfDestinationsAndRawHTMLAttributes() throws {
        let input = """
        [label $x$](https://example.com/$asset$)
        ![formula $y$](images/$image$.png "title $raw$")
        <https://example.com/$autolink$>
        <span data-value="$attribute$">body $z$</span>
        <span
          data-multiline="$multiline$">
        comparison x < y and $w$
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(input: .string(input), context: PipelineContext())

        #expect(document.html.contains("MARKLENSMATH") == false)
        #expect(document.html.contains("https://example.com/$asset$"))
        #expect(document.html.contains("images/$image$.png"))
        #expect(document.html.contains("title=\"title $raw$\""))
        #expect(document.html.contains("data-value=\"$attribute$\""))
        #expect(document.html.contains("data-multiline=\"$multiline$\""))
        #expect(document.html.contains("https://example.com/$autolink$"))
        #if !canImport(JavaScriptCore)
        #expect(document.html.contains("label $x$"))
        #expect(document.html.contains("alt=\"formula $y$\""))
        #expect(document.html.contains("body $z$"))
        #endif
    }

    @Test func keepsMathPlaceholdersOutOfReferenceDestinations() throws {
        let input = """
        [label $x$][reference]

        [reference]: https://example.com/$asset$
        """
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.count == 1)
        #expect(protected.markdown.contains("https://example.com/$asset$"))
    }

    @Test func preservesExactMathFenceForFallback() {
        let input = """
          ~~~~Math custom-info
        \\frac{
          ~~~~
        """
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.count == 1)
        #expect(protected.expressions.values.first?.original == input)
        #expect(protected.expressions.values.first?.source == #"\frac{"#)
    }

    @Test func fenceWithTrailingInfoDoesNotCloseCodeBlock() {
        let input = """
        ~~~text
        ~~~math
        $x$
        ~~~
        """
        let protected = MathSyntaxProtector().protect(in: input)

        #expect(protected.expressions.isEmpty)
        #expect(protected.markdown == input)
    }

    @Test func normalizesNestedMarkdownFenceBeforeProtectingFollowingMath() {
        let input = """
        ```markdown
        # Example

        ```swift
        let value = 1
        ```

        ```

        Arrow: $\\rightarrow$
        """
        let normalized = MarkdownFenceNormalizer().normalize(input)
        let protected = MathSyntaxProtector().protect(in: normalized)

        #expect(protected.expressions.count == 1)
        #expect(protected.expressions.values.first?.source == #"\rightarrow"#)
    }

    @Test func unclosedMathFenceRemainsCode() throws {
        let input = """
        ~~~math
        $x$
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(input),
            context: PipelineContext(enableCodeHighlighting: false)
        )

        #expect(document.html.contains("<pre><code class=\"lang-math\">"))
        #expect(document.html.contains("$x$"))
        #expect(document.html.contains("class=\"math math-display\"") == false)
    }

    @Test func indentedCodeNeverBecomesMathOrLeaksPlaceholders() throws {
        let input = """
            $x$

        \t$y$

            $$
            E = mc^2
            $$

            ```math
            \\rightarrow
            ```
        """
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(input),
            context: PipelineContext(enableCodeHighlighting: false)
        )

        #expect(document.html.contains("MARKLENSMATH") == false)
        #expect(document.html.contains("class=\"math math-inline\"") == false)
        #expect(document.html.contains("class=\"math math-display\"") == false)
        #expect(document.html.contains("$x$"))
        #expect(document.html.contains("$y$"))
        #expect(document.html.contains("```math"))
        #expect(document.html.contains(#"\rightarrow"#))
    }

    @Test func preservesMathSourceWhenRendererIsUnavailable() throws {
        #if !canImport(JavaScriptCore)
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"Arrow $\rightarrow$."#),
            context: PipelineContext()
        )

        #expect(document.html.contains(#"Arrow $\rightarrow$."#))
        #endif
    }

    #if canImport(JavaScriptCore)
    @Test func rendersStaticAccessibleKaTeXHTML() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"Arrow $\rightarrow$."#),
            context: PipelineContext()
        )

        #expect(document.html.contains("class=\"math math-inline\""))
        #expect(document.html.contains("class=\"katex-mathml\""))
        #expect(document.html.contains("class=\"katex-html\""))
        #expect(document.html.contains("<script src=") == false)
    }

    @Test func preservesMalformedTeXSource() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string(#"Broken $\frac{$ expression."#),
            context: PipelineContext()
        )

        #expect(document.html.contains(#"$\frac{$"#))
        #expect(document.html.contains("class=\"math math-inline\"") == false)
    }
    #endif

    @Test func treatsMathFenceAsDisplayMathInsteadOfCode() throws {
        let pipeline = MarkdownPipeline()
        let document = try pipeline.render(
            input: .string("""
            ```math
            E = mc^2
            ```
            """),
            context: PipelineContext()
        )

        #expect(document.html.contains("<pre><code") == false)
        #if !canImport(JavaScriptCore)
        #expect(document.html.contains("```math"))
        #endif
    }

    @Test func packagesKaTeXFontsForCanonicalURLs() throws {
        let assets = try KaTeXAssets.load()

        #expect(assets.resources.count == 20)
        #expect(assets.resources.allSatisfy { $0.contentType == "font/woff2" })
        #expect(assets.resources.allSatisfy { assets.stylesheet.contains($0.url.absoluteString) })
        #expect(assets.stylesheet.contains("fonts/KaTeX_Main-Regular.woff") == false)
        #expect(assets.stylesheet.contains("fonts/KaTeX_Main-Regular.ttf") == false)
    }

    @Test func standaloneHTMLInlinesPackagedFonts() throws {
        let resource = HTMLResource(
            identifier: "test/font.woff2",
            contentType: "font/woff2",
            data: Data([1, 2, 3])
        )
        let document = HTMLDocument(
            html: "<style>src: url(\(resource.url.absoluteString))</style>",
            title: nil,
            baseURL: nil,
            resources: [resource]
        )

        #expect(document.standaloneHTML.contains("marklens-resource://") == false)
        #expect(document.standaloneHTML.contains("data:font/woff2;base64,"))
    }

    @Test func publicResourceIdentifiersProduceSafeURLs() {
        let resource = HTMLResource(
            identifier: "folder/unsafe value/☃.woff2",
            contentType: "font/woff2",
            data: Data()
        )

        #expect(resource.url.scheme == "marklens-resource")
        #expect(resource.url.absoluteString.contains("%20"))
    }

    @Test func contentIdentifiersAreStableAndCollisionResistant() {
        let first = HTMLResource(identifier: "a/b.c", contentType: "text/plain", data: Data())
        let second = HTMLResource(identifier: "a-b-c", contentType: "text/plain", data: Data())

        #expect(first.contentIdentifier != second.contentIdentifier)
        #expect(first.contentIdentifier == "marklens-YS9iLmM")
        #expect(first.contentIdentifier.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        })
    }

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

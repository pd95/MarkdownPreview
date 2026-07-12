import XCTest
import MarkdownPipeline
@testable import MarkLens

final class KaTeXIntegrationTests: XCTestCase {
    func testRendersStaticAccessibleMathOnApplePlatforms() throws {
        let pipeline = MarkdownPipeline.defaultHTML()
        let document = try pipeline.renderHTML(from: .string(#"Arrow $\rightarrow$."#))

        XCTAssertTrue(document.html.contains("class=\"math math-inline\""))
        XCTAssertTrue(document.html.contains("class=\"katex-mathml\""))
        XCTAssertTrue(document.html.contains("class=\"katex-html\""))
        XCTAssertFalse(document.html.contains("undefined"))
        XCTAssertEqual(document.resources.count, 20)
    }

    func testMalformedMathPreservesOriginalSource() throws {
        let pipeline = MarkdownPipeline.defaultHTML()
        let document = try pipeline.renderHTML(from: .string(#"Broken $\frac{$ expression."#))

        XCTAssertTrue(document.html.contains(#"$\frac{$"#))
        XCTAssertFalse(document.html.contains("undefined"))
        XCTAssertFalse(document.html.contains("class=\"math math-inline\""))
    }

    func testMathInLinkLabelDoesNotLeakPlaceholder() throws {
        let pipeline = MarkdownPipeline.defaultHTML()
        let document = try pipeline.renderHTML(
            from: .string(#"[value $x$](https://example.com/$asset$)"#)
        )

        XCTAssertTrue(document.html.contains("class=\"math math-inline\""))
        XCTAssertTrue(document.html.contains("https://example.com/$asset$"))
        XCTAssertFalse(document.html.contains("MARKLENSMATH"))
    }

    func testMathAfterNestedMarkdownFenceRenders() throws {
        let source = """
        ```markdown
        # Example

        ```swift
        let value = 1
        ```

        ```

        Arrow: $\\rightarrow$

        $$
        E = mc^2
        $$
        """
        let document = try MarkdownPipeline.defaultHTML().renderHTML(from: .string(source))

        XCTAssertEqual(
            document.html.components(separatedBy: "class=\"math math-inline\"").count - 1,
            1
        )
        XCTAssertEqual(
            document.html.components(separatedBy: "class=\"math math-display\"").count - 1,
            1
        )
        XCTAssertFalse(document.html.contains("MARKLENSMATH"))
        XCTAssertEqual(document.resources.count, 20)
    }
}

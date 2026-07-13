import JavaScriptCore
import MarkdownPipeline
import XCTest
@testable import MarkLens

final class CustomCSSIntegrationTests: XCTestCase {
    func testUpdateScriptPreservesCSSAsTextContent() throws {
        let css = """
        body::before {
            content: "quotes \\" and slash \\\\ and snowman ☃";
        }
        </style><script>alert('x')</script>
        """
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript("""
        var capturedIdentifier = null;
        var style = { textContent: null };
        var document = {
            getElementById: function(identifier) {
                capturedIdentifier = identifier;
                return style;
            }
        };
        """)

        context.evaluateScript(MarkdownWebView.customCSSUpdateScript(for: css))

        XCTAssertEqual(context.objectForKeyedSubscript("capturedIdentifier")?.toString(),
                       HTMLFeature.customCSSStyleElementID)
        XCTAssertEqual(context.objectForKeyedSubscript("style")?
            .objectForKeyedSubscript("textContent")?.toString(), css)
        XCTAssertNil(context.exception)
    }
}

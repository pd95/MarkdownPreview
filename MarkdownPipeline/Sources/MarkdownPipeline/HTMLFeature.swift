/// A selectable, built-in capability of the HTML rendering pipeline.
///
/// Features are descriptors rather than extension points: clients can compose and configure
/// the capabilities shipped by MarkdownPipeline, while their implementations remain internal.
public struct HTMLFeature: Sendable {
    enum Configuration: Sendable {
        case wikiLinks
        case syntaxHighlighting(languageSubset: [String])
        case math
        case mermaid(rendering: PipelineContext.MermaidRendering)
        case customCSS(String)
    }

    let configuration: Configuration

    private init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    public static func wikiLinks() -> HTMLFeature {
        HTMLFeature(.wikiLinks)
    }

    public static func syntaxHighlighting(languageSubset: [String] = []) -> HTMLFeature {
        HTMLFeature(.syntaxHighlighting(languageSubset: languageSubset))
    }

    public static func math() -> HTMLFeature {
        HTMLFeature(.math)
    }

    public static func mermaid(
        rendering: PipelineContext.MermaidRendering = .rendered
    ) -> HTMLFeature {
        HTMLFeature(.mermaid(rendering: rendering))
    }

    /// Adds a final stylesheet whose rules can override the bundled presentation.
    ///
    /// The style element is emitted even when `css` is empty so clients can update it live.
    public static func customCSS(_ css: String = "") -> HTMLFeature {
        HTMLFeature(.customCSS(css))
    }

    /// The stable DOM identifier used by the custom CSS feature's style element.
    public static let customCSSStyleElementID = "marklens-custom-css"

    /// The complete feature set used by `MarkdownPipeline.defaultHTML(theme:)`.
    public static var defaultHTML: [HTMLFeature] {
        [.wikiLinks(), .syntaxHighlighting(), .math(), .mermaid(), .customCSS()]
    }
}

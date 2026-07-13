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

    /// The complete feature set used by `MarkdownPipeline.defaultHTML(theme:)`.
    public static var defaultHTML: [HTMLFeature] {
        [.wikiLinks(), .syntaxHighlighting(), .math(), .mermaid()]
    }
}

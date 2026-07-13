import Foundation

public struct PipelineContext {
    public enum Theme: String, Sendable {
        case light
        case dark
        case auto
    }

    public enum MermaidRendering: Sendable, Equatable {
        case rendered
        case sourceWithAppHint
    }

    public var title: String?
    public var baseURL: URL?
    public var theme: Theme
    /// Legacy per-render override. Prefer configuring `.syntaxHighlighting(languageSubset:)`
    /// when constructing `MarkdownPipeline`.
    public var highlightLanguageSubset: [String]
    /// Legacy per-render switch retained for source compatibility.
    public var enableCodeHighlighting: Bool
    /// Legacy per-render override. A source fallback requested here or by the Mermaid feature wins.
    public var mermaidRendering: MermaidRendering

    public init(
        title: String? = nil,
        baseURL: URL? = nil,
        theme: Theme = .auto,
        highlightLanguageSubset: [String] = [],
        enableCodeHighlighting: Bool = true,
        mermaidRendering: MermaidRendering = .rendered
    ) {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.highlightLanguageSubset = highlightLanguageSubset
        self.enableCodeHighlighting = enableCodeHighlighting
        self.mermaidRendering = mermaidRendering
    }
}

import Foundation

public struct PipelineContext {
    public enum Theme: String {
        case light
        case dark
        case auto
    }

    public enum MermaidRendering: Sendable {
        case rendered
        case sourceWithAppHint
    }

    public var title: String?
    public var baseURL: URL?
    public var theme: Theme
    public var highlightLanguageSubset: [String]
    public var enableCodeHighlighting: Bool
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

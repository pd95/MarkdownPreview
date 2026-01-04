import Foundation

public struct PipelineContext {
    public enum Theme: String {
        case light
        case dark
        case auto
    }

    public var title: String?
    public var baseURL: URL?
    public var theme: Theme
    public var highlightLanguageSubset: [String]

    public init(
        title: String? = nil,
        baseURL: URL? = nil,
        theme: Theme = .auto,
        highlightLanguageSubset: [String] = []
    ) {
        self.title = title
        self.baseURL = baseURL
        self.theme = theme
        self.highlightLanguageSubset = highlightLanguageSubset
    }
}

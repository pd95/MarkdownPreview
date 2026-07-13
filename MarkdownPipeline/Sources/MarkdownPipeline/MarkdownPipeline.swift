import Foundation

public struct MarkdownPipeline: Sendable {
    private let defaultTheme: PipelineContext.Theme
    private let plugins: [any HTMLRenderingPlugin]

    /// Creates an HTML pipeline from built-in feature descriptors.
    ///
    /// Feature order does not affect execution order. When a feature appears more than once,
    /// its last configuration is used.
    public init(
        defaultTheme: PipelineContext.Theme = .auto,
        plugins: [HTMLFeature] = HTMLFeature.defaultHTML
    ) {
        self.defaultTheme = defaultTheme
        self.plugins = Self.makePlugins(from: plugins)
    }

    public static func defaultHTML(theme: PipelineContext.Theme = .auto) -> MarkdownPipeline {
        MarkdownPipeline(defaultTheme: theme)
    }

    public func renderHTML(from input: MarkdownInput, context: PipelineContext = PipelineContext()) throws -> HTMLDocument {
        try render(input: input, context: context)
    }

    public func render(input: MarkdownInput, context: PipelineContext) throws -> HTMLDocument {
        let markdown = try input.resolvedString()
        let extraction = FrontMatterExtractor().extract(from: markdown)
        let mergedContext = merge(context: context, frontMatter: extraction.frontMatter)

        let coordinator = HTMLPluginCoordinator(plugins: plugins, context: mergedContext)
        let normalizedMarkdown = MarkdownFenceNormalizer().normalize(extraction.bodyMarkdown)
        let preparedMarkdown = coordinator.preprocess(normalizedMarkdown)
        let document = SwiftMarkdownParser().parse(markdown: preparedMarkdown)
        let renderedBody = HTMLVisitor.render(
            document: document,
            keepLineBreaks: true,
            plugins: coordinator
        )
        let contribution = try coordinator.contribution()
        let html = try HTMLEmitter().render(
            bodyHTML: renderedBody.html,
            title: mergedContext.title,
            additionalStyles: contribution.styles,
            additionalScripts: contribution.scripts
        )
        return HTMLDocument(
            html: html,
            title: mergedContext.title,
            baseURL: mergedContext.baseURL,
            containsWikiLinks: contribution.containsWikiLinks,
            resources: contribution.resources
        )
    }

    private func merge(context: PipelineContext, frontMatter: FrontMatter?) -> PipelineContext {
        var merged = context
        if merged.title == nil {
            merged.title = frontMatter?.title
        }
        if let rawTheme = frontMatter?.theme?.lowercased(),
           let parsedTheme = PipelineContext.Theme(rawValue: rawTheme) {
            merged.theme = parsedTheme
        }
        if merged.theme == .auto {
            merged.theme = defaultTheme
        }
        return merged
    }

    private static func makePlugins(from features: [HTMLFeature]) -> [any HTMLRenderingPlugin] {
        var includesWikiLinks = false
        var includesMath = false
        var highlightingSubset: [String]?
        var mermaidRendering: PipelineContext.MermaidRendering?

        for feature in features {
            switch feature.configuration {
            case .wikiLinks:
                includesWikiLinks = true
            case .syntaxHighlighting(let languageSubset):
                highlightingSubset = languageSubset
            case .math:
                includesMath = true
            case .mermaid(let rendering):
                mermaidRendering = rendering
            }
        }

        var plugins: [any HTMLRenderingPlugin] = []
        if includesMath {
            plugins.append(MathHTMLPlugin())
        }
        if includesWikiLinks {
            plugins.append(WikiLinkHTMLPlugin())
        }
        if let mermaidRendering {
            plugins.append(MermaidHTMLPlugin(rendering: mermaidRendering))
        }
        if let highlightingSubset {
            plugins.append(SyntaxHighlightingHTMLPlugin(languageSubset: highlightingSubset))
        }
        return plugins
    }
}

enum MarkdownPipelineError: Error {
    case invalidStringEncoding
    case missingResource(String)
}

import Foundation

public struct MarkdownPipeline {
    private let defaultTheme: PipelineContext.Theme
    private let highlighter: HLJSHighlighter
    private let mathRenderer: KaTeXRenderer

    public init(defaultTheme: PipelineContext.Theme = .auto) {
        self.defaultTheme = defaultTheme
        self.highlighter = HLJSHighlighter()
        self.mathRenderer = KaTeXRenderer()
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

        let normalizedMarkdown = MarkdownFenceNormalizer().normalize(extraction.bodyMarkdown)
        let protectedMath = MathSyntaxProtector().protect(in: normalizedMarkdown)
        let protectedMarkdown = WikiLinkEscapes.protect(in: protectedMath.markdown)
        let document = SwiftMarkdownParser().parse(markdown: protectedMarkdown.markdown)
        let highlights: [Int: CodeHighlightResult]
        if mergedContext.enableCodeHighlighting {
            highlights = CodeBlockHighlighter(
                highlighter: highlighter,
                languageSubset: mergedContext.highlightLanguageSubset
            ).highlights(for: document)
        } else {
            highlights = [:]
        }
        let renderedBody = HTMLVisitor.render(
            document: document,
            keepLineBreaks: true,
            codeBlockHighlights: highlights,
            escapedWikiLinkPlaceholder: protectedMarkdown.placeholder,
            mathExpressions: protectedMath.expressions,
            mathRenderer: mathRenderer
        )
        let katexAssets: KaTeXAssets?
        if renderedBody.containsRenderedMath {
            katexAssets = try KaTeXAssets.load()
        } else {
            katexAssets = nil
        }
        let html = try HTMLEmitter().render(
            bodyHTML: renderedBody.html,
            title: mergedContext.title,
            theme: mergedContext.theme,
            additionalStyles: katexAssets?.stylesheet ?? ""
        )
        return HTMLDocument(
            html: html,
            title: mergedContext.title,
            baseURL: mergedContext.baseURL,
            containsWikiLinks: renderedBody.containsWikiLinks,
            resources: katexAssets?.resources ?? []
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
}

enum MarkdownPipelineError: Error {
    case invalidStringEncoding
    case missingResource(String)
}

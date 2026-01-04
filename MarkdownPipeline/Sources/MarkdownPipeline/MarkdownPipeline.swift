import Foundation

public struct MarkdownPipeline {
    private let defaultTheme: PipelineContext.Theme
    private let highlighter: HLJSHighlighter

    public init(defaultTheme: PipelineContext.Theme = .auto) {
        self.defaultTheme = defaultTheme
        self.highlighter = HLJSHighlighter()
    }

    public static func defaultHTML(theme: PipelineContext.Theme = .auto) -> MarkdownPipeline {
        MarkdownPipeline(defaultTheme: theme)
    }

    public func render(input: MarkdownInput, context: PipelineContext) throws -> HTMLDocument {
        let markdown = try input.resolvedString()
        let extraction = FrontMatterExtractor().extract(from: markdown)
        let mergedContext = merge(context: context, frontMatter: extraction.frontMatter)

        let document = SwiftMarkdownParser().parse(markdown: extraction.bodyMarkdown)
        let highlights = CodeBlockHighlighter(
            highlighter: highlighter,
            languageSubset: mergedContext.highlightLanguageSubset
        ).highlights(for: document)
        let bodyHTML = HTMLVisitor.render(
            document: document,
            keepLineBreaks: true,
            codeBlockHighlights: highlights
        )
        let html = try HTMLEmitter().render(bodyHTML: bodyHTML, title: mergedContext.title, theme: mergedContext.theme)
        return HTMLDocument(html: html, title: mergedContext.title, baseURL: mergedContext.baseURL)
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

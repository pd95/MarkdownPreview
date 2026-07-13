import Markdown

struct CodeBlockHighlighter {
    let highlighter: HLJSHighlighter
    let languageSubset: [String]

    func highlights(for document: Document) -> [Int: CodeHighlightResult] {
        var collector = Collector(highlighter: highlighter, languageSubset: languageSubset)
        _ = collector.visit(document)
        return collector.highlights
    }

    private struct Collector: MarkupVisitor {
        let highlighter: HLJSHighlighter
        let languageSubset: [String]
        var index = 0
        var highlights: [Int: CodeHighlightResult] = [:]

        mutating func defaultVisit(_ markup: any Markup) -> String {
            var result = ""
            for child in markup.children {
                result += visit(child)
            }
            return result
        }

        mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
            if codeBlock.language?
                .split(whereSeparator: { $0.isWhitespace })
                .first?
                .lowercased() != "mermaid" {
                let result = highlighter.highlight(
                    code: codeBlock.code,
                    language: codeBlock.language,
                    languageSubset: languageSubset
                )
                if let result {
                    highlights[index] = result
                }
            }
            index += 1
            return ""
        }
    }
}

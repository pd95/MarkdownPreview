import Foundation
import Markdown

extension String {
    func encodedHTMLEntities() -> String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func encodedHTMLAttribute() -> String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

struct HTMLVisitor: MarkupVisitor {
    struct RenderResult {
        let html: String
        let containsWikiLinks: Bool
        let containsRenderedMath: Bool
        let containsMermaidDiagrams: Bool
    }

    var softBreak: String
    var skipParagraphTags = false
    var currentTable: Table?
    var currentColumnIndex = 0
    var codeBlockIndex = 0
    var codeBlockHighlights: [Int: CodeHighlightResult]
    var headingIDCounts: [String: Int] = [:]
    var containsWikiLinks = false
    var escapedWikiLinkPlaceholder: String?
    var linkDepth = 0
    var containsRenderedMath = false
    var containsMermaidDiagrams = false
    let mermaidRendering: PipelineContext.MermaidRendering
    let mathExpressions: [String: ProtectedMath.Expression]
    let mathRenderer: KaTeXRenderer

    static let disallowedRawHTMLTags = [
        "title",
        "textarea",
        "style",
        "xmp",
        "iframe",
        "noembed",
        "noframes",
        "script",
        "plaintext"
    ]

    init(
        keepLineBreaks: Bool = false,
        codeBlockHighlights: [Int: CodeHighlightResult] = [:],
        escapedWikiLinkPlaceholder: String? = nil,
        mathExpressions: [String: ProtectedMath.Expression] = [:],
        mathRenderer: KaTeXRenderer = KaTeXRenderer(),
        mermaidRendering: PipelineContext.MermaidRendering = .rendered
    ) {
        softBreak = keepLineBreaks ? "<br>" : "\n"
        self.codeBlockHighlights = codeBlockHighlights
        self.escapedWikiLinkPlaceholder = escapedWikiLinkPlaceholder
        self.mathExpressions = mathExpressions
        self.mathRenderer = mathRenderer
        self.mermaidRendering = mermaidRendering
    }

    static func render(
        document: Document,
        keepLineBreaks: Bool = false,
        codeBlockHighlights: [Int: CodeHighlightResult] = [:],
        escapedWikiLinkPlaceholder: String? = nil,
        mathExpressions: [String: ProtectedMath.Expression] = [:],
        mathRenderer: KaTeXRenderer = KaTeXRenderer(),
        mermaidRendering: PipelineContext.MermaidRendering = .rendered
    ) -> RenderResult {
        var visitor = HTMLVisitor(
            keepLineBreaks: keepLineBreaks,
            codeBlockHighlights: codeBlockHighlights,
            escapedWikiLinkPlaceholder: escapedWikiLinkPlaceholder,
            mathExpressions: mathExpressions,
            mathRenderer: mathRenderer,
            mermaidRendering: mermaidRendering
        )
        let html = visitor.visit(document)
        return RenderResult(
            html: html,
            containsWikiLinks: visitor.containsWikiLinks,
            containsRenderedMath: visitor.containsRenderedMath,
            containsMermaidDiagrams: visitor.containsMermaidDiagrams
        )
    }

    mutating func defaultVisit(_ markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    mutating func visitText(_ text: Text) -> String {
        renderTextAndMath(text.plainText, renderWikiLinks: linkDepth == 0)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        if paragraph.childCount == 1,
           let text = paragraph.child(at: 0) as? Text,
           let expression = mathExpressions[text.plainText],
           expression.displayMode {
            return renderMath(expression) + "\n"
        }
        var result: String
        let shouldSkipParagraph = skipParagraphTags
        if shouldSkipParagraph {
            skipParagraphTags = false
            result = ""
        } else {
            result = "<p>"
        }

        for child in paragraph.children {
            result += visit(child)
        }

        if shouldSkipParagraph {
            result += "\n"
        } else {
            result += "</p>\n"
        }
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        var result = "<strong>"
        for child in strong.children {
            result += visit(child)
        }
        result += "</strong>"
        return result
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        var result = "<em>"
        for child in emphasis.children {
            result += visit(child)
        }
        result += "</em>"
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        var result = "<del>"
        for child in strikethrough.children {
            result += visit(child)
        }
        result += "</del>"
        return result
    }

    mutating func visitLink(_ link: Link) -> String {
        let destination = sanitizedURL(restoreMathSource(in: link.destination ?? ""), fallback: "#")
            .encodedHTMLAttribute()
        var result = "<a href=\"\(destination)\">"
        linkDepth += 1
        for child in link.children {
            result += visit(child)
        }
        linkDepth -= 1
        result += "</a>"
        return result
    }

    mutating func visitImage(_ image: Image) -> String {
        let sanitizedSource = sanitizedImageURL(restoreMathSource(in: image.source ?? ""), fallback: "")
        let source = sanitizedSource.encodedHTMLAttribute()
        var result = "<img src=\"\(source)\""
        if isLocalImageURL(sanitizedSource),
           let capability = sanitizedSource.data(using: .utf8)?.base64EncodedString() {
            result += " data-marklens-local-image=\"\(capability)\""
        }

        if image.isEmpty == false {
            result += " alt=\""
            for child in image.children {
                if let plainTextMarkup = child as? PlainTextConvertibleMarkup {
                    result += restoreMathSource(in: plainTextMarkup.plainText).encodedHTMLAttribute()
                }
            }
            result += "\""
        }
        result += image.title.map { " title=\"\(restoreMathSource(in: $0).encodedHTMLAttribute())\"" } ?? ""
        result += ">"
        return result
    }

    private func isLocalImageURL(_ raw: String) -> Bool {
        guard raw.isEmpty == false, raw.lowercased().hasPrefix("data:") == false else {
            return false
        }
        guard let scheme = urlScheme(from: raw) else {
            return true
        }
        return scheme.caseInsensitiveCompare("file") == .orderedSame
    }

    func visitInlineCode(_ inlineCode: InlineCode) -> String {
        let code = WikiLinkEscapes.restoreText(
            inlineCode.code,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
        return "<code>\(code.encodedHTMLEntities())</code>"
    }

    func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>"
    }

    func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        self.softBreak
    }

    func visitSymbolLink(_ symbolLink: SymbolLink) -> String {
        "<code>\(symbolLink.destination ?? "")</code>"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let identifier = uniqueHeadingID(for: heading)
        var result = "<h\(heading.level) id=\"\(identifier.encodedHTMLAttribute())\">"
        for child in heading.children {
            result += visit(child)
        }
        result += "</h\(heading.level)>\n"
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let highlight = codeBlockHighlights[codeBlockIndex]
        codeBlockIndex += 1
        if isMermaidLanguage(codeBlock.language) {
            return renderMermaidBlock(codeBlock.code)
        }
        if let highlight {
            let languageClass = highlight.language.map { " language-\($0)" } ?? ""
            let literalHTML = WikiLinkEscapes.restoreText(
                highlight.html,
                placeholder: escapedWikiLinkPlaceholder,
                includeBackslash: true
            )
            return "<pre><code class=\"hljs\(languageClass)\">\(restoreMathSource(in: literalHTML))</code></pre>\n"
        }

        var result = "<pre><code class=\"lang-\(codeBlock.language ?? "plaintext")\">"
        let literalCode = WikiLinkEscapes.restoreText(
            codeBlock.code,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
        result += restoreMathSource(in: literalCode)
            .trimmingCharacters(in: .newlines)
            .encodedHTMLEntities()
        result += "\n</code></pre>\n"
        return result
    }

    private mutating func renderMermaidBlock(_ source: String) -> String {
        let escapedSource = restoreMathSource(in: source)
            .trimmingCharacters(in: .newlines)
            .encodedHTMLEntities()
        switch mermaidRendering {
        case .rendered:
            containsMermaidDiagrams = true
            return """
            <div class="mermaid-block" data-mermaid-diagram>
            <pre class="mermaid-source"><code class="language-mermaid">\(escapedSource)\n</code></pre>
            <p class="mermaid-error" role="status" hidden>Could not render Mermaid diagram. Showing source.</p>
            </div>
            """ + "\n"
        case .sourceWithAppHint:
            return """
            <div class="mermaid-block mermaid-source-fallback">
            <p class="mermaid-hint"><strong>Quick Look source</strong> — open in MarkLens to render this Mermaid diagram</p>
            <pre class="mermaid-source"><code class="lang-plaintext">\(escapedSource)\n</code></pre>
            </div>
            """ + "\n"
        }
    }

    private func isMermaidLanguage(_ language: String?) -> Bool {
        language?
            .split(whereSeparator: { $0.isWhitespace })
            .first?
            .lowercased() == "mermaid"
    }

    private mutating func renderTextAndMath(_ text: String, renderWikiLinks: Bool) -> String {
        var result = ""
        var remaining = text[...]
        while let match = mathExpressions.values
            .compactMap({ expression -> (ProtectedMath.Expression, Range<String.Index>)? in
                guard let range = remaining.range(of: expression.token) else { return nil }
                return (expression, range)
            })
            .min(by: { $0.1.lowerBound < $1.1.lowerBound }) {
            let plain = String(remaining[..<match.1.lowerBound])
            result += renderPlainText(plain, renderWikiLinks: renderWikiLinks)
            result += renderMath(match.0)
            remaining = remaining[match.1.upperBound...]
        }
        result += renderPlainText(String(remaining), renderWikiLinks: renderWikiLinks)
        return result
    }

    private mutating func renderPlainText(_ text: String, renderWikiLinks: Bool) -> String {
        guard renderWikiLinks else {
            return WikiLinkEscapes.restoreText(
                text,
                placeholder: escapedWikiLinkPlaceholder,
                includeBackslash: false
            ).encodedHTMLEntities()
        }
        let rendered = WikiLinkRenderer.render(
            text,
            escapedWikiLinkPlaceholder: escapedWikiLinkPlaceholder
        )
        containsWikiLinks = containsWikiLinks || rendered.containsWikiLinks
        return rendered.html
    }

    private func restoreMathSource(in text: String) -> String {
        mathExpressions.values.reduce(text) { result, expression in
            result.replacingOccurrences(of: expression.token, with: expression.original)
        }
    }

    private mutating func renderMath(_ expression: ProtectedMath.Expression) -> String {
        guard let html = mathRenderer.render(expression.source, displayMode: expression.displayMode) else {
            return expression.original.encodedHTMLEntities()
        }
        containsRenderedMath = true
        let tag = expression.displayMode ? "div" : "span"
        let mode = expression.displayMode ? "display" : "inline"
        return "<\(tag) class=\"math math-\(mode)\">\(html)</\(tag)>"
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        var result = "<blockquote>\n"
        for child in blockQuote.children {
            result += visit(child)
        }
        result += "</blockquote>\n"
        return result
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        var result = "<ol>\n"
        for child in orderedList.listItems {
            result += visit(child)
        }
        result += "</ol>\n"
        return result
    }

    mutating func visitUnorderedList(_ orderedList: UnorderedList) -> String {
        var result = "<ul>\n"
        for child in orderedList.listItems {
            result += visit(child)
        }
        result += "</ul>\n"
        return result
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        var result = "<li>"

        if let checkbox = listItem.checkbox {
            result += "<input type=\"checkbox\" disabled\(checkbox == .checked ? " checked" : "")>"
        }
        skipParagraphTags = true
        for child in listItem.children {
            result += visit(child)
        }

        result += "</li>\n"
        return result
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        let rawHTML = restoreMathSource(in: WikiLinkEscapes.restoreText(
            html.rawHTML,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        ))
        var result = sanitizeRawHTML(rawHTML)
        result += "\n"
        return result
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        let rawHTML = restoreMathSource(in: WikiLinkEscapes.restoreText(
            inlineHTML.rawHTML,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        ))
        return sanitizeRawHTML(rawHTML)
    }

    private func sanitizeRawHTML(_ rawHTML: String) -> String {
        let tags = Self.disallowedRawHTMLTags.joined(separator: "|")
        let pattern = "(?i)<\\s*/?\\s*(\(tags))\\b"
        var result = rawHTML
        if let markerRegex = try? Regex("(?i)\\s+data-marklens-local-image(?:\\s*=\\s*(?:\\\"[^\\\"]*\\\"|'[^']*'|[^\\s>]+))?") {
            result = result.replacing(markerRegex, with: "")
        }

        guard let regex = try? Regex(pattern) else {
            return result
        }
        let matches = result.matches(of: regex)
        if matches.isEmpty {
            return result
        }

        let offsets = matches.map { match in
            result.distance(from: result.startIndex, to: match.range.lowerBound)
        }
        for offset in offsets.sorted(by: >) {
            let index = result.index(result.startIndex, offsetBy: offset)
            result.replaceSubrange(index...index, with: "&lt;")
        }
        return result
    }

    mutating func visitTable(_ table: Table) -> String {
        let previousState = (table: currentTable, index: currentColumnIndex)
        currentTable = table

        var result = "<table>"
        for child in table.children {
            result += visit(child)
        }
        result += "</table>\n"

        currentTable = previousState.table
        currentColumnIndex = previousState.index
        return result
    }

    mutating func visitTableHead(_ head: Table.Head) -> String {
        var result = "<thead>"
        currentColumnIndex = 0
        for child in head.children {
            result += visit(child)
        }

        result += "</thead>\n"
        return result
    }

    mutating func visitTableBody(_ body: Table.Body) -> String {
        var result = "<tbody>"
        for child in body.children {
            result += visit(child)
        }

        result += "</tbody>\n"
        return result
    }

    mutating func visitTableRow(_ row: Table.Row) -> String {
        var result = "<tr>"

        currentColumnIndex = 0
        for child in row.children {
            result += visit(child)
        }

        result += "</tr>\n"
        return result
    }

    mutating func visitTableCell(_ cell: Table.Cell) -> String {
        var attributes = ""
        if cell.colspan > 1 {
            attributes += " colspan=\"\(cell.colspan)\""
        }
        if cell.rowspan > 1 {
            attributes += " rowspan=\"\(cell.rowspan)\""
        }
        if let alignment = currentTable?.columnAlignments[currentColumnIndex] {
            attributes += "  style=\"text-align:\(String(describing: alignment))\""
        }

        var result = "<td\(attributes)>"
        for child in cell.children {
            result += visit(child)
        }

        currentColumnIndex += Int(cell.colspan)

        result += "</td>\n"
        return result
    }

    private func sanitizedURL(_ raw: String?, fallback: String) -> String {
        guard let raw, raw.isEmpty == false else {
            return fallback
        }

        if let scheme = urlScheme(from: raw),
           ["http", "https", "file"].contains(scheme.lowercased()) == false {
            return fallback
        }

        return raw
    }

    private func sanitizedImageURL(_ raw: String?, fallback: String) -> String {
        guard let raw, raw.isEmpty == false else {
            return fallback
        }

        if raw.lowercased().hasPrefix("data:") {
            return isAllowedImageDataURI(raw) ? raw : fallback
        }

        return sanitizedURL(raw, fallback: fallback)
    }

    private func isAllowedImageDataURI(_ raw: String) -> Bool {
        let lowercased = raw.lowercased()
        guard lowercased.hasPrefix("data:image/") else {
            return false
        }

        let allowedTypes = [
            "image/png",
            "image/jpeg",
            "image/gif",
            "image/webp"
        ]

        let headerEnd = lowercased.firstIndex(of: ",")
        guard let headerEnd else {
            return false
        }

        let header = String(lowercased[..<headerEnd])
        guard header.contains(";base64") else {
            return false
        }

        return allowedTypes.contains { header.hasPrefix("data:\($0)") }
    }

    private func urlScheme(from raw: String) -> String? {
        if let range = raw.range(of: "://") {
            return String(raw[..<range.lowerBound])
        }

        if let colonRange = raw.range(of: ":") {
            let prefix = raw[..<colonRange.lowerBound]
            if let terminatorIndex = raw.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }),
               terminatorIndex < colonRange.lowerBound {
                return nil
            }
            return String(prefix)
        }

        return nil
    }

    private mutating func uniqueHeadingID(for heading: Heading) -> String {
        let headingText = WikiLinkEscapes.restoreText(
            heading.plainText,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
        let base = slugifiedHeadingID(from: headingText)
        let count = headingIDCounts[base, default: 0]
        let identifier = count == 0 ? base : "\(base)-\(count)"
        headingIDCounts[base] = count + 1
        return identifier
    }

    private func slugifiedHeadingID(from text: String) -> String {
        let lowercase = text.lowercased()
        var slug = ""
        var needsDash = false

        for scalar in lowercase.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                if needsDash && slug.isEmpty == false {
                    slug.append("-")
                }
                needsDash = false
                slug.append(Character(scalar))
            } else {
                needsDash = true
            }
        }

        if slug.isEmpty {
            return "section"
        }

        return slug
    }
}

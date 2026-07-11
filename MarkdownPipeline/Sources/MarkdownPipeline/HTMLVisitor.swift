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
        escapedWikiLinkPlaceholder: String? = nil
    ) {
        softBreak = keepLineBreaks ? "<br>" : "\n"
        self.codeBlockHighlights = codeBlockHighlights
        self.escapedWikiLinkPlaceholder = escapedWikiLinkPlaceholder
    }

    static func render(
        document: Document,
        keepLineBreaks: Bool = false,
        codeBlockHighlights: [Int: CodeHighlightResult] = [:],
        escapedWikiLinkPlaceholder: String? = nil
    ) -> RenderResult {
        var visitor = HTMLVisitor(
            keepLineBreaks: keepLineBreaks,
            codeBlockHighlights: codeBlockHighlights,
            escapedWikiLinkPlaceholder: escapedWikiLinkPlaceholder
        )
        let html = visitor.visit(document)
        return RenderResult(html: html, containsWikiLinks: visitor.containsWikiLinks)
    }

    mutating func defaultVisit(_ markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    mutating func visitText(_ text: Text) -> String {
        guard linkDepth == 0 else {
            return WikiLinkEscapes.restoreText(
                text.plainText,
                placeholder: escapedWikiLinkPlaceholder,
                includeBackslash: false
            ).encodedHTMLEntities()
        }
        let rendered = WikiLinkRenderer.render(
            text.plainText,
            escapedWikiLinkPlaceholder: escapedWikiLinkPlaceholder
        )
        containsWikiLinks = containsWikiLinks || rendered.containsWikiLinks
        return rendered.html
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
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
        let destination = sanitizedURL(link.destination, fallback: "#").encodedHTMLAttribute()
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
        let sanitizedSource = sanitizedImageURL(image.source, fallback: "")
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
                    result += plainTextMarkup.plainText.encodedHTMLAttribute()
                }
            }
            result += "\""
        }
        result += image.title.map { " title=\"\($0.encodedHTMLAttribute())\"" } ?? ""
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

        if let highlight {
            let languageClass = highlight.language.map { " language-\($0)" } ?? ""
            let literalHTML = WikiLinkEscapes.restoreText(
                highlight.html,
                placeholder: escapedWikiLinkPlaceholder,
                includeBackslash: true
            )
            return "<pre><code class=\"hljs\(languageClass)\">\(literalHTML)</code></pre>\n"
        }

        var result = "<pre><code class=\"lang-\(codeBlock.language ?? "plaintext")\">"
        let literalCode = WikiLinkEscapes.restoreText(
            codeBlock.code,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
        result += literalCode.trimmingCharacters(in: .newlines).encodedHTMLEntities()
        result += "\n</code></pre>\n"
        return result
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
        let rawHTML = WikiLinkEscapes.restoreText(
            html.rawHTML,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
        var result = sanitizeRawHTML(rawHTML)
        result += "\n"
        return result
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        let rawHTML = WikiLinkEscapes.restoreText(
            inlineHTML.rawHTML,
            placeholder: escapedWikiLinkPlaceholder,
            includeBackslash: true
        )
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

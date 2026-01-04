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
    var softBreak: String
    var skipParagraphTags = false
    var currentTable: Table?
    var currentColumnIndex = 0

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

    init(keepLineBreaks: Bool = false) {
        softBreak = keepLineBreaks ? "<br>" : "\n"
    }

    static func render(document: Document, keepLineBreaks: Bool = false) -> String {
        var visitor = HTMLVisitor(keepLineBreaks: keepLineBreaks)
        return visitor.visit(document)
    }

    mutating func defaultVisit(_ markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    func visitText(_ text: Text) -> String {
        text.plainText.encodedHTMLEntities()
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
        for child in link.children {
            result += visit(child)
        }
        result += "</a>"
        return result
    }

    mutating func visitImage(_ image: Image) -> String {
        let source = sanitizedURL(image.source, fallback: "").encodedHTMLAttribute()
        var result = "<img src=\"\(source)\""

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

    func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(inlineCode.code.encodedHTMLEntities())</code>"
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
        var result = "<h\(heading.level)>"
        for child in heading.children {
            result += visit(child)
        }
        result += "</h\(heading.level)>\n"
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        var result = "<pre><code class=\"lang-\(codeBlock.language ?? "plaintext")\">"
        result += codeBlock.code.trimmingCharacters(in: .newlines).encodedHTMLEntities()
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
        var result = sanitizeRawHTML(html.rawHTML)
        result += "\n"
        return result
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        sanitizeRawHTML(inlineHTML.rawHTML)
    }

    private func sanitizeRawHTML(_ rawHTML: String) -> String {
        let tags = Self.disallowedRawHTMLTags.joined(separator: "|")
        let pattern = "(?i)<\\s*/?\\s*(\(tags))\\b"
        guard let regex = try? Regex(pattern) else {
            return rawHTML
        }
        let matches = rawHTML.matches(of: regex)
        if matches.isEmpty {
            return rawHTML
        }

        let offsets = matches.map { match in
            rawHTML.distance(from: rawHTML.startIndex, to: match.range.lowerBound)
        }
        var result = rawHTML
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
}

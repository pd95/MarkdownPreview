import Foundation

struct WikiLinkRenderer {
    struct Result {
        let html: String
        let containsWikiLinks: Bool
    }

    static func render(_ text: String, escapedWikiLinkPlaceholder: String? = nil) -> Result {
        guard let escapedWikiLinkPlaceholder else {
            return renderUnescaped(text)
        }
        let protectedParts = text.components(separatedBy: escapedWikiLinkPlaceholder)
        if protectedParts.count > 1 {
            var combinedHTML = ""
            var containsWikiLinks = false
            for (index, part) in protectedParts.enumerated() {
                if index > 0 {
                    combinedHTML += "[["
                }
                let renderedPart = renderUnescaped(part)
                combinedHTML += renderedPart.html
                containsWikiLinks = containsWikiLinks || renderedPart.containsWikiLinks
            }
            return Result(html: combinedHTML, containsWikiLinks: containsWikiLinks)
        }
        return renderUnescaped(text)
    }

    private static func renderUnescaped(_ text: String) -> Result {
        var html = ""
        var searchStart = text.startIndex
        var foundWikiLink = false

        while let opener = text.range(of: "[[", range: searchStart..<text.endIndex) {
            html += String(text[searchStart..<opener.lowerBound]).encodedHTMLEntities()

            guard let closer = text.range(of: "]]", range: opener.upperBound..<text.endIndex) else {
                html += String(text[opener.lowerBound...]).encodedHTMLEntities()
                return Result(html: html, containsWikiLinks: foundWikiLink)
            }

            let rawContents = String(text[opener.upperBound..<closer.lowerBound])
            guard let link = parse(rawContents) else {
                html += String(text[opener.lowerBound..<closer.upperBound]).encodedHTMLEntities()
                searchStart = closer.upperBound
                continue
            }

            let destination = internalDestination(for: link.target).encodedHTMLAttribute()
            html += "<a href=\"\(destination)\" data-marklens-wikilink>\(link.label.encodedHTMLEntities())</a>"
            foundWikiLink = true
            searchStart = closer.upperBound
        }

        html += String(text[searchStart...]).encodedHTMLEntities()
        return Result(html: html, containsWikiLinks: foundWikiLink)
    }

    private static func parse(_ contents: String) -> (target: String, label: String)? {
        let pieces = contents.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let target = String(pieces[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.isEmpty == false,
              target.hasPrefix("/") == false,
              target.hasPrefix("~") == false,
              target.contains("#") == false,
              target.contains("^") == false else {
            return nil
        }

        let components = target.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ $0.isEmpty == false && $0 != "." && $0 != ".." }) else {
            return nil
        }

        let label: String
        if pieces.count == 2 {
            label = String(pieces[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.isEmpty == false else { return nil }
        } else {
            label = target
        }
        return (target, label)
    }

    private static func internalDestination(for target: String) -> String {
        var components = URLComponents()
        components.scheme = "marklens-wikilink"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "target", value: target)]
        return components.string ?? "#"
    }
}

enum WikiLinkEscapes {
    struct ProtectedMarkdown {
        let markdown: String
        let placeholder: String?
    }

    static func protect(in markdown: String) -> ProtectedMarkdown {
        guard containsEscapedOpener(markdown) else {
            return ProtectedMarkdown(markdown: markdown, placeholder: nil)
        }

        var placeholder = "\u{F0000}marklens-escaped-wikilink\u{F0001}"
        while markdown.contains(placeholder) {
            placeholder += "\u{F0002}"
        }

        var result = ""
        var index = markdown.startIndex
        while index < markdown.endIndex {
            if markdown[index] == "\\" {
                let runStart = index
                while index < markdown.endIndex, markdown[index] == "\\" {
                    index = markdown.index(after: index)
                }
                let count = markdown.distance(from: runStart, to: index)
                if count.isMultiple(of: 2) == false,
                   markdown[index...].hasPrefix("[[") {
                    result += String(repeating: "\\", count: count - 1)
                    result += placeholder
                    index = markdown.index(index, offsetBy: 2)
                } else {
                    result += String(markdown[runStart..<index])
                }
            } else {
                result.append(markdown[index])
                index = markdown.index(after: index)
            }
        }
        return ProtectedMarkdown(markdown: result, placeholder: placeholder)
    }

    static func restoreText(
        _ text: String,
        placeholder: String?,
        includeBackslash: Bool
    ) -> String {
        guard let placeholder else { return text }
        return text.replacingOccurrences(
            of: placeholder,
            with: includeBackslash ? "\\[[" : "[["
        )
    }

    private static func containsEscapedOpener(_ markdown: String) -> Bool {
        markdown.contains("\\[[")
    }
}

import Foundation

struct FrontMatter {
    let raw: String
    let values: [String: String]

    var title: String? {
        values["title"]
    }

    var theme: String? {
        values["theme"]
    }
}

struct FrontMatterExtractor {
    func extract(from markdown: String) -> (frontMatter: FrontMatter?, bodyMarkdown: String) {
        let lines = markdown.components(separatedBy: .newlines)
        guard lines.first == "---" else {
            return (nil, markdown)
        }

        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            return (nil, markdown)
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let bodyLines = Array(lines[(closingIndex + 1)...])
        let frontMatterRaw = frontMatterLines.joined(separator: "\n")
        let values = Self.parseFlatYAML(lines: frontMatterLines)
        let frontMatter = FrontMatter(raw: frontMatterRaw, values: values)
        let bodyMarkdown = bodyLines.joined(separator: "\n")
        return (frontMatter, bodyMarkdown)
    }

    private static func parseFlatYAML(lines: [String]) -> [String: String] {
        var values: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }
            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                continue
            }
            values[String(key)] = String(value)
        }
        return values
    }
}

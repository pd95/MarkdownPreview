struct MarkdownFenceNormalizer {
    func normalize(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            guard let opening = FenceLine.parseOpening(lines[index]),
                  opening.isMarkdownInfo else {
                index += 1
                continue
            }

            guard let closingIndex = closingIndex(for: opening, in: lines, startingAt: index + 1) else {
                index += 1
                continue
            }

            let maxNestedFenceLength = lines[(index + 1)..<closingIndex]
                .compactMap { FenceLine.parse($0) }
                .filter { $0.character == opening.character }
                .map(\.length)
                .max() ?? opening.length

            if maxNestedFenceLength >= opening.length {
                let replacementLength = maxNestedFenceLength + 1
                lines[index] = opening.replacingFence(length: replacementLength)

                if let closing = FenceLine.parseClosing(lines[closingIndex], character: opening.character, minimumLength: opening.length) {
                    lines[closingIndex] = closing.replacingFence(length: replacementLength)
                }
            }

            index = closingIndex + 1
        }

        return lines.joined(separator: "\n")
    }

    private func closingIndex(for opening: FenceLine, in lines: [String], startingAt startIndex: Int) -> Int? {
        var depth = 1
        var index = startIndex

        while index < lines.count {
            if let nestedOpening = FenceLine.parseOpening(lines[index]),
               nestedOpening.character == opening.character,
               nestedOpening.length >= opening.length {
                depth += 1
            } else if FenceLine.parseClosing(lines[index], character: opening.character, minimumLength: opening.length) != nil {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }

            index += 1
        }

        return nil
    }
}

private struct FenceLine {
    let indentation: String
    let character: Character
    let length: Int
    let suffix: String

    var isMarkdownInfo: Bool {
        let info = suffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return info == "markdown" || info == "md"
    }

    static func parseOpening(_ line: String) -> FenceLine? {
        guard let fence = parse(line), fence.length >= 3 else {
            return nil
        }

        let info = fence.suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard info.isEmpty == false else {
            return nil
        }

        if fence.character == "`", info.contains("`") {
            return nil
        }

        return fence
    }

    static func parseClosing(_ line: String, character: Character, minimumLength: Int) -> FenceLine? {
        guard let fence = parse(line),
              fence.character == character,
              fence.length >= minimumLength,
              fence.suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return fence
    }

    static func parse(_ line: String) -> FenceLine? {
        var index = line.startIndex
        var indentation = ""

        while index < line.endIndex, line[index] == " " {
            indentation.append(line[index])
            index = line.index(after: index)
        }

        guard indentation.count <= 3,
              index < line.endIndex,
              line[index] == "`" || line[index] == "~" else {
            return nil
        }

        let character = line[index]
        var length = 0

        while index < line.endIndex, line[index] == character {
            length += 1
            index = line.index(after: index)
        }

        guard length >= 3 else {
            return nil
        }

        return FenceLine(
            indentation: indentation,
            character: character,
            length: length,
            suffix: String(line[index...])
        )
    }

    func replacingFence(length: Int) -> String {
        indentation + String(repeating: String(character), count: length) + suffix
    }
}

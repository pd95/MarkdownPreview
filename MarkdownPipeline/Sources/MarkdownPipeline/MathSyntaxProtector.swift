import Foundation

struct ProtectedMath {
    struct Expression {
        let token: String
        let source: String
        let original: String
        let displayMode: Bool
    }

    let markdown: String
    let expressions: [String: Expression]
}

struct MathSyntaxProtector {
    private struct HTMLTagState {
        var isInsideTag = false
        var quote: Character?
    }

    func protect(in markdown: String) -> ProtectedMath {
        let prefix = "MARKLENSMATH\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var expressions: [String: ProtectedMath.Expression] = [:]
        var output: [String] = []
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        var fence: (character: Character, count: Int)?
        var htmlTagState = HTMLTagState()

        func token(source: String, original: String, displayMode: Bool) -> String {
            let value = "\(prefix)TOKEN\(expressions.count)END"
            expressions[value] = .init(
                token: value,
                source: source,
                original: original,
                displayMode: displayMode
            )
            return value
        }

        while index < lines.count {
            let line = lines[index]
            if let marker = fenceMarker(in: line) {
                if fence == nil, isMathFenceOpening(line, marker: marker),
                   let closingIndex = closingFenceIndex(
                    in: lines,
                    after: index,
                    marker: marker
                   ) {
                    let body = lines[(index + 1)..<closingIndex].joined(separator: "\n")
                    let original = lines[index...closingIndex].joined(separator: "\n")
                    output.append(token(source: body, original: original, displayMode: true))
                    index = closingIndex + 1
                    continue
                }
                if let current = fence {
                    if marker.character == current.character,
                       marker.count >= current.count,
                       isStrictClosingFence(line, marker: marker) {
                        fence = nil
                    }
                } else {
                    fence = marker
                }
                output.append(line)
                index += 1
                continue
            }
            if fence != nil {
                output.append(line)
                index += 1
                continue
            }

            if isIndentedCodeLine(line) {
                output.append(line)
                index += 1
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("$$") {
                let afterOpening = String(trimmed.dropFirst(2))
                if let closing = afterOpening.range(of: "$$"),
                   afterOpening[closing.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty {
                    let source = String(afterOpening[..<closing.lowerBound])
                    let original = "$$\(source)$$"
                    output.append(token(source: source, original: original, displayMode: true))
                    index += 1
                    continue
                }

                var body: [String] = []
                var closingIndex: Int?
                if afterOpening.isEmpty == false {
                    body.append(afterOpening)
                }
                var cursor = index + 1
                while cursor < lines.count {
                    let candidate = lines[cursor]
                    if candidate.trimmingCharacters(in: .whitespaces) == "$$" {
                        closingIndex = cursor
                        break
                    }
                    body.append(candidate)
                    cursor += 1
                }
                if let closingIndex {
                    let original = lines[index...closingIndex].joined(separator: "\n")
                    output.append(token(
                        source: body.joined(separator: "\n"),
                        original: original,
                        displayMode: true
                    ))
                    index = closingIndex + 1
                    continue
                }
            }

            output.append(protectInline(
                in: line,
                htmlTagState: &htmlTagState,
                makeToken: token
            ))
            index += 1
        }

        return ProtectedMath(markdown: output.joined(separator: "\n"), expressions: expressions)
    }

    private func fenceMarker(in line: String) -> (character: Character, count: Int)? {
        let indentation = line.prefix(while: { $0 == " " }).count
        guard indentation <= 3 else { return nil }
        let trimmed = line.dropFirst(indentation)
        guard trimmed.count >= 3, let first = trimmed.first, first == "`" || first == "~" else {
            return nil
        }
        let count = trimmed.prefix(while: { $0 == first }).count
        return count >= 3 ? (first, count) : nil
    }

    private func isIndentedCodeLine(_ line: String) -> Bool {
        line.first == "\t" || line.prefix(while: { $0 == " " }).count >= 4
    }

    private func isMathFenceOpening(
        _ line: String,
        marker: (character: Character, count: Int)
    ) -> Bool {
        let trimmed = line.drop(while: { $0 == " " })
        let info = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        return info.split(whereSeparator: { $0.isWhitespace }).first?
            .caseInsensitiveCompare("math") == .orderedSame
    }

    private func closingFenceIndex(
        in lines: [String],
        after openingIndex: Int,
        marker: (character: Character, count: Int)
    ) -> Int? {
        for index in (openingIndex + 1)..<lines.count {
            let trimmed = lines[index].drop(while: { $0 == " " })
            let count = trimmed.prefix(while: { $0 == marker.character }).count
            guard count >= marker.count else { continue }
            if isStrictClosingFence(lines[index], marker: (marker.character, count)) {
                return index
            }
        }
        return nil
    }

    private func isStrictClosingFence(
        _ line: String,
        marker: (character: Character, count: Int)
    ) -> Bool {
        let trimmed = line.drop(while: { $0 == " " })
        return trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func protectInline(
        in line: String,
        htmlTagState: inout HTMLTagState,
        makeToken: (String, String, Bool) -> String
    ) -> String {
        var result = ""
        var cursor = line.startIndex

        while cursor < line.endIndex {
            if htmlTagState.isInsideTag {
                let start = cursor
                while cursor < line.endIndex {
                    let character = line[cursor]
                    if let quote = htmlTagState.quote {
                        if character == quote, isEscaped(line, at: cursor) == false {
                            htmlTagState.quote = nil
                        }
                    } else if character == "\"" || character == "'" {
                        htmlTagState.quote = character
                    } else if character == ">" {
                        cursor = line.index(after: cursor)
                        htmlTagState.isInsideTag = false
                        break
                    }
                    cursor = line.index(after: cursor)
                }
                result += String(line[start..<cursor])
                continue
            }

            if isPlausibleAngleRegionStart(in: line, at: cursor) {
                htmlTagState.isInsideTag = true
                htmlTagState.quote = nil
                continue
            }

            if line[cursor] == "]" {
                let next = line.index(after: cursor)
                if next < line.endIndex, line[next] == "(",
                   let end = parenthesizedDestinationEnd(in: line, from: next) {
                    result += String(line[cursor..<end])
                    cursor = end
                    continue
                }
                if next < line.endIndex, line[next] == ":" {
                    result += String(line[cursor...])
                    break
                }
            }

            if line[cursor] == "`" {
                let count = line[cursor...].prefix(while: { $0 == "`" }).count
                let delimiter = String(repeating: "`", count: count)
                let contentStart = line.index(cursor, offsetBy: count)
                if let end = line.range(of: delimiter, range: contentStart..<line.endIndex) {
                    result += String(line[cursor..<end.upperBound])
                    cursor = end.upperBound
                    continue
                }
            }

            if line[cursor] == "$", isEscaped(line, at: cursor) == false {
                let next = line.index(after: cursor)
                if next < line.endIndex, line[next] == "$" {
                    result += "$$"
                    cursor = line.index(after: next)
                    continue
                }
                if next < line.endIndex, line[next] == "`",
                   let end = line.range(of: "`$", range: line.index(after: next)..<line.endIndex) {
                    let sourceStart = line.index(after: next)
                    let source = String(line[sourceStart..<end.lowerBound])
                    if source.isEmpty == false {
                        let original = String(line[cursor..<end.upperBound])
                        result += makeToken(source, original, false)
                        cursor = end.upperBound
                        continue
                    }
                } else if next < line.endIndex, line[next].isWhitespace == false,
                          let end = closingDollar(in: line, after: next) {
                    let source = String(line[next..<end])
                    let afterEnd = line.index(after: end)
                    let original = String(line[cursor..<afterEnd])
                    result += makeToken(source, original, false)
                    cursor = afterEnd
                    continue
                }
            }

            result.append(line[cursor])
            cursor = line.index(after: cursor)
        }
        return result
    }

    private func isPlausibleAngleRegionStart(in line: String, at index: String.Index) -> Bool {
        guard line[index] == "<" else { return false }
        let next = line.index(after: index)
        guard next < line.endIndex else { return false }
        let character = line[next]
        return character.isLetter || character == "/" || character == "!" || character == "?"
    }

    private func parenthesizedDestinationEnd(
        in line: String,
        from opening: String.Index
    ) -> String.Index? {
        var cursor = line.index(after: opening)
        var depth = 1
        var quote: Character?
        while cursor < line.endIndex {
            let character = line[cursor]
            if let currentQuote = quote {
                if character == currentQuote, isEscaped(line, at: cursor) == false {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(", isEscaped(line, at: cursor) == false {
                depth += 1
            } else if character == ")", isEscaped(line, at: cursor) == false {
                depth -= 1
                if depth == 0 {
                    return line.index(after: cursor)
                }
            }
            cursor = line.index(after: cursor)
        }
        return nil
    }

    private func closingDollar(in line: String, after start: String.Index) -> String.Index? {
        var cursor = start
        while cursor < line.endIndex {
            if line[cursor] == "$", isEscaped(line, at: cursor) == false {
                let before = line.index(before: cursor)
                if line[before].isWhitespace == false {
                    return cursor
                }
            }
            cursor = line.index(after: cursor)
        }
        return nil
    }

    private func isEscaped(_ text: String, at index: String.Index) -> Bool {
        var cursor = index
        var slashCount = 0
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard text[previous] == "\\" else { break }
            slashCount += 1
            cursor = previous
        }
        return slashCount % 2 == 1
    }
}

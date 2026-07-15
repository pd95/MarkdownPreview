import Foundation

struct KaTeXAssets: Sendable {
    let stylesheet: String
    let resources: [HTMLResource]

    static func load() throws -> KaTeXAssets {
        guard let cached else {
            throw MarkdownPipelineError.missingResource("KaTeX assets")
        }
        return cached
    }

    private static let cached = try? loadUncached()

    private static func loadUncached() throws -> KaTeXAssets {
        var stylesheet = try ResourceLoader.stringResource("katex.min.css")
        stylesheet = stylesheet.replacingOccurrences(
            of: #",url\(fonts/[^)]*\.(?:woff|ttf)\) format\("(?:woff|truetype)"\)"#,
            with: "",
            options: .regularExpression
        )
        let resources = try WebDependencyMetadata.kaTeXFontNames.map { name in
            let identifier = "katex/\(name)"
            stylesheet = stylesheet.replacingOccurrences(
                of: "fonts/\(name)",
                with: "marklens-resource://resource/\(identifier)"
            )
            return HTMLResource(
                identifier: identifier,
                contentType: "font/woff2",
                data: try ResourceLoader.dataResource(name)
            )
        }
        stylesheet += """

        .math-display { max-width: 100%; overflow-x: auto; overflow-y: hidden; }
        .math-inline { white-space: nowrap; }
        @media print { .math-display { overflow: visible; } }
        """
        return KaTeXAssets(stylesheet: stylesheet, resources: resources)
    }
}

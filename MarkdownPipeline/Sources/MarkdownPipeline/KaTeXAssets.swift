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
        let fontNames = [
            "KaTeX_AMS-Regular.woff2",
            "KaTeX_Caligraphic-Bold.woff2",
            "KaTeX_Caligraphic-Regular.woff2",
            "KaTeX_Fraktur-Bold.woff2",
            "KaTeX_Fraktur-Regular.woff2",
            "KaTeX_Main-Bold.woff2",
            "KaTeX_Main-BoldItalic.woff2",
            "KaTeX_Main-Italic.woff2",
            "KaTeX_Main-Regular.woff2",
            "KaTeX_Math-BoldItalic.woff2",
            "KaTeX_Math-Italic.woff2",
            "KaTeX_SansSerif-Bold.woff2",
            "KaTeX_SansSerif-Italic.woff2",
            "KaTeX_SansSerif-Regular.woff2",
            "KaTeX_Script-Regular.woff2",
            "KaTeX_Size1-Regular.woff2",
            "KaTeX_Size2-Regular.woff2",
            "KaTeX_Size3-Regular.woff2",
            "KaTeX_Size4-Regular.woff2",
            "KaTeX_Typewriter-Regular.woff2",
        ]

        var stylesheet = try ResourceLoader.stringResource("katex.min.css")
        stylesheet = stylesheet.replacingOccurrences(
            of: #",url\(fonts/[^)]*\.(?:woff|ttf)\) format\("(?:woff|truetype)"\)"#,
            with: "",
            options: .regularExpression
        )
        let resources = try fontNames.map { name in
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

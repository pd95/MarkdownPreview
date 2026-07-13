import Foundation

struct MermaidAssets: Sendable {
    let scripts: String
    let resources: [HTMLResource]

    static func load(theme: PipelineContext.Theme) throws -> MermaidAssets {
        guard let resource = cachedResource else {
            throw MarkdownPipelineError.missingResource("mermaid.min.js")
        }
        guard let rendererTemplate = cachedRenderer else {
            throw MarkdownPipelineError.missingResource("mermaid-renderer.js")
        }
        let renderer = rendererTemplate
            .replacingOccurrences(of: "{{MERMAID_THEME}}", with: theme.rawValue)
        let scripts = """
        <script src="\(resource.url.absoluteString)"></script>
        <script>\(renderer)</script>
        """
        return MermaidAssets(scripts: scripts, resources: [resource])
    }

    static func stylesheet() throws -> String {
        guard let cachedStylesheet else {
            throw MarkdownPipelineError.missingResource("mermaid-style.css")
        }
        return cachedStylesheet
    }

    private static let cachedResource = try? HTMLResource(
        identifier: "mermaid/mermaid.min.js",
        contentType: "application/javascript",
        data: ResourceLoader.dataResource("mermaid.min.js")
    )
    private static let cachedRenderer = try? ResourceLoader.stringResource("mermaid-renderer.js")
    private static let cachedStylesheet = try? ResourceLoader.stringResource("mermaid-style.css")
}

import Foundation

struct MermaidAssets: Sendable {
    let scripts: String
    let resources: [HTMLResource]

    static func load(theme: PipelineContext.Theme) throws -> MermaidAssets {
        let resource = HTMLResource(
            identifier: "mermaid/mermaid.min.js",
            contentType: "application/javascript",
            data: try ResourceLoader.dataResource("mermaid.min.js")
        )
        let renderer = try ResourceLoader.stringResource("mermaid-renderer.js")
            .replacingOccurrences(of: "{{MERMAID_THEME}}", with: theme.rawValue)
        let scripts = """
        <script src="\(resource.url.absoluteString)"></script>
        <script>\(renderer)</script>
        """
        return MermaidAssets(scripts: scripts, resources: [resource])
    }
}

import Foundation

struct HTMLEmitter {
    func render(bodyHTML: String, title: String?, theme: PipelineContext.Theme) throws -> String {
        var template = try ResourceLoader.stringResource("template.html")
        let markdownCSS = try ResourceLoader.stringResource("markdown-style.css")
        let themeCSS = try themeStylesheet(for: theme)
        let cssBlock = "<style>\n\(markdownCSS)\n\(themeCSS)\n</style>"

        template = template.replacingOccurrences(
            of: "<link rel=\"stylesheet\" href=\"markdown-style.css\" />",
            with: cssBlock
        )
        template = template.replacingOccurrences(
            of: "<link rel=\"stylesheet\" href=\"stackoverflow-dark.min.css\" media=\"(prefers-color-scheme: dark)\" />",
            with: ""
        )
        template = template.replacingOccurrences(
            of: "<link rel=\"stylesheet\" href=\"stackoverflow-light.min.css\" media=\"(prefers-color-scheme: light), (prefers-color-scheme: no-preference)\" />",
            with: ""
        )
        template = template.replacingOccurrences(of: "<script src=\"highlight.min.js\"></script>", with: "")
        template = template.replacingOccurrences(of: "<script>hljs.highlightAll()</script>", with: "")

        let resolvedTitle = title ?? "Markdown Preview"
        template = template
            .replacingOccurrences(of: "{{HTML}}", with: bodyHTML)
            .replacingOccurrences(of: "{{FILENAME}}", with: resolvedTitle)

        return template
    }

    private func themeStylesheet(for theme: PipelineContext.Theme) throws -> String {
        switch theme {
        case .light:
            return try ResourceLoader.stringResource("stackoverflow-light.min.css")
        case .dark:
            return try ResourceLoader.stringResource("stackoverflow-dark.min.css")
        case .auto:
            let dark = try ResourceLoader.stringResource("stackoverflow-dark.min.css")
            let light = try ResourceLoader.stringResource("stackoverflow-light.min.css")
            return "@media (prefers-color-scheme: dark) {\n\(dark)\n}\n" +
                "@media (prefers-color-scheme: light), (prefers-color-scheme: no-preference) {\n\(light)\n}"
        }
    }
}

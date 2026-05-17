import Foundation

struct HTMLEmitter {
    func render(bodyHTML: String, title: String?, theme: PipelineContext.Theme) throws -> String {
        var template = try ResourceLoader.stringResource("template.html")
        let markdownCSS = try ResourceLoader.stringResource("markdown-style.css")
        let themeCSS = try themeStylesheet(for: theme)
        let cssBlock = "<style>\n\(markdownCSS)\n\(themeCSS)\n</style>"

        template = template.replacingOccurrences(of: "{{STYLES}}", with: cssBlock)

        let resolvedTitle = (title ?? "MarkLens").encodedHTMLEntities()
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

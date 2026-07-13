import Foundation

struct HTMLEmitter {
    func render(
        bodyHTML: String,
        title: String?,
        additionalStyles: String = "",
        additionalScripts: String = ""
    ) throws -> String {
        var template = try ResourceLoader.stringResource("template.html")
        let markdownCSS = try ResourceLoader.stringResource("markdown-style.css")
        let cssBlock = "<style>\n\(markdownCSS)\n\(additionalStyles)\n</style>"

        template = template.replacingOccurrences(of: "{{STYLES}}", with: cssBlock)
        template = template.replacingOccurrences(of: "{{SCRIPTS}}", with: additionalScripts)

        let resolvedTitle = (title ?? "MarkLens").encodedHTMLEntities()
        template = template
            .replacingOccurrences(of: "{{HTML}}", with: bodyHTML)
            .replacingOccurrences(of: "{{FILENAME}}", with: resolvedTitle)

        return template
    }
}

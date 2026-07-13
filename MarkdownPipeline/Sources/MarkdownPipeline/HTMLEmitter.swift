import Foundation

struct HTMLEmitter {
    func render(
        bodyHTML: String,
        title: String?,
        additionalStyles: String = "",
        additionalScripts: String = "",
        overrideStyles: String? = nil
    ) throws -> String {
        var template = try ResourceLoader.stringResource("template.html")
        let markdownCSS = try ResourceLoader.stringResource("markdown-style.css")
        let cssBlock = "<style>\n\(markdownCSS)\n\(additionalStyles)\n</style>"

        let overrideBlock = overrideStyles.map {
            "<style id=\"\(HTMLFeature.customCSSStyleElementID)\">\n\(escapedStyleContent($0))\n</style>"
        } ?? ""

        template = template.replacingOccurrences(
            of: "{{STYLES}}",
            with: cssBlock + "\n" + overrideBlock
        )
        template = template.replacingOccurrences(of: "{{SCRIPTS}}", with: additionalScripts)

        let resolvedTitle = (title ?? "MarkLens").encodedHTMLEntities()
        template = template
            .replacingOccurrences(of: "{{HTML}}", with: bodyHTML)
            .replacingOccurrences(of: "{{FILENAME}}", with: resolvedTitle)

        return template
    }

    private func escapedStyleContent(_ css: String) -> String {
        css.replacingOccurrences(of: "<", with: "\\3C ")
    }
}

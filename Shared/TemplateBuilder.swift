//
//  TemplateBuilder.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import Foundation

nonisolated struct TemplateBuilder {

    let markdown: String

    init(_ data: Data) {
        markdown = String(data: data, encoding: .utf8) ?? ""
    }

    var html: String {
        let htmlContent = MarkdownParser(markdown: markdown, keepLineBreaks: true).text

        // Load HTML template from bundle
        let template = self.stringFromResource("template.html")
        let css = self.stringFromResource("markdown-style.css")
        //let script = self.stringFromResource("highlight.min.js")

        // Replace placeholders for content and optional inline script
        let html = template
            .replacingOccurrences(of: "{{MARKDOWN}}", with: htmlContent)
            .replacingOccurrences(of: "{{STYLE.CSS}}", with: css)
            //.replacingOccurrences(of: "{{SCRIPT.JS}}", with: script)

        return html
    }

    private func stringFromResource(_ resource: String) -> String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: nil),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Couldn't load \(resource) from bundle")
        }
        return content
    }

}

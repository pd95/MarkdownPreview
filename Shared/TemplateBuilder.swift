//
//  TemplateBuilder.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import Foundation

nonisolated struct TemplateBuilder {

    let markdown: String
    let quickLook: Bool

    init(_ data: Data, quickLook: Bool) {
        markdown = String(data: data, encoding: .utf8) ?? ""
        self.quickLook = quickLook
    }

    var html: String {
        let htmlContent = MarkdownParser(markdown: markdown, keepLineBreaks: true).text

        // Load HTML template from bundle
        var template = Bundle.main.stringResource(from: "template.html")
        if quickLook {
            // Load HTML template from bundle & prefix CSS und JS links with cid: and replace placeholder for content
            template = template
                .replacingOccurrences(of: "stylesheet\" href=\"", with: "stylesheet\" href=\"cid:")
                .replacingOccurrences(of: "<script src=\"", with: "<script src=\"cid:")
        }

        // Replace content placeholder for content
        let html = template
            .replacingOccurrences(of: "{{HTML}}", with: htmlContent)

        return html
    }
}

//
//  PreviewProvider.swift
//  QuickLookPreview
//
//  Created by Philipp on 02.01.2026.
//

#if os(macOS)
import QuickLookUI
#endif
import QuickLook

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: .defaultWindowSize) { (replyToUpdate : QLPreviewReply) in
            let data = try Data(contentsOf: request.fileURL)
            let html = TemplateBuilder(data, quickLook: true).html

            // Read bundled resources and create attachments
            let bundle = Bundle.main
            replyToUpdate.attachments = [
                "markdown-style.css": .init(data: bundle.dataResource(from: "markdown-style.css"), contentType: .css),
                "stackoverflow-light.min.css": .init(data: bundle.dataResource(from: "stackoverflow-light.min.css"), contentType: .css),
                "stackoverflow-dark.min.css": .init(data: bundle.dataResource(from: "stackoverflow-dark.min.css"), contentType: .css),
                "highlight.min.js": .init(data: bundle.dataResource(from: "highlight.min.js"), contentType: .javaScript)
            ]

            return html.data(using: .utf8)!
        }

        return reply
    }
}


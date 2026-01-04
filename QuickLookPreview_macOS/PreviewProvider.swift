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
import MarkdownPipeline

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: .defaultWindowSize) { [self] (replyToUpdate : QLPreviewReply) in
            let useMarkdownPipeline = true
            let render = try self.renderHTML(for: request.fileURL, usePipeline: useMarkdownPipeline)
            let html = render.html

            if render.usedFallback {
                let bundle = Bundle.main
                replyToUpdate.attachments = [
                    "markdown-style.css": .init(data: bundle.dataResource(from: "markdown-style.css"), contentType: .css),
                    "stackoverflow-light.min.css": .init(data: bundle.dataResource(from: "stackoverflow-light.min.css"), contentType: .css),
                    "stackoverflow-dark.min.css": .init(data: bundle.dataResource(from: "stackoverflow-dark.min.css"), contentType: .css),
                    "highlight.min.js": .init(data: bundle.dataResource(from: "highlight.min.js"), contentType: .javaScript)
                ]
            }

            return html.data(using: .utf8)!
        }

        return reply
    }

    private func renderHTML(for url: URL, usePipeline: Bool) throws -> (html: String, usedFallback: Bool) {
        let data = try Data(contentsOf: url)
        let fallback = TemplateBuilder(data, quickLook: true, filename: url.lastPathComponent).html

        guard usePipeline else {
            return (fallback, true)
        }

        let pipeline = MarkdownPipeline.defaultHTML()
        let context = PipelineContext(title: url.lastPathComponent)
        if let document = try? pipeline.renderHTML(from: .data(data), context: context) {
            return (document.html, false)
        }
        return (fallback, true)
    }
}

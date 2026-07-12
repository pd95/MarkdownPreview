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
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: .defaultWindowSize) { [self] reply in
            let document = try self.renderHTML(for: request.fileURL)
            var html = document.html
            var attachments: [String: QLPreviewReplyAttachment] = [:]
            for resource in document.resources {
                let identifier = resource.contentIdentifier
                html = html.replacingOccurrences(of: resource.url.absoluteString, with: "cid:\(identifier)")
                let contentType = UTType(mimeType: resource.contentType) ?? .data
                attachments[identifier] = QLPreviewReplyAttachment(
                    data: resource.data,
                    contentType: contentType
                )
            }
            reply.attachments = attachments
            return html.data(using: .utf8) ?? Data()
        }

        return reply
    }

    private func renderHTML(for url: URL) throws -> HTMLDocument {
        let pipeline = MarkdownPipeline.defaultHTML()
        let context = PipelineContext(title: url.lastPathComponent)
        return try pipeline.renderHTML(from: .file(url), context: context)
    }
}

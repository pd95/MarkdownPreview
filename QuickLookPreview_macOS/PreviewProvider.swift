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
        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: .defaultWindowSize) { [self] _ in
            let document = try self.renderHTML(for: request.fileURL)
            return document.html.data(using: .utf8) ?? Data()
        }

        return reply
    }

    private func renderHTML(for url: URL) throws -> HTMLDocument {
        let pipeline = MarkdownPipeline.defaultHTML()
        let context = PipelineContext(title: url.lastPathComponent)
        return try pipeline.renderHTML(from: .file(url), context: context)
    }
}

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
            let html = TemplateBuilder(data).html
            return html.data(using: .utf8)!
        }
                
        return reply
    }
}


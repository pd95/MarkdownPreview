//
//  ContentView.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import MarkdownPipeline

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var isPrintRequested = false
    private let useMarkdownPipeline = true

    var body: some View {
        MarkdownWebView(
            html: renderHTML(),
            printRequested: $isPrintRequested
        )
#if os(macOS)
        .toolbar {
            Button {
                isPrintRequested = true
            } label: {
                Label("Print", systemImage: "printer")
            }
            .keyboardShortcut("p")
        }
#endif
        .focusedSceneValue(\.printAction, PrintAction {
            isPrintRequested = true
        })
#if os(macOS)
        .focusedSceneValue(\.pageSetupAction, PageSetupAction {
            let printInfo = NSPrintInfo.shared
            let pageLayout = NSPageLayout()

            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                pageLayout.beginSheet(with: printInfo, modalFor: window, delegate: nil, didEnd: nil, contextInfo: nil)
            } else {
                pageLayout.runModal(with: printInfo)
            }
        })
#endif
    }

    private func renderHTML() -> String {
        if useMarkdownPipeline {
            let pipeline = MarkdownPipeline.defaultHTML()
            let context = PipelineContext(title: document.filename)
            if let document = try? pipeline.renderHTML(from: .data(document.data), context: context) {
                return document.html
            }
        }

        return TemplateBuilder(document.data, quickLook: false, filename: document.filename).html
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument()))
}

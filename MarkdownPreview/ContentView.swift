//
//  ContentView.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var isPrintRequested = false

    var body: some View {
        MarkdownWebView(
            html: TemplateBuilder(document.data, quickLook: false, filename: document.filename).html,
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
}

#Preview {
    ContentView(document: .constant(MarkdownDocument()))
}

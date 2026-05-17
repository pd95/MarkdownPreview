//
//  ContentView.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @State private var isPrintRequested = false
    @State private var isRawEditing = false
    @State private var showFind = false
    @State private var rawDraft = ""

    init(document: MarkdownDocument) {
        self.document = document
    }

    var body: some View {
        ZStack {
            MarkdownWebView(
                html: document.renderedHTML,
                printRequested: $isPrintRequested
            )
            .allowsHitTesting(!isRawEditing)
            .zIndex(0)

            if isRawEditing {
                RawEditorView(text: $rawDraft, showFind: $showFind)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .animation(.snappy, value: isRawEditing)
        .toolbar {
            if isRawEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        isRawEditing = false
                    }
                    .keyboardShortcut(.cancelAction)
                }

#if os(macOS)
                if #available(macOS 26.0, *) {
                    ToolbarSpacer()
                }
#endif

                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showFind) {
                        Label("Find", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("f")
                }

#if os(macOS)
                if #available(macOS 26.0, *) {
                    ToolbarSpacer()
                }
#endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update", systemImage: "checkmark") {
                        document.updateText(rawDraft)
                        isRawEditing = false
                    }
                    .keyboardShortcut("s")
                }
            } else {
#if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isPrintRequested = true
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .keyboardShortcut("p")
                }

                if #available(macOS 26.0, *) {
                    ToolbarSpacer()
                }
#endif
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        rawDraft = rawString()
                        isRawEditing = true
                    } label: {
                        Label("Raw", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("e")
                }
            }
        }
#if os(macOS)
        .focusedSceneValue(\.printAction, PrintAction {
            isPrintRequested = true
        })
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

    private func rawString() -> String {
        document.text
    }
}

#Preview {
    ContentView(document: MarkdownDocument())
}

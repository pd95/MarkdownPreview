//
//  ContentView.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import MarkdownPipeline

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @State private var isPrintRequested = false
    @State private var isRawEditing = false
    @State private var showFind = false
    @State private var rawDraft = ""
    @State private var renderedHTML = Self.renderFailureHTML

    init(document: MarkdownDocument) {
        self.document = document
        self._renderedHTML = State(initialValue: Self.renderHTML(for: document))
    }

    var body: some View {
        ZStack {
            MarkdownWebView(
                html: renderedHTML,
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
                        updateDocument(with: rawDraft)
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
        .onAppear {
            refreshRenderedHTML()
        }
        .onChange(of: document.text) { _ in
            refreshRenderedHTML()
        }
        .onChange(of: document.filename ?? "") { _ in
            refreshRenderedHTML()
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

    private func refreshRenderedHTML() {
        renderedHTML = Self.renderHTML(for: document)
    }

    private static func renderHTML(for document: MarkdownDocument) -> String {
        let pipeline = MarkdownPipeline.defaultHTML()
        let context = PipelineContext(title: document.filename)
        if let document = try? pipeline.renderHTML(from: .string(document.text), context: context) {
            return document.html
        }
        return Self.renderFailureHTML
    }

    private func rawString() -> String {
        document.text
    }

    private func updateDocument(with text: String) {
        if document.text != text {
            document.text = text
        }
    }

    private static let renderFailureHTML = "<!doctype html><html><body><pre>Unable to render document.</pre></body></html>"
}

#Preview {
    ContentView(document: MarkdownDocument())
}

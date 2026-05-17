//
//  ContentView.swift
//  MarkLens
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
    @State private var previewFindText = ""
    @State private var isPreviewFindPresented = false
    @State private var previewFindRequest = 0
    @State private var previewFindBackwards = false
    @State private var previewFindAnchorRequest = 0
    @State private var previewFindMatchCount = 0
    @State private var previewFindCurrentIndex = 0

    init(document: MarkdownDocument) {
        self.document = document
    }

    var body: some View {
        ZStack {
            MarkdownWebView(
                html: document.renderedHTML,
                printRequested: $isPrintRequested,
                findMatchCount: $previewFindMatchCount,
                findCurrentIndex: $previewFindCurrentIndex,
                findTerm: isRawEditing ? "" : previewFindText,
                findRequest: previewFindRequest,
                findBackwards: previewFindBackwards,
                findAnchorRequest: previewFindAnchorRequest
            )
            .allowsHitTesting(!isRawEditing)
            .zIndex(0)

            if isRawEditing {
                RawEditorView(text: $rawDraft, showFind: $showFind)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .accessibilityIdentifier("contentView")
#if os(macOS)
        .safeAreaInset(edge: .top, spacing: 0) {
            if isPreviewFindPresented && isRawEditing == false {
                PreviewFindBar(
                    text: $previewFindText,
                    statusText: findStatusText,
                    canNavigate: previewFindMatchCount > 0,
                    previous: findPrevious,
                    next: findNext,
                    close: closePreviewFind
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
#endif
        .animation(.snappy, value: isRawEditing)
        .animation(.snappy, value: isPreviewFindPresented)
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        beginPreviewFind()
                    } label: {
                        Label("Find", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("previewFindButton")
                    .keyboardShortcut("f")
                }

#if !os(macOS)
                if isPreviewFindPresented || previewFindText.isEmpty == false {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Text(findStatusText)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Button {
                            findPrevious()
                        } label: {
                            Label("Previous", systemImage: "chevron.up")
                        }
                        .accessibilityIdentifier("previewFindPreviousButton")
                        .disabled(previewFindMatchCount == 0)

                        Button {
                            findNext()
                        } label: {
                            Label("Next", systemImage: "chevron.down")
                        }
                        .accessibilityIdentifier("previewFindNextButton")
                        .disabled(previewFindMatchCount == 0)
                    }
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
        .previewSearchable(
            enabled: !isRawEditing,
            text: $previewFindText,
            isPresented: $isPreviewFindPresented,
            submit: findNext
        )
        .onChange(of: isPreviewFindPresented) { _ in
            if isPreviewFindPresented == false {
                previewFindText = ""
            }
        }
        .onChange(of: isRawEditing) { _ in
            if isRawEditing {
                isPreviewFindPresented = false
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

    private var findStatusText: String {
        guard previewFindText.isEmpty == false else {
            return ""
        }

        if previewFindMatchCount == 0 {
            return "No Results"
        }

        return "\(previewFindCurrentIndex) of \(previewFindMatchCount)"
    }

    private func findNext() {
        previewFindBackwards = false
        previewFindRequest += 1
    }

    private func findPrevious() {
        previewFindBackwards = true
        previewFindRequest += 1
    }

    private func beginPreviewFind() {
        previewFindAnchorRequest += 1
        isPreviewFindPresented = true
    }

    private func closePreviewFind() {
        isPreviewFindPresented = false
        previewFindText = ""
        previewFindMatchCount = 0
        previewFindCurrentIndex = 0
    }
}

private extension View {
    @ViewBuilder
    func previewSearchable(
        enabled: Bool,
        text: Binding<String>,
        isPresented: Binding<Bool>,
        submit: @escaping () -> Void
    ) -> some View {
#if os(macOS)
        self
            .onSubmit(of: .search, submit)
#else
        if enabled {
            self
                .searchable(
                    text: text,
                    isPresented: isPresented,
                    placement: .toolbar,
                    prompt: "Find"
                )
                .onSubmit(of: .search, submit)
        } else {
            self
        }
#endif
    }
}

#if os(macOS)
private struct PreviewFindBar: View {
    @Binding var text: String
    var statusText: String
    var canNavigate: Bool
    var previous: () -> Void
    var next: () -> Void
    var close: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            searchField

            Button(action: previous) {
                Label("Previous", systemImage: "chevron.left")
            }
            .accessibilityIdentifier("previewFindPreviousButton")
            .disabled(!canNavigate)

            Button(action: next) {
                Label("Next", systemImage: "chevron.right")
            }
            .accessibilityIdentifier("previewFindNextButton")
            .disabled(!canNavigate)

            Button("Done", action: close)
                .accessibilityIdentifier("previewFindDoneButton")
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            isFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .accessibilityIdentifier("previewFindField")
                .onSubmit(next)

            if statusText.isEmpty == false {
                Text(statusText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(minWidth: 74, alignment: .trailing)
            }

            if text.isEmpty == false {
                Button {
                    text = ""
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minWidth: 280, idealWidth: 460, maxWidth: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.quaternary)
        }
    }
}
#endif

#Preview {
    ContentView(document: MarkdownDocument())
}

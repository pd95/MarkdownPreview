//
//  RawEditorView.swift
//  MarkLens
//
//  Created by Philipp on 16.01.2026.
//
import SwiftUI

struct RawEditorView: View {
    @Binding var text: String
    @Binding var showFind: Bool

    @ViewBuilder
    var textEditor: some View {
        if #available(macOS 26.0, iOS 16.0, *) {
            TextEditor(text: $text)
                .findNavigator(isPresented: $showFind)
        } else {
            TextEditor(text: $text)
        }
    }

    var body: some View {
        textEditor
            .font(.system(.body, design: .monospaced))
#if os(iOS)
            .textInputAutocapitalization(.never)
#endif
            .disableAutocorrection(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Markdown source editor")
            .accessibilityTextContentType(.plain)
    }
}

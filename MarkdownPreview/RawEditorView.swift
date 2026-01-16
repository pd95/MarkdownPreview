//
//  RawEditorView.swift
//  MarkdownPreview
//
//  Created by Philipp on 16.01.2026.
//
import SwiftUI

struct RawEditorView: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
#if os(iOS)
            .textInputAutocapitalization(.never)
#endif
            .disableAutocorrection(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

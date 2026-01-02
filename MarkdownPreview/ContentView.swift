//
//  ContentView.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument

    var body: some View {
        MarkdownWebView(html: document.html)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument()))
}

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
        MarkdownWebView(html: TemplateBuilder(document.data, quickLook: false).html)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument()))
}

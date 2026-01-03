//
//  MarkdownPreviewApp.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI

@main
struct MarkdownPreviewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(.defaultWindowSize)
    }
}

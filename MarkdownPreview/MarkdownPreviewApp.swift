//
//  MarkdownPreviewApp.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct MarkdownPreviewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 900, height: defaultWindowHeight)
    }

    private var defaultWindowHeight: CGFloat {
        #if os(macOS)
        let height = NSScreen.main?.visibleFrame.height
        #else
        let height: CGFloat? = UIScreen.main.bounds.height
        #endif
        let scaled = height.map { $0 * 0.8 } ?? 800
        return max(scaled, 800)
    }
}

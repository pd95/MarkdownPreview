//
//  MarkLensApp.swift
//  MarkLens
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI

@main
struct MarkLensApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    @FocusedValue(\.printAction) private var printAction
    @FocusedValue(\.pageSetupAction) private var pageSetupAction

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document)
#if os(macOS)
                .onAppear {
                    // Make sure the app stops after the last window has been closed
                    appDelegate.exitAfterLastWindow = true
                }
#endif
        }
        .defaultSize(.defaultWindowSize)
#if os(macOS)
        .commands {
            CommandGroup(replacing: .printItem) {
                Button("Print…") {
                    printAction?.run()
                }
                .keyboardShortcut("p")
                .disabled(printAction == nil)
            }
            CommandGroup(before: .printItem) {
                Button("Page Setup…") {
                    pageSetupAction?.run()
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
                .disabled(pageSetupAction == nil)
            }
        }
#endif
    }
}

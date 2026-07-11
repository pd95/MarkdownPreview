//
//  MarkLensApp.swift
//  MarkLens
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct MarkLensApp: App {
    @StateObject private var localDocumentAccess = LocalDocumentAccess()
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    @FocusedValue(\.printAction) private var printAction
    @FocusedValue(\.pageSetupAction) private var pageSetupAction

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .environmentObject(localDocumentAccess)
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
            CommandGroup(replacing: .appInfo) {
                Button("About MarkLens") {
                    showAboutPanel()
                }
            }
        }
#endif
#if os(macOS)
        Settings {
            FolderAccessSettingsView()
                .environmentObject(localDocumentAccess)
        }
#endif
    }

#if os(macOS)
    private func showAboutPanel() {
        let credits = NSAttributedString(
            string: BuildInfo.releaseDescription,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "MarkLens",
            .applicationVersion: BuildInfo.displayVersion,
            .credits: credits,
        ])
    }
#endif
}

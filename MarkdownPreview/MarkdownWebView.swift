import SwiftUI
import WebKit

#if os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformView = NSView
#else
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformView = UIView
#endif

struct MarkdownWebView: PlatformViewRepresentable {

    var html: String
    @Binding var printRequested: Bool
    private var baseURL: URL? { Bundle.main.resourceURL }

    init(html: String, printRequested: Binding<Bool> = .constant(false)) {
        self.html = html
        self._printRequested = printRequested
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
#if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
#endif
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

#if DEBUG && os(macOS)
        webView.isInspectable = true    // Enable debugging using Safari!
#endif
        webView.loadHTMLString(html, baseURL: baseURL)

        return webView
    }

    func updateView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self

        // Update state only if view is presented
        if context.environment.isPresented {
            context.coordinator.updateState()
        }
    }

    static func dismantleView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
#if DEBUG && os(macOS)
        view.isInspectable = false
#endif
        view.navigationDelegate = nil
        view.uiDelegate = nil
        coordinator.webView = nil
    }

#if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        updateView(view, context: context)
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        dismantleView(view, coordinator: coordinator)
    }

#else
    func makeUIView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        updateView(view, context: context)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        dismantleView(view, coordinator: coordinator)
    }


#endif

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView

        weak var webView: WKWebView?

        var isPageReady = false
        var latestHash: Int = 0
        var pendingPrintRequest = false

        init(parent: MarkdownWebView) {
            self.parent = parent
            super.init()
        }

        func updateState() {
            let newHash = parent.html.hashValue
            let markdownChanged = newHash != latestHash
            let needsUpdate = markdownChanged

            if isPageReady && needsUpdate {
                webView?.loadHTMLString(parent.html, baseURL: parent.baseURL)
                latestHash = newHash
            }

            handlePrintRequest()
        }

        func handlePrintRequest() {
            guard parent.printRequested else { return }

            if isPageReady {
                Task { @MainActor in
                    parent.printRequested = false

                    // Give WebKit a moment to finish layout before printing.
                    try? await Task.sleep(for: .milliseconds(50))

                    printCurrentDocument()
                }
            } else {
                pendingPrintRequest = true
            }
        }

        func printCurrentDocument() {
            guard let webView else { return }

#if os(macOS)
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic

            let cmToPrint: Double = 72/2.54
            //printInfo.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = true
            //printInfo.isHorizontallyCentered = false
            //printInfo.isVerticallyCentered = false
            printInfo.leftMargin = 1.0 * cmToPrint
            printInfo.rightMargin = 1.0 * cmToPrint
            printInfo.topMargin = 1.0 * cmToPrint
            printInfo.bottomMargin = 1.0 * cmToPrint

            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.view?.frame = webView.bounds

            if let window = webView.window {
                printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
            } else {
                printOperation.run()
            }
#else
            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo.printInfo()
            printInfo.jobName = "Markdown Preview"
            printController.printInfo = printInfo
            printController.printFormatter = webView.viewPrintFormatter()

            if UIDevice.current.userInterfaceIdiom == .pad {
                printController.present(from: webView.bounds, in: webView, animated: true, completionHandler: nil)
            } else {
                printController.present(animated: true, completionHandler: nil)
            }
#endif
        }

        private func openExternalURL(_ url: URL) {
#if os(macOS)
            NSWorkspace.shared.open(url)
#else
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
        }

        private func urlWithoutFragment(_ url: URL) -> URL? {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            return components?.url
        }

        private func isSameDocumentAnchor(_ url: URL, in webView: WKWebView) -> Bool {
            guard url.fragment != nil, let currentURL = webView.url else { return false }
            return urlWithoutFragment(url) == urlWithoutFragment(currentURL)
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if isSameDocumentAnchor(url, in: webView) {
                decisionHandler(.allow)
                return
            }

            openExternalURL(url)
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true

            if pendingPrintRequest || parent.printRequested {
                pendingPrintRequest = false
                printCurrentDocument()
            }
        }
    }
}

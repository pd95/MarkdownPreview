import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformView = NSView
#else
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformView = UIView
#endif

struct MarkdownWebView: PlatformViewRepresentable {

    var html: String

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
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self

        // Update state only if view is presented
        if context.environment.isPresented {
            context.coordinator.updateState()
        }
    }

#if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        updateView(view, context: context)
    }

#else
    func makeUIView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        updateView(view, context: context)
    }

#endif

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView

        weak var webView: WKWebView?

        var isPageReady = false
        var latestHash: Int = 0

        init(parent: MarkdownWebView) {
            self.parent = parent
            super.init()
        }

        func updateState() {
            let newHash = parent.html.hashValue
            let markdownChanged = newHash != latestHash
            let needsUpdate = markdownChanged

            if isPageReady && needsUpdate {
                webView?.loadHTMLString(parent.html, baseURL: nil)
                latestHash = newHash
            }
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
        }
    }
}

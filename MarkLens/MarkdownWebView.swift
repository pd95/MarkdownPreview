import SwiftUI
import WebKit
import MarkdownPipeline

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
    var resources: [HTMLResource]
    var documentURL: URL?
    var openDocument: (URL) async throws -> Void
    var openWikiLink: (String) -> Void
    var requestLocalDocumentAccess: (URL, String) -> Void
    var localImagePermissionDenied: (URL) -> Void
    var reloadRequest: Int
    @Binding var printRequested: Bool
    @Binding var findMatchCount: Int
    @Binding var findCurrentIndex: Int
    var findTerm: String
    var findRequest: Int
    var findBackwards: Bool
    var findAnchorRequest: Int
    private var baseURL: URL? {
        documentURL
    }

    init(
        html: String,
        resources: [HTMLResource] = [],
        documentURL: URL? = nil,
        openDocument: @escaping (URL) async throws -> Void = { _ in },
        openWikiLink: @escaping (String) -> Void = { _ in },
        requestLocalDocumentAccess: @escaping (URL, String) -> Void = { _, _ in },
        localImagePermissionDenied: @escaping (URL) -> Void = { _ in },
        reloadRequest: Int = 0,
        printRequested: Binding<Bool> = .constant(false),
        findMatchCount: Binding<Int> = .constant(0),
        findCurrentIndex: Binding<Int> = .constant(0),
        findTerm: String = "",
        findRequest: Int = 0,
        findBackwards: Bool = false,
        findAnchorRequest: Int = 0
    ) {
        self.html = html
        self.resources = resources
        self.documentURL = documentURL
        self.openDocument = openDocument
        self.openWikiLink = openWikiLink
        self.requestLocalDocumentAccess = requestLocalDocumentAccess
        self.localImagePermissionDenied = localImagePermissionDenied
        self.reloadRequest = reloadRequest
        self._printRequested = printRequested
        self._findMatchCount = findMatchCount
        self._findCurrentIndex = findCurrentIndex
        self.findTerm = findTerm
        self.findRequest = findRequest
        self.findBackwards = findBackwards
        self.findAnchorRequest = findAnchorRequest
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let resourceHandler = HTMLResourceSchemeHandler()
        resourceHandler.update(resources: resources)
        config.setURLSchemeHandler(resourceHandler, forURLScheme: Self.resourceScheme)
        context.coordinator.resourceHandler = resourceHandler
#if os(macOS)
        let localImageHandler = LocalImageSchemeHandler()
        localImageHandler.documentURL = documentURL
        localImageHandler.allowedImageURLs = localImageURLs
        localImageHandler.permissionDenied = { [weak coordinator = context.coordinator] url in
            coordinator?.localImagePermissionDenied(url)
        }
        config.setURLSchemeHandler(localImageHandler, forURLScheme: Self.localImageScheme)
        config.userContentController.addUserScript(WKUserScript(
            source: Self.localImageScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        context.coordinator.localImageHandler = localImageHandler
#endif
        let webView = WKWebView(frame: .zero, configuration: config)
#if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        webView.setAccessibilityIdentifier("previewWebView")
#else
        webView.accessibilityIdentifier = "previewWebView"
#endif
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.latestHash = contentHash

#if DEBUG && os(macOS)
        webView.isInspectable = true
#endif
        webView.loadHTMLString(html, baseURL: baseURL)

        return webView
    }

    func updateView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self

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
        coordinator.searchGeneration += 1
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

    private var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(html)
        for resource in resources {
            hasher.combine(resource.identifier)
            hasher.combine(resource.contentType)
            hasher.combine(resource.revision)
        }
        hasher.combine(documentURL)
        hasher.combine(reloadRequest)
        return hasher.finalize()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        weak var webView: WKWebView?
        var resourceHandler: HTMLResourceSchemeHandler?
#if os(macOS)
        weak var localImageHandler: LocalImageSchemeHandler?
#endif

        var isPageReady = false
        var latestHash = 0
        var latestFindTerm = ""
        var latestFindRequest = 0
        var latestFindAnchorRequest = 0
        var isSearchInstalled = false
        var searchGeneration = 0
        var pendingPrintRequest = false

        init(parent: MarkdownWebView) {
            self.parent = parent
            super.init()
        }

        func updateState() {
#if os(macOS)
            localImageHandler?.documentURL = parent.documentURL
            localImageHandler?.allowedImageURLs = parent.localImageURLs
#endif
            resourceHandler?.update(resources: parent.resources)
            let newHash = parent.contentHash
            let markdownChanged = newHash != latestHash
            let findTermChanged = parent.findTerm != latestFindTerm
            let findChanged = findTermChanged || parent.findRequest != latestFindRequest
            let findAnchorChanged = parent.findAnchorRequest != latestFindAnchorRequest

            if isPageReady && markdownChanged {
                isPageReady = false
                isSearchInstalled = false
                searchGeneration += 1
                webView?.loadHTMLString(parent.html, baseURL: parent.baseURL)
                latestHash = newHash
            } else if isPageReady && findAnchorChanged {
                updateSearch(command: "anchor")
                latestFindAnchorRequest = parent.findAnchorRequest
            } else if isPageReady && findChanged {
                updateSearch(command: findTermChanged ? "search" : searchCommand())
                latestFindTerm = parent.findTerm
                latestFindRequest = parent.findRequest
            }

            handlePrintRequest()
        }

        func localImagePermissionDenied(_ url: URL) {
            Task { @MainActor in
                parent.localImagePermissionDenied(url)
            }
        }

        private func searchCommand() -> String {
            parent.findBackwards ? "previous" : "next"
        }

        private func updateSearch(command: String) {
            guard let webView else { return }
            searchGeneration += 1
            let generation = searchGeneration

            installSearchIfNeeded(generation: generation) {
                self.runSearchCommand(command, generation: generation, in: webView)
            }
        }

        private func installSearchIfNeeded(generation: Int, completion: @escaping () -> Void) {
            guard let webView else { return }

            if isSearchInstalled {
                completion()
                return
            }

            webView.evaluateJavaScript(Self.searchScript) { [weak self] _, _ in
                guard let self, generation == self.searchGeneration else { return }

                self.isSearchInstalled = true
                completion()
            }
        }

        private func runSearchCommand(_ command: String, generation: Int, in webView: WKWebView) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: [
                "command": command,
                "term": parent.findTerm
            ]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }

            webView.evaluateJavaScript("window.MarkLensSearch.run(\(jsonString));") { [weak self] result, _ in
                guard let self, generation == self.searchGeneration else { return }

                let dictionary = result as? [String: Any]
                let count = Self.intValue(dictionary?["count"])
                let index = Self.intValue(dictionary?["index"])

                Task { @MainActor in
                    self.parent.findMatchCount = count
                    self.parent.findCurrentIndex = index
                }
            }
        }

        private static func intValue(_ value: Any?) -> Int {
            if let int = value as? Int {
                return int
            }
            if let number = value as? NSNumber {
                return number.intValue
            }
            return 0
        }

        private static let searchScript: String = {
            guard let url = Bundle.main.url(forResource: "WebResources/preview-search", withExtension: "js"),
                  let script = try? String(contentsOf: url, encoding: .utf8) else {
                assertionFailure("Missing preview-search.js resource")
                return "window.MarkLensSearch = { run() { return { count: 0, index: 0 }; }, clear() { return { count: 0, index: 0 }; } };"
            }

            return script
        }()

        func handlePrintRequest() {
            guard parent.printRequested else { return }

            if isPageReady {
                Task { @MainActor in
                    parent.printRequested = false

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
            printInfo.jobName = "MarkLens"
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

            if url.scheme?.caseInsensitiveCompare("marklens-wikilink") == .orderedSame {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   components.host == "open",
                   let target = components.queryItems?.first(where: { $0.name == "target" })?.value,
                   target.isEmpty == false {
                    parent.openWikiLink(target)
                }
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL {
#if os(macOS)
                guard let documentURL = urlWithoutFragment(url) else {
                    decisionHandler(.cancel)
                    return
                }
                Task { @MainActor in
                    do {
                        try await parent.openDocument(documentURL)
                    } catch {
                        parent.requestLocalDocumentAccess(documentURL, error.localizedDescription)
                    }
                }
#else
                openExternalURL(url)
#endif
            } else {
                openExternalURL(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            isSearchInstalled = false
            updateSearch(command: "search")
            latestFindTerm = parent.findTerm
            latestFindRequest = parent.findRequest

            if pendingPrintRequest || parent.printRequested {
                pendingPrintRequest = false
                printCurrentDocument()
            }
        }
    }

    private static let localImageScheme = "marklens-local-image"
    private static let resourceScheme = "marklens-resource"

    private var localImageURLs: Set<URL> {
        guard let documentURL,
              let regex = try? NSRegularExpression(
                  pattern: "data-marklens-local-image=\\\"([^\\\"]+)\\\""
              ) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return Set(regex.matches(in: html, range: range).compactMap { match in
            guard let capabilityRange = Range(match.range(at: 1), in: html),
                  let data = Data(base64Encoded: String(html[capabilityRange])),
                  let source = String(data: data, encoding: .utf8),
                  let url = URL(string: source, relativeTo: documentURL)?.absoluteURL,
                  url.isFileURL else {
                return nil
            }
            return url.standardizedFileURL.resolvingSymlinksInPath()
        })
    }

    private static let localImageScript = """
        document.querySelectorAll('img[data-marklens-local-image]').forEach(image => {
            const source = image.getAttribute('src');
            if (!source) return;
            const resolved = new URL(source, document.baseURI);
            if (resolved.protocol !== 'file:') return;
            image.src = '\(localImageScheme)://resource?url=' + encodeURIComponent(resolved.href);
        });
        """
}

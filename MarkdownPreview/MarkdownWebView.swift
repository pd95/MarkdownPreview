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
    @Binding var findMatchCount: Int
    @Binding var findCurrentIndex: Int
    var findTerm: String
    var findRequest: Int
    var findBackwards: Bool
    var findAnchorRequest: Int
    private var baseURL: URL? { Bundle.main.resourceURL }

    init(
        html: String,
        printRequested: Binding<Bool> = .constant(false),
        findMatchCount: Binding<Int> = .constant(0),
        findCurrentIndex: Binding<Int> = .constant(0),
        findTerm: String = "",
        findRequest: Int = 0,
        findBackwards: Bool = false,
        findAnchorRequest: Int = 0
    ) {
        self.html = html
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
        let webView = WKWebView(frame: .zero, configuration: config)
#if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
#endif
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.latestHash = html.hashValue

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

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        weak var webView: WKWebView?

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
            let newHash = parent.html.hashValue
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

            webView.evaluateJavaScript("window.MarkdownPreviewSearch.run(\(jsonString));") { [weak self] result, _ in
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

        private static let searchScript = #"""
        (() => {
            if (window.MarkdownPreviewSearch) {
                return;
            }

            const state = {
                term: "",
                hits: [],
                currentIndex: -1,
                activeStart: null,
                lastSelectionStart: null
            };

            function rootElement() {
                return document.getElementById("container") || document.body;
            }

            function folded(value) {
                return (value || "").normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
            }

            function buildFoldedMap(original) {
                const foldedChars = [];
                const foldedToCharIndex = [];
                const originalCharStarts = [];
                const originalCharLengths = [];
                let codeUnitIndex = 0;
                let charIndex = 0;

                for (const ch of original) {
                    originalCharStarts.push(codeUnitIndex);
                    originalCharLengths.push(ch.length);

                    const normalized = folded(ch);
                    for (let index = 0; index < normalized.length; index += 1) {
                        foldedChars.push(normalized[index]);
                        foldedToCharIndex.push(charIndex);
                    }

                    codeUnitIndex += ch.length;
                    charIndex += 1;
                }

                return {
                    folded: foldedChars.join(""),
                    foldedToCharIndex,
                    originalCharStarts,
                    originalCharLengths
                };
            }

            function shouldSkipTextNode(node) {
                let element = node.parentElement;
                while (element) {
                    const tagName = element.tagName;
                    if (tagName === "SCRIPT" || tagName === "STYLE" || tagName === "TEXTAREA") {
                        return true;
                    }
                    if (
                        element.classList.contains("copy-btn") ||
                        element.classList.contains("sr-only") ||
                        element.classList.contains("search-hit")
                    ) {
                        return true;
                    }
                    element = element.parentElement;
                }
                return false;
            }

            function documentOffsetForTextNodePosition(targetNode, targetOffset) {
                const root = rootElement();
                const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
                let absoluteOffset = 0;
                let node;

                while ((node = walker.nextNode())) {
                    const text = node.nodeValue || "";
                    if (node === targetNode) {
                        return absoluteOffset + Math.min(targetOffset, text.length);
                    }
                    absoluteOffset += text.length;
                }

                return null;
            }

            function documentOffsetForRangeStart(range) {
                const root = rootElement();
                const start = range.startContainer;
                if (!root.contains(start)) {
                    return null;
                }

                try {
                    const prefix = document.createRange();
                    prefix.selectNodeContents(root);
                    prefix.setEnd(start, range.startOffset);
                    return prefix.toString().length;
                } catch (_) {
                    return documentOffsetForTextNodePosition(start, range.startOffset);
                }
            }

            function selectedDocumentOffset() {
                const selection = window.getSelection();
                if (!selection || selection.rangeCount === 0) {
                    return null;
                }

                const range = selection.getRangeAt(0);
                if (range.collapsed) {
                    return null;
                }

                const root = rootElement();
                if (!root.contains(range.startContainer)) {
                    return null;
                }

                return documentOffsetForRangeStart(range);
            }

            function captureSelectionAnchor() {
                const offset = selectedDocumentOffset();
                if (offset != null) {
                    state.lastSelectionStart = offset;
                }
                return offset;
            }

            function clearDocumentSelection() {
                const selection = window.getSelection();
                if (selection) {
                    selection.removeAllRanges();
                }
            }

            function consumeSelectionAnchor() {
                const offset = captureSelectionAnchor();
                if (offset != null) {
                    state.lastSelectionStart = null;
                    clearDocumentSelection();
                    return offset;
                }

                if (state.lastSelectionStart != null) {
                    const cachedOffset = state.lastSelectionStart;
                    state.lastSelectionStart = null;
                    return cachedOffset;
                }

                return null;
            }

            function clearHighlights() {
                document.querySelectorAll(".search-hit").forEach(span => {
                    const parent = span.parentNode;
                    parent.replaceChild(document.createTextNode(span.textContent), span);
                    parent.normalize();
                });
                state.hits = [];
                state.currentIndex = -1;
            }

            function result() {
                return {
                    count: state.hits.length,
                    index: state.currentIndex >= 0 ? state.currentIndex + 1 : 0
                };
            }

            function isInViewport(element) {
                const rect = element.getBoundingClientRect();
                return rect.top >= 0
                    && rect.left >= 0
                    && rect.bottom <= window.innerHeight
                    && rect.right <= window.innerWidth;
            }

            function selectHit(index, shouldScroll = true, scrollBlock = "nearest") {
                if (index < 0 || index >= state.hits.length) {
                    state.currentIndex = -1;
                    state.activeStart = null;
                    return result();
                }

                state.currentIndex = index;
                state.hits.forEach((hit, hitIndex) => {
                    hit.classList.toggle("search-hit-active", hitIndex === index);
                });

                const hit = state.hits[index];
                state.activeStart = Number(hit.dataset.searchStart);

                if (shouldScroll && !isInViewport(hit)) {
                    hit.scrollIntoView({
                        behavior: "smooth",
                        block: scrollBlock,
                        inline: "nearest"
                    });
                }

                return result();
            }

            function selectHitAtOrAfter(offset) {
                const nextIndex = state.hits.findIndex(hit => Number(hit.dataset.searchStart) >= offset);
                return selectHit(nextIndex >= 0 ? nextIndex : 0, true);
            }

            function selectHitAtOrBefore(offset) {
                let previousIndex = -1;
                for (let index = state.hits.length - 1; index >= 0; index -= 1) {
                    if (Number(state.hits[index].dataset.searchStart) <= offset) {
                        previousIndex = index;
                        break;
                    }
                }

                return selectHit(previousIndex >= 0 ? previousIndex : state.hits.length - 1, true);
            }

            function rebuild(term, preferredStart) {
                clearHighlights();
                state.term = term || "";

                if (!state.term) {
                    state.activeStart = null;
                    return result();
                }

                const foldedTerm = folded(state.term);
                if (!foldedTerm) {
                    state.activeStart = null;
                    return result();
                }

                const escaped = foldedTerm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
                const regex = new RegExp(escaped, "g");
                const root = rootElement();
                const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
                const textNodesToProcess = [];
                let absoluteOffset = 0;
                let node;

                while ((node = walker.nextNode())) {
                    const text = node.nodeValue || "";
                    const nodeStart = absoluteOffset;
                    absoluteOffset += text.length;

                    if (shouldSkipTextNode(node) || !text.trim()) {
                        continue;
                    }

                    const map = buildFoldedMap(text);
                    regex.lastIndex = 0;

                    if (regex.test(map.folded)) {
                        textNodesToProcess.push({ node, map, nodeStart });
                    }
                }

                for (const entry of textNodesToProcess) {
                    const node = entry.node;
                    const text = node.nodeValue;
                    const {
                        folded,
                        foldedToCharIndex,
                        originalCharStarts,
                        originalCharLengths
                    } = entry.map;
                    const fragments = [];
                    let lastOriginalCU = 0;
                    let match;

                    regex.lastIndex = 0;
                    while ((match = regex.exec(folded))) {
                        const foldedStart = match.index;
                        const foldedEnd = foldedStart + match[0].length;
                        const firstCharIndex = foldedToCharIndex[foldedStart];
                        const lastCharIndex = foldedToCharIndex[foldedEnd - 1];
                        const originalStartCU = originalCharStarts[firstCharIndex];
                        const originalEndCU = originalCharStarts[lastCharIndex] + originalCharLengths[lastCharIndex];

                        if (originalStartCU > lastOriginalCU) {
                            fragments.push(document.createTextNode(text.slice(lastOriginalCU, originalStartCU)));
                        }

                        const span = document.createElement("span");
                        span.className = "search-hit";
                        span.dataset.searchStart = String(entry.nodeStart + originalStartCU);
                        span.textContent = text.slice(originalStartCU, originalEndCU);

                        fragments.push(span);
                        state.hits.push(span);

                        lastOriginalCU = originalEndCU;
                        if (match[0].length === 0) {
                            regex.lastIndex += 1;
                        }
                    }

                    if (lastOriginalCU < text.length) {
                        fragments.push(document.createTextNode(text.slice(lastOriginalCU)));
                    }

                    const parent = node.parentNode;
                    fragments.forEach(fragment => parent.insertBefore(fragment, node));
                    parent.removeChild(node);
                }

                if (state.hits.length === 0) {
                    state.activeStart = null;
                    return result();
                }

                let selectedIndex = 0;
                if (preferredStart != null) {
                    const exactIndex = state.hits.findIndex(hit => Number(hit.dataset.searchStart) === preferredStart);
                    if (exactIndex >= 0) {
                        selectedIndex = exactIndex;
                    } else {
                        const nextIndex = state.hits.findIndex(hit => Number(hit.dataset.searchStart) > preferredStart);
                        selectedIndex = nextIndex >= 0 ? nextIndex : 0;
                    }
                }

                return selectHit(selectedIndex, true, "nearest");
            }

            document.addEventListener("selectionchange", () => {
                captureSelectionAnchor();
            });

            window.MarkdownPreviewSearch = {
                run(payload) {
                    payload = payload || {};
                    const command = payload.command || "search";
                    const term = payload.term || "";

                    if (command === "anchor") {
                        const offset = captureSelectionAnchor();
                        if (offset != null) {
                            state.activeStart = offset;
                        }
                        return result();
                    }

                    if (command === "search") {
                        const offset = consumeSelectionAnchor();
                        return rebuild(term, offset ?? state.activeStart);
                    }

                    if (term !== state.term) {
                        const offset = consumeSelectionAnchor();
                        return rebuild(term, offset ?? state.activeStart);
                    }

                    if (state.hits.length === 0) {
                        return result();
                    }

                    const offset = consumeSelectionAnchor();
                    if (offset != null) {
                        return command === "previous"
                            ? selectHitAtOrBefore(offset)
                            : selectHitAtOrAfter(offset);
                    }

                    if (command === "previous") {
                        const previousIndex = state.currentIndex <= 0 ? state.hits.length - 1 : state.currentIndex - 1;
                        return selectHit(previousIndex, true);
                    }

                    const nextIndex = state.currentIndex < 0
                        ? 0
                        : (state.currentIndex + 1) % state.hits.length;
                    return selectHit(nextIndex, true);
                },
                clear() {
                    clearHighlights();
                    state.term = "";
                    state.activeStart = null;
                    state.lastSelectionStart = null;
                    return result();
                }
            };
        })();
        """#

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
}

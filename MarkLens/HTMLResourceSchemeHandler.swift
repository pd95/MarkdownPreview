import Foundation
import MarkdownPipeline
import WebKit

final class HTMLResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    private let lock = NSLock()
    private var resources: [URL: HTMLResource] = [:]

    func update(resources: [HTMLResource]) {
        let updated = Dictionary(resources.map { ($0.url, $0) }, uniquingKeysWith: { _, latest in latest })
        lock.withLock {
            self.resources = updated
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let resource = lock.withLock { resources[url] }
        guard let resource else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(
            url: url,
            mimeType: resource.contentType,
            expectedContentLength: resource.data.count,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(resource.data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

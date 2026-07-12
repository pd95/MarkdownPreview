import XCTest
import WebKit
import MarkdownPipeline
@testable import MarkLens

@MainActor
final class HTMLResourceSchemeHandlerTests: XCTestCase {
    func testServesKnownResourceWithDeclaredMIMEType() {
        let handler = HTMLResourceSchemeHandler()
        let resource = HTMLResource(
            identifier: "test/font.woff2",
            contentType: "font/woff2",
            data: Data([1, 2, 3])
        )
        handler.update(resources: [resource])
        let task = MockSchemeTask(url: resource.url)

        handler.webView(WKWebView(), start: task)

        XCTAssertEqual(task.response?.mimeType, "font/woff2")
        XCTAssertEqual(task.receivedData, resource.data)
        XCTAssertTrue(task.finished)
        XCTAssertNil(task.error)
    }

    func testRejectsUnknownResource() {
        let handler = HTMLResourceSchemeHandler()
        let task = MockSchemeTask(url: URL(string: "marklens-resource://resource/unknown")!)

        handler.webView(WKWebView(), start: task)

        XCTAssertNotNil(task.error)
        XCTAssertFalse(task.finished)
    }

    func testDuplicateResourceUsesLatestValueWithoutTrapping() {
        let handler = HTMLResourceSchemeHandler()
        let first = HTMLResource(identifier: "duplicate", contentType: "font/woff2", data: Data([1]))
        let latest = HTMLResource(identifier: "duplicate", contentType: "font/woff2", data: Data([2]))
        handler.update(resources: [first, latest])
        let task = MockSchemeTask(url: latest.url)

        handler.webView(WKWebView(), start: task)

        XCTAssertEqual(task.receivedData, latest.data)
    }
}

private final class MockSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    var response: URLResponse?
    var receivedData = Data()
    var finished = false
    var error: Error?

    init(url: URL) {
        self.request = URLRequest(url: url)
    }

    func didReceive(_ response: URLResponse) {
        self.response = response
    }

    func didReceive(_ data: Data) {
        receivedData.append(data)
    }

    func didFinish() {
        finished = true
    }

    func didFailWithError(_ error: any Error) {
        self.error = error
    }
}

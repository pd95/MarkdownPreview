//
//  MarkdownPreviewUITests.swift
//  MarkdownPreviewUITests
//
//  Created by Philipp on 17.05.2026.
//

import XCTest

final class MarkdownPreviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpensSampleMarkdownPreview() throws {
        let fixtureURL = try repositoryRoot()
            .appending(path: "inspiration")
            .appending(path: "sample.md")
        let app = XCUIApplication()
        app.launchArguments = [fixtureURL.path]
        app.launch()

        let contentView = app.descendants(matching: .any)["contentView"]
        XCTAssertTrue(contentView.waitForExistence(timeout: 5), "Expected markdown preview content view to appear.")

        let identifiedWebView = app.descendants(matching: .any)["previewWebView"]
        let webView = identifiedWebView.exists ? identifiedWebView : app.webViews.firstMatch
        if webView.waitForExistence(timeout: 5) == false {
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "accessibility-hierarchy"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Expected rendered markdown web view to appear.")
        }

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Expected MarkdownPreview window to appear.")
        capture(window, name: "sample-md-preview")
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(filePath: #filePath)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appending(path: "MarkdownPreview.xcodeproj").path) {
                return url
            }
            url.deleteLastPathComponent()
        }

        throw XCTSkip("Could not locate repository root from \(#filePath)")
    }
}

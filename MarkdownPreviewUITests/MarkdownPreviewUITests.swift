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
        let preview = XCUIApplication().openDocument(named: "sample", fileExtension: "md")
        defer { preview.terminate() }

        capture(preview.window, name: "sample-md-preview")
    }

    @MainActor
    func testOpenFileRecorded() throws {
        let preview = XCUIApplication().openDocument(named: "search-sample", fileExtension: "md")
        defer { preview.terminate() }

        capture(preview.window, name: "search-sample-opened")

        preview.openFind()
        capture(preview.window, name: "search-sample-find-open")

        preview.search("MLX")
        capture(preview.window, name: "search-sample-search-mlx")

        preview.submitSearch()
        preview.submitSearch()
        preview.submitSearch()
        capture(preview.window, name: "search-sample-search-mlx-advanced")

        preview.search(" ")
        capture(preview.window, name: "search-sample-search-mlx-space")

        preview.previousSearchResult()
        capture(preview.window, name: "search-sample-search-previous")

        preview.nextSearchResult()
        capture(preview.window, name: "search-sample-search-next")

        preview.closeFind()
        capture(preview.window, name: "search-sample-search-closed")

        preview.openFind()
        preview.search("Think")
        preview.submitSearch()
        capture(preview.window, name: "search-sample-search-think")
    }
}

private extension XCUIApplication {
    @MainActor
    @discardableResult
    func openDocument(
        named baseName: String,
        fileExtension: String,
        file: StaticString = #file,
        line: UInt = #line
    ) -> MarkdownPreviewAppHandle {
        guard let fixtureURL = Bundle(for: MarkdownPreviewUITests.self)
            .url(forResource: baseName, withExtension: fileExtension) else {
            XCTFail("Could not locate fixture \(baseName).\(fileExtension).", file: file, line: line)
            launch()
            return previewHandle(documentTitle: "\(baseName).\(fileExtension)", file: file, line: line)
        }

        terminate()
        launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            fixtureURL.path
        ]
        launch()

        return previewHandle(documentTitle: "\(baseName).\(fileExtension)", file: file, line: line)
    }

    @MainActor
    func previewHandle(documentTitle: String, file: StaticString = #file, line: UInt = #line) -> MarkdownPreviewAppHandle {
        let window = windows[documentTitle].firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 5),
            "Expected \(documentTitle) window to appear.",
            file: file,
            line: line
        )

        let contentView = window.descendants(matching: .any)["contentView"]
        XCTAssertTrue(
            contentView.waitForExistence(timeout: 5),
            "Expected markdown preview content view to appear.",
            file: file,
            line: line
        )

        let identifiedWebView = window.descendants(matching: .any)["previewWebView"]
        let webView = identifiedWebView.exists ? identifiedWebView : window.webViews.firstMatch
        if webView.waitForExistence(timeout: 5) == false {
            XCTFail("Expected rendered markdown web view to appear.", file: file, line: line)
        }

        return MarkdownPreviewAppHandle(app: self, window: window, contentView: contentView)
    }
}

@MainActor
private struct MarkdownPreviewAppHandle {
    let app: XCUIApplication
    let window: XCUIElement
    let contentView: XCUIElement

    var findField: XCUIElement {
        app.textFields["previewFindField"].firstMatch
    }

    func openFind() {
        if findField.exists {
            return
        }

        contentView.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(findField.waitForExistence(timeout: 5), "Expected preview find field to appear.")
    }

    func search(_ text: String) {
        findField.click()
        findField.typeText(text)
    }

    func submitSearch() {
        findField.typeText("\r")
    }

    func previousSearchResult() {
        let button = app.buttons["previewFindPreviousButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Expected previous search button.")
        button.click()
    }

    func nextSearchResult() {
        let button = app.buttons["previewFindNextButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Expected next search button.")
        button.click()
    }

    func closeFind() {
        let button = app.buttons["previewFindDoneButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Expected done search button.")
        button.click()
        XCTAssertFalse(findField.exists, "Expected preview find field to close.")
    }

    func terminate() {
        app.terminate()
    }
}

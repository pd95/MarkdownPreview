//
//  MarkLensUITests.swift
//  MarkLensUITests
//
//  Created by Philipp on 17.05.2026.
//

import XCTest

final class MarkLensUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpensSampleMarkLens() throws {
        let preview = XCUIApplication().openDocument(named: "sample", fileExtension: "md")
        defer { preview.terminate() }

        capture(preview.window, name: "sample-md-preview")
    }

    @MainActor
    func testCreatesStarterDocument() throws {
        let preview = XCUIApplication().openDocument(named: "sample", fileExtension: "md")
        defer { preview.terminate() }

        preview.createStarterDocument()
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

    @MainActor
    func testCancelDismissesPrintDialog() throws {
        let preview = XCUIApplication().openDocument(named: "sample", fileExtension: "md")
        defer { preview.terminate() }

        preview.cancelPrint()
    }

    @MainActor
    func testExportCancellationAndRenderedFormats() throws {
        let preview = XCUIApplication().openDocument(named: "sample", fileExtension: "md")
        defer { preview.terminate() }

        preview.cancelExport()
        try preview.exportAndVerifyContent(format: .pdf)
        try preview.exportAndVerifyContent(format: .html)
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
    ) -> MarkLensAppHandle {
        guard let fixtureURL = Bundle(for: MarkLensUITests.self)
            .url(forResource: baseName, withExtension: fileExtension) else {
            XCTFail("Could not locate fixture \(baseName).\(fileExtension).", file: file, line: line)
            launch()
            return previewHandle(
                documentTitle: "\(baseName).\(fileExtension)",
                file: file,
                line: line
            )
        }

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkLensUITests-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: exportDirectory,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(
                at: fixtureURL,
                to: exportDirectory.appendingPathComponent(fixtureURL.lastPathComponent)
            )
        } catch {
            XCTFail("Could not prepare the temporary test document: \(error)", file: file, line: line)
        }

        let temporaryDocumentURL = exportDirectory.appendingPathComponent(fixtureURL.lastPathComponent)

        terminate()
        launchEnvironment["MARKLENS_UI_TEST_EXPORT_DIRECTORY"] = exportDirectory.path
        launchArguments = [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-CustomCSSOverrides",
            "",
            "-LastRenderedDocumentExportFormat",
            "pdf",
            temporaryDocumentURL.path
        ]
        launch()

        return previewHandle(
            documentTitle: "\(baseName).\(fileExtension)",
            exportDirectoryURL: exportDirectory,
            file: file,
            line: line
        )
    }

    @MainActor
    func previewHandle(
        documentTitle: String,
        exportDirectoryURL: URL? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) -> MarkLensAppHandle {
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

        return MarkLensAppHandle(
            app: self,
            window: window,
            contentView: contentView,
            exportDirectoryURL: exportDirectoryURL
        )
    }
}

@MainActor
private struct MarkLensAppHandle {
    enum ExportFormat {
        case pdf
        case html

        var pathExtension: String {
            switch self {
            case .pdf: "pdf"
            case .html: "html"
            }
        }
    }

    let app: XCUIApplication
    let window: XCUIElement
    let contentView: XCUIElement
    let exportDirectoryURL: URL?

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

    func createStarterDocument() {
        let originalWindowCount = app.windows.count
        let previews = app.webViews
        let originalPreviewCount = previews.count
        let fileMenu = app.menuBars.menuBarItems["File"]
        fileMenu.click()

        let newItem = fileMenu.menus.menuItems["New"]
        XCTAssertTrue(newItem.waitForExistence(timeout: 2), "Expected the File → New command.")
        XCTAssertTrue(newItem.isEnabled, "Expected File → New to be enabled.")
        newItem.click()

        let deadline = Date().addingTimeInterval(5)
        while app.windows.count <= originalWindowCount, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertGreaterThan(
            app.windows.count,
            originalWindowCount,
            "Expected File → New to create another document window."
        )

        let previewDeadline = Date().addingTimeInterval(5)
        while previews.count <= originalPreviewCount, Date() < previewDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertGreaterThan(
            previews.count,
            originalPreviewCount,
            "Expected the new Markdown document to display its rendered preview."
        )

        app.typeKey("e", modifierFlags: .command)
        let sourceEditor = app.textViews["Markdown source editor"].firstMatch
        XCTAssertTrue(
            sourceEditor.waitForExistence(timeout: 5),
            "Expected the new document to expose its editable Markdown source."
        )
        XCTAssertTrue(
            (sourceEditor.value as? String)?.contains("# Welcome to MarkLens") == true,
            "Expected File → New to use the Markdown starter."
        )
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

    func cancelPrint() {
        contentView.typeKey("p", modifierFlags: .command)

        let printSheet = window.sheets.firstMatch
        XCTAssertTrue(printSheet.waitForExistence(timeout: 5), "Expected the print dialog to appear.")

        let cancelButton = printSheet.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Expected the print dialog to appear.")
        cancelButton.click()
        XCTAssertTrue(
            printSheet.waitForNonExistence(timeout: 2),
            "Expected the print dialog to stay dismissed after cancellation."
        )
        XCTAssertFalse(
            window.sheets.firstMatch.waitForExistence(timeout: 1),
            "Expected the print dialog not to reappear after cancellation."
        )
    }

    func cancelExport() {
        let exportSheet = openExportSheet()
        let cancelButton = exportSheet.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2), "Expected the Export cancel button.")
        cancelButton.click()
        XCTAssertTrue(
            exportSheet.waitForNonExistence(timeout: 2),
            "Expected the Export dialog to stay dismissed after cancellation."
        )
    }

    func exportAndVerifyContent(format: ExportFormat) throws {
        let exportDirectoryURL = try XCTUnwrap(exportDirectoryURL)
        let filesBeforeExport = try exportedFiles(in: exportDirectoryURL)

        let exportSheet = openExportSheet()
        let formatPopup = formatPopup(in: exportSheet)
        if format == .html {
            formatPopup.click()
            formatPopup.typeKey(.downArrow, modifierFlags: [])
            formatPopup.typeKey(.return, modifierFlags: [])
        }

        let exportButton = exportSheet.buttons["Export"].firstMatch
        XCTAssertTrue(exportButton.waitForExistence(timeout: 2), "Expected the Export button.")
        exportButton.click()

        // PDF generation may temporarily replace the save panel with another sheet.
        // The file itself is the reliable signal that the asynchronous export finished.
        let deadline = Date().addingTimeInterval(15)
        var exportURL: URL?
        while Date() < deadline {
            exportURL = try exportedFiles(in: exportDirectoryURL).subtracting(filesBeforeExport).first
            if exportURL != nil {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        let unsafeDestinationAlert = app.alerts["Unsafe Test Export Destination"]
        XCTAssertFalse(
            unsafeDestinationAlert.waitForExistence(timeout: 1),
            "The app rejected the temporary export directory."
        )
        let completedExportURL = try XCTUnwrap(
            exportURL,
            "Expected the export in the UI test's temporary directory."
        )
        defer { try? FileManager.default.removeItem(at: completedExportURL) }
        XCTAssertEqual(completedExportURL.pathExtension, format.pathExtension)

        let data = try Data(contentsOf: completedExportURL)
        switch format {
        case .pdf:
            XCTAssertTrue(data.starts(with: Data("%PDF-".utf8)), "Expected a PDF file.")
            XCTAssertGreaterThan(data.count, 2_000, "Expected rendered PDF content, not empty pages.")
        case .html:
            let html = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertTrue(html.contains("<!DOCTYPE html>"), "Expected an HTML document.")
            XCTAssertTrue(html.contains("data-mermaid-diagram"), "Expected the Mermaid diagram markup.")
            XCTAssertTrue(html.contains("mermaid.initialize"), "Expected the Mermaid renderer.")
            XCTAssertFalse(html.contains("marklens-resource://"), "Expected app resources to be inlined.")
            XCTAssertFalse(
                html.contains("data:application/javascript"),
                "Expected executable JavaScript to be safely inlined."
            )
        }
    }

    private func exportedFiles(in directory: URL) throws -> Set<URL> {
        Set(try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))
    }

    private func openExportSheet() -> XCUIElement {
        contentView.typeKey("e", modifierFlags: [.command, .shift])

        let exportSheet = window.sheets.firstMatch
        XCTAssertTrue(exportSheet.waitForExistence(timeout: 5), "Expected the Export dialog to appear.")
        _ = formatPopup(in: exportSheet)
        return exportSheet
    }

    private func formatPopup(in exportSheet: XCUIElement) -> XCUIElement {
        let popups = exportSheet.popUpButtons
        XCTAssertGreaterThanOrEqual(
            popups.count,
            2,
            "Expected separate path and file-format selectors."
        )
        let popup = popups.element(boundBy: popups.count - 1)
        XCTAssertTrue(popup.waitForExistence(timeout: 2), "Expected the PDF and HTML format selector.")
        return popup
    }

    func terminate() {
        app.terminate()
        if let exportDirectoryURL {
            try? FileManager.default.removeItem(at: exportDirectoryURL)
        }
    }
}

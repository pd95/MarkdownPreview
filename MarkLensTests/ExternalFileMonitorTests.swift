#if os(macOS)
import Dispatch
import Foundation
import XCTest
@testable import MarkLens

@MainActor
final class ExternalFileMonitorTests: XCTestCase {
    func testDetectsAtomicFileReplacement() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("document.md")
        try Data("# Before".utf8).write(to: fileURL)

        let changed = expectation(description: "external file change")
        let monitor = ExternalFileMonitor(fileURL: fileURL, initialText: "# Before") { text in
            XCTAssertEqual(text, "# After")
            changed.fulfill()
        }

        try Data("# After".utf8).write(to: fileURL, options: .atomic)
        wait(for: [changed], timeout: 3)
        monitor.stop()
        withExtendedLifetime(monitor) {}
    }

    func testDetectsSuccessiveAtomicReplacements() throws {
        let fixture = try MonitorFixture(initialText: "One")
        defer { fixture.remove() }

        let changed = expectation(description: "successive changes")
        changed.expectedFulfillmentCount = 2
        var received: [String] = []
        let monitor = ExternalFileMonitor(fileURL: fixture.fileURL, initialText: "One") { text in
            received.append(text)
            changed.fulfill()
        }

        try Data("Two".utf8).write(to: fixture.fileURL, options: .atomic)
        XCTAssertTrue(waitUntil { received == ["Two"] })
        try Data("Three".utf8).write(to: fixture.fileURL, options: .atomic)

        wait(for: [changed], timeout: 3)
        XCTAssertEqual(received, ["Two", "Three"])
        monitor.stop()
    }

    func testDetectsFileRecreatedAfterDeletion() throws {
        let fixture = try MonitorFixture(initialText: "Before")
        defer { fixture.remove() }

        let changed = expectation(description: "recreated file")
        let monitor = ExternalFileMonitor(fileURL: fixture.fileURL, initialText: "Before") { text in
            XCTAssertEqual(text, "After")
            changed.fulfill()
        }

        try FileManager.default.removeItem(at: fixture.fileURL)
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(300)) {
            try? Data("After".utf8).write(to: fixture.fileURL)
        }

        wait(for: [changed], timeout: 3)
        monitor.stop()
    }

    func testStopSuppressesQueuedDelivery() throws {
        let fixture = try MonitorFixture(initialText: "Before")
        defer { fixture.remove() }

        let changed = expectation(description: "stale change")
        changed.isInverted = true
        let monitor = ExternalFileMonitor(fileURL: fixture.fileURL, initialText: "Before") { _ in
            changed.fulfill()
        }

        try Data("After".utf8).write(to: fixture.fileURL, options: .atomic)
        monitor.stop()

        wait(for: [changed], timeout: 0.5)
    }

    func testReplacingFileDoesNotReportItsOwnWrite() async throws {
        let fixture = try MonitorFixture(initialText: "Before")
        defer { fixture.remove() }

        let changed = expectation(description: "stale external change")
        changed.isInverted = true
        let monitor = ExternalFileMonitor(fileURL: fixture.fileURL, initialText: "Before") { _ in
            changed.fulfill()
        }

        try await monitor.replaceFile(with: "Draft")

        await fulfillment(of: [changed], timeout: 0.5)
        XCTAssertEqual(try String(contentsOf: fixture.fileURL, encoding: .utf8), "Draft")
        monitor.stop()
    }

    func testReplacingFileRejectsAChangedBaseline() async throws {
        let fixture = try MonitorFixture(initialText: "Before")
        defer { fixture.remove() }
        let monitor = ExternalFileMonitor(fileURL: fixture.fileURL, initialText: "Before") { _ in }

        try Data("External".utf8).write(to: fixture.fileURL, options: .atomic)

        do {
            try await monitor.replaceFile(with: "Draft")
            XCTFail("Expected the changed file to prevent replacement")
        } catch ExternalFileMonitor.ReplacementError.fileChanged(let text) {
            XCTAssertEqual(text, "External")
        }
        XCTAssertEqual(try String(contentsOf: fixture.fileURL, encoding: .utf8), "External")
        monitor.stop()
    }

    func testStartsMonitoringWhenInitiallyMissingFileAppears() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("document.md")

        let changed = expectation(description: "created file")
        let monitor = ExternalFileMonitor(fileURL: fileURL, initialText: "Before") { text in
            XCTAssertEqual(text, "After")
            changed.fulfill()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(300)) {
            try? Data("After".utf8).write(to: fileURL)
        }

        wait(for: [changed], timeout: 3)
        monitor.stop()
    }

    private func waitUntil(
        timeout: TimeInterval = 3,
        condition: @escaping () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false && RunLoop.current.run(mode: .default, before: deadline) && Date() < deadline {}
        return condition()
    }
}

private struct MonitorFixture {
    let directoryURL: URL
    let fileURL: URL

    init(initialText: String) throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("document.md")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(initialText.utf8).write(to: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
#endif

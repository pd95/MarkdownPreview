#if os(macOS)
import Darwin
import Dispatch
import Foundation

@MainActor
final class ExternalFileMonitor {
    enum InspectionResult {
        case unchanged
        case changed(String)
        case unavailable(Error)
        case cancelled
    }

    enum ReplacementError: Error {
        case fileChanged(String)
    }

    typealias ChangeHandler = @MainActor (String) -> Void

    private let fileURL: URL
    private let changeHandler: ChangeHandler
    private var source: DispatchSourceFileSystemObject?
    private var reloadTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var lastContents: Data
    private var generation: UInt64 = 0
    private var sourceGeneration: UInt64 = 0
    private var isActive = true

    init(fileURL: URL, initialText: String, changeHandler: @escaping ChangeHandler) {
        self.fileURL = fileURL.standardizedFileURL
        self.changeHandler = changeHandler
        self.lastContents = Data(initialText.utf8)

        if installSource() {
            refresh()
        } else {
            scheduleReconnect()
        }
    }

    deinit {
        reloadTask?.cancel()
        reconnectTask?.cancel()
        source?.cancel()
    }

    func refresh() {
        scheduleReload()
    }

    func stop() {
        invalidatePendingWork()
        isActive = false
        sourceGeneration &+= 1
        source?.cancel()
        source = nil
    }

    func inspectForExternalChange() async -> InspectionResult {
        let operationGeneration = beginResolution()
        do {
            let contents = try await stableContents()
            guard isCurrent(operationGeneration) else {
                return .cancelled
            }
            replaceSource()
            guard contents != lastContents else {
                return .unchanged
            }
            lastContents = contents
            guard let text = String(data: contents, encoding: .utf8) else {
                return .unavailable(CocoaError(.fileReadInapplicableStringEncoding))
            }
            return .changed(text)
        } catch {
            guard isCurrent(operationGeneration) else {
                return .cancelled
            }
            replaceSource()
            return .unavailable(error)
        }
    }

    func replaceFile(with text: String) async throws {
        let operationGeneration = beginResolution()
        guard isCurrent(operationGeneration) else {
            throw CancellationError()
        }
        let expectedContents = lastContents
        let currentContents = try await stableContents()
        guard isCurrent(operationGeneration) else {
            throw CancellationError()
        }
        guard currentContents == expectedContents else {
            lastContents = currentContents
            replaceSource()
            guard let currentText = String(data: currentContents, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            throw ReplacementError.fileChanged(currentText)
        }

        let fileURL = fileURL
        let contents = Data(text.utf8)
        try await Task.detached(priority: .userInitiated) {
            try contents.write(to: fileURL, options: .atomic)
        }.value

        guard isCurrent(operationGeneration) else {
            throw CancellationError()
        }
        lastContents = contents
        replaceSource()
    }

    func currentFileText() async throws -> String {
        let operationGeneration = beginResolution()
        guard isCurrent(operationGeneration) else {
            throw CancellationError()
        }
        let contents = try await stableContents()
        guard isCurrent(operationGeneration) else {
            throw CancellationError()
        }
        guard let text = String(data: contents, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        lastContents = contents
        replaceSource()
        return text
    }

    private func scheduleReload() {
        guard isActive else {
            return
        }
        generation &+= 1
        let reloadGeneration = generation
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                let contents = try await stableContents()
                guard isCurrent(reloadGeneration), contents != lastContents else {
                    return
                }
                lastContents = contents
                guard let text = String(data: contents, encoding: .utf8) else {
                    return
                }
                changeHandler(text)
                replaceSource()
            } catch is CancellationError {
                return
            } catch {
                guard let self, isCurrent(reloadGeneration) else { return }
                replaceSource()
            }
        }
    }

    private func stableContents() async throws -> Data {
        let first = try await readContents()
        try await Task.sleep(for: .milliseconds(75))
        let second = try await readContents()
        guard first == second else {
            throw CocoaError(.fileReadUnknown)
        }
        return second
    }

    private func readContents() async throws -> Data {
        let fileURL = fileURL
        return try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: fileURL)
        }.value
    }

    private func beginResolution() -> UInt64 {
        invalidatePendingWork()
        sourceGeneration &+= 1
        source?.cancel()
        source = nil
        return generation
    }

    private func invalidatePendingWork() {
        generation &+= 1
        reloadTask?.cancel()
        reloadTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    private func isCurrent(_ operationGeneration: UInt64) -> Bool {
        isActive && generation == operationGeneration && Task.isCancelled == false
    }

    private func replaceSource() {
        sourceGeneration &+= 1
        source?.cancel()
        source = nil
        guard isActive else {
            return
        }
        if installSource() {
            scheduleReload()
        } else {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard let self, isActive else { return }
                if installSource() {
                    scheduleReload()
                } else {
                    scheduleReconnect()
                }
            } catch {
                return
            }
        }
    }

    private func installSource() -> Bool {
        guard isActive else {
            return false
        }
        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            return false
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend, .link, .revoke],
            queue: .main
        )
        sourceGeneration &+= 1
        let installedGeneration = sourceGeneration
        newSource.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.sourceDidChange(installedGeneration: installedGeneration)
            }
        }
        newSource.setCancelHandler {
            close(descriptor)
        }
        source = newSource
        newSource.resume()
        return true
    }

    private func sourceDidChange(installedGeneration: UInt64) {
        guard isActive, sourceGeneration == installedGeneration else {
            return
        }
        scheduleReload()
    }
}
#endif

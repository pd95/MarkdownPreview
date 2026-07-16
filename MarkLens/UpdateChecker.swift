#if os(macOS)
import Combine
import Foundation

struct ReleaseVersion: Comparable, Equatable {
    private let components: [Int]
    private let prereleaseIdentifiers: [String]?

    init?(_ value: String) {
        var value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first?.lowercased() == "v" {
            value.removeFirst()
        }

        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.isEmpty == false else {
            return nil
        }

        let numericParts = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        let parsedComponents = numericParts.map { Int($0) }
        guard numericParts.isEmpty == false,
            numericParts.allSatisfy({ $0.isEmpty == false }),
            numericParts.allSatisfy({ $0.allSatisfy { $0.isNumber } }),
            parsedComponents.allSatisfy({ $0 != nil })
        else {
            return nil
        }
        var components = parsedComponents.compactMap { $0 }

        while components.count > 1 && components.last == 0 {
            components.removeLast()
        }

        if parts.count == 2 {
            let identifiers = parts[1].split(separator: ".", omittingEmptySubsequences: false)
            guard identifiers.isEmpty == false,
                identifiers.allSatisfy({ $0.isEmpty == false }),
                identifiers.allSatisfy({ identifier in
                    identifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
                })
            else {
                return nil
            }
            prereleaseIdentifiers = identifiers.map(String.init)
        } else {
            prereleaseIdentifiers = nil
        }

        self.components = components
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let componentCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<componentCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }

        switch (lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers) {
        case (nil, nil):
            return false
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (.some(let left), .some(let right)):
            for index in 0..<min(left.count, right.count) {
                if left[index] == right[index] {
                    continue
                }

                let leftNumber = Int(left[index])
                let rightNumber = Int(right[index])
                switch (leftNumber, rightNumber) {
                case (.some(let leftNumber), .some(let rightNumber)):
                    return leftNumber < rightNumber
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return left[index] < right[index]
                }
            }
            return left.count < right.count
        }
    }
}

struct AvailableRelease: Codable, Equatable {
    let tagName: String
    let name: String?
    let body: String
    let htmlURL: URL

    var displayVersion: String {
        tagName.first?.lowercased() == "v" ? String(tagName.dropFirst()) : tagName
    }
}

struct UpdateHTTPResponse {
    let data: Data
    let statusCode: Int
    let etag: String?
}

@MainActor
final class UpdateChecker: ObservableObject {
    typealias HTTPRequest = (URLRequest) async throws -> UpdateHTTPResponse

    @Published private(set) var availableRelease: AvailableRelease?

    private static let releasesURL = URL(
        string: "https://api.github.com/repos/pd95/MarkdownPreview/releases/latest"
    )!
    private static let checkInterval: TimeInterval = 7 * 24 * 60 * 60
    private static let lastAttemptKey = "updateChecker.lastAttempt"
    private static let cachedReleaseKey = "updateChecker.cachedRelease"
    private static let etagKey = "updateChecker.etag"

    private let currentVersion: String
    private let automaticChecksEnabled: Bool
    private let defaults: UserDefaults
    private let now: () -> Date
    private let request: HTTPRequest
    private var activeCheck: Task<Void, Never>?

    init(
        currentVersion: String = BuildInfo.tagVersion,
        releaseTag: String = BuildInfo.releaseTag,
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: @escaping () -> Date = Date.init,
        request: @escaping HTTPRequest = UpdateChecker.liveRequest
    ) {
        #if DEBUG
        let mockRelease = Self.mockRelease(from: environment)
        #else
        let mockRelease: AvailableRelease? = nil
        #endif
        self.currentVersion = currentVersion
        self.automaticChecksEnabled = releaseTag != "local" && mockRelease == nil
        self.defaults = defaults
        self.now = now
        self.request = request

        if let mockRelease {
            availableRelease = mockRelease
        } else if let data = defaults.data(forKey: Self.cachedReleaseKey),
            let release = try? JSONDecoder().decode(AvailableRelease.self, from: data),
            Self.isTrustedReleaseURL(release.htmlURL)
        {
            availableRelease = Self.isNewer(release.tagName, than: currentVersion) ? release : nil
        }
    }

    func checkIfDue() async {
        guard automaticChecksEnabled else {
            return
        }

        if let activeCheck {
            await activeCheck.value
            return
        }

        let attemptDate = now()
        if let lastAttempt = defaults.object(forKey: Self.lastAttemptKey) as? Date,
            attemptDate.timeIntervalSince(lastAttempt) < Self.checkInterval
        {
            return
        }

        defaults.set(attemptDate, forKey: Self.lastAttemptKey)
        let task = Task<Void, Never> { [weak self] in
            guard let self else {
                return
            }
            await self.performCheck()
        }
        activeCheck = task
        await task.value
        activeCheck = nil
    }

    private func performCheck() async {
        var urlRequest = URLRequest(url: Self.releasesURL)
        urlRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let etag = defaults.string(forKey: Self.etagKey) {
            urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let response = try await request(urlRequest)
            if response.statusCode == 304 {
                return
            }
            guard response.statusCode == 200 else {
                return
            }

            let githubRelease = try JSONDecoder().decode(GitHubRelease.self, from: response.data)
            guard githubRelease.draft == false,
                githubRelease.prerelease == false,
                Self.isTrustedReleaseURL(githubRelease.htmlURL)
            else {
                return
            }

            let release = AvailableRelease(
                tagName: githubRelease.tagName,
                name: githubRelease.name,
                body: githubRelease.body ?? "",
                htmlURL: githubRelease.htmlURL
            )
            if let cachedData = try? JSONEncoder().encode(release) {
                defaults.set(cachedData, forKey: Self.cachedReleaseKey)
            }
            if let etag = response.etag {
                defaults.set(etag, forKey: Self.etagKey)
            } else {
                defaults.removeObject(forKey: Self.etagKey)
            }
            availableRelease = Self.isNewer(release.tagName, than: currentVersion) ? release : nil
        } catch {
            // Update checks must never interrupt normal document work.
        }
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let candidateVersion = ReleaseVersion(candidate),
            let currentVersion = ReleaseVersion(current)
        else {
            return false
        }
        return candidateVersion > currentVersion
    }

    private static func isTrustedReleaseURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.lowercased() == "github.com"
    }

    #if DEBUG
    private static func mockRelease(from environment: [String: String]) -> AvailableRelease? {
        guard let configuredVersion = environment["MARKLENS_MOCK_UPDATE_VERSION"],
            ReleaseVersion(configuredVersion) != nil
        else {
            return nil
        }

        let tagName =
            configuredVersion.first?.lowercased() == "v"
            ? configuredVersion
            : "v\(configuredVersion)"
        guard
            let releaseURL = URL(
                string: "https://github.com/pd95/MarkdownPreview/releases/tag/\(tagName)"
            )
        else {
            return nil
        }

        return AvailableRelease(
            tagName: tagName,
            name: "MarkLens \(tagName)",
            body: "Debug preview of the MarkLens update notification.",
            htmlURL: releaseURL
        )
    }
    #endif

    static func liveRequest(_ request: URLRequest) async throws -> UpdateHTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return UpdateHTTPResponse(
            data: data,
            statusCode: response.statusCode,
            etag: response.value(forHTTPHeaderField: "ETag")
        )
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
        case prerelease
    }
}
#endif

#if os(macOS)
import XCTest
@testable import MarkLens

@MainActor
final class UpdateCheckerTests: XCTestCase {
    func testVersionComparisonUsesNumericComponentsAndPrereleaseOrdering() throws {
        XCTAssertLessThan(try version("v1.9.0"), try version("1.10.0"))
        XCTAssertEqual(try version("1.2"), try version("1.2.0"))
        XCTAssertLessThan(try version("1.2.0-rc1"), try version("1.2.0"))
        XCTAssertLessThan(try version("1.2.0-rc.2"), try version("1.2.0-rc.10"))
        XCTAssertNil(ReleaseVersion("local"))
        XCTAssertNil(ReleaseVersion("1.two.0"))
    }

    func testNewerStableReleaseBecomesAvailableAndIsCached() async throws {
        let defaults = makeDefaults()
        let checker = UpdateChecker(
            currentVersion: "1.2.0",
            releaseTag: "v1.2.0",
            defaults: defaults,
            request: { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")
                return UpdateHTTPResponse(
                    data: Self.releaseJSON(tag: "v1.3.0", body: "Useful improvements."),
                    statusCode: 200,
                    etag: "release-etag"
                )
            }
        )

        await checker.checkIfDue()

        XCTAssertEqual(checker.availableRelease?.displayVersion, "1.3.0")
        XCTAssertEqual(checker.availableRelease?.body, "Useful improvements.")

        let restored = UpdateChecker(
            currentVersion: "1.2.0",
            releaseTag: "v1.2.0",
            defaults: defaults,
            request: { _ in
                XCTFail("Restoring cached state must not make a request")
                throw URLError(.unknown)
            }
        )
        XCTAssertEqual(restored.availableRelease, checker.availableRelease)
    }

    func testCurrentOrOlderReleaseDoesNotBecomeAvailable() async {
        for tag in ["v1.2.0", "v1.1.9"] {
            let checker = UpdateChecker(
                currentVersion: "1.2.0",
                releaseTag: "v1.2.0",
                defaults: makeDefaults(),
                request: { _ in
                    UpdateHTTPResponse(
                        data: Self.releaseJSON(tag: tag),
                        statusCode: 200,
                        etag: nil
                    )
                }
            )

            await checker.checkIfDue()
            XCTAssertNil(checker.availableRelease)
        }
    }

    func testChecksAreThrottledForSevenDays() async {
        let defaults = makeDefaults()
        var currentDate = Date(timeIntervalSince1970: 1_000_000)
        var requestCount = 0
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            releaseTag: "v1.0.0",
            defaults: defaults,
            now: { currentDate },
            request: { _ in
                requestCount += 1
                return UpdateHTTPResponse(
                    data: Self.releaseJSON(tag: "v1.1.0"),
                    statusCode: 200,
                    etag: nil
                )
            }
        )

        await checker.checkIfDue()
        currentDate.addTimeInterval(6 * 24 * 60 * 60)
        await checker.checkIfDue()
        XCTAssertEqual(requestCount, 1)

        currentDate.addTimeInterval(2 * 24 * 60 * 60)
        await checker.checkIfDue()
        XCTAssertEqual(requestCount, 2)
    }

    func testETagIsSentAndNotModifiedKeepsCachedRelease() async {
        let defaults = makeDefaults()
        var requestCount = 0
        var currentDate = Date(timeIntervalSince1970: 1_000_000)
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            releaseTag: "v1.0.0",
            defaults: defaults,
            now: { currentDate },
            request: { request in
                requestCount += 1
                if requestCount == 1 {
                    return UpdateHTTPResponse(
                        data: Self.releaseJSON(tag: "v1.1.0"),
                        statusCode: 200,
                        etag: "cached-etag"
                    )
                }
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "If-None-Match"),
                    "cached-etag"
                )
                return UpdateHTTPResponse(
                    data: Data(),
                    statusCode: 304,
                    etag: nil
                )
            }
        )

        await checker.checkIfDue()
        currentDate.addTimeInterval(8 * 24 * 60 * 60)
        await checker.checkIfDue()

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(checker.availableRelease?.tagName, "v1.1.0")
    }

    func testConcurrentChecksShareOneRequest() async {
        var requestCount = 0
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            releaseTag: "v1.0.0",
            defaults: makeDefaults(),
            request: { _ in
                requestCount += 1
                try? await Task.sleep(for: .milliseconds(25))
                return UpdateHTTPResponse(
                    data: Self.releaseJSON(tag: "v1.1.0"),
                    statusCode: 200,
                    etag: nil
                )
            }
        )

        async let first: Void = checker.checkIfDue()
        async let second: Void = checker.checkIfDue()
        await first
        await second

        XCTAssertEqual(requestCount, 1)
    }

    func testLocalBuildDoesNotCheckAutomatically() async {
        var requested = false
        let checker = UpdateChecker(
            currentVersion: "local",
            releaseTag: "local",
            defaults: makeDefaults(),
            request: { _ in
                requested = true
                return UpdateHTTPResponse(data: Data(), statusCode: 500, etag: nil)
            }
        )

        await checker.checkIfDue()

        XCTAssertFalse(requested)
        XCTAssertNil(checker.availableRelease)
    }

    #if DEBUG
    func testDebugMockReleaseAppearsWithoutRequestingGitHub() async {
        var requested = false
        let checker = UpdateChecker(
            currentVersion: "local",
            releaseTag: "local",
            defaults: makeDefaults(),
            environment: ["MARKLENS_MOCK_UPDATE_VERSION": "99.0.0"],
            request: { _ in
                requested = true
                return UpdateHTTPResponse(data: Data(), statusCode: 500, etag: nil)
            }
        )

        await checker.checkIfDue()

        XCTAssertFalse(requested)
        XCTAssertEqual(checker.availableRelease?.tagName, "v99.0.0")
        XCTAssertEqual(checker.availableRelease?.displayVersion, "99.0.0")
        XCTAssertEqual(
            checker.availableRelease?.htmlURL,
            URL(string: "https://github.com/pd95/MarkdownPreview/releases/tag/v99.0.0")
        )

    }
    #endif

    func testFailuresUntrustedURLsAndNonStableReleasesAreIgnored() async {
        let failureChecker = UpdateChecker(
            currentVersion: "1.0.0",
            releaseTag: "v1.0.0",
            defaults: makeDefaults(),
            request: { _ in
                throw URLError(.notConnectedToInternet)
            }
        )
        await failureChecker.checkIfDue()
        XCTAssertNil(failureChecker.availableRelease)

        let untrustedChecker = UpdateChecker(
            currentVersion: "1.0.0",
            releaseTag: "v1.0.0",
            defaults: makeDefaults(),
            request: { _ in
                UpdateHTTPResponse(
                    data: Self.releaseJSON(tag: "v2.0.0", url: "https://example.com/release"),
                    statusCode: 200,
                    etag: nil
                )
            }
        )
        await untrustedChecker.checkIfDue()
        XCTAssertNil(untrustedChecker.availableRelease)

        for response in [
            Self.releaseJSON(tag: "v2.0.0", draft: true),
            Self.releaseJSON(tag: "v2.0.0-rc1", prerelease: true),
        ] {
            let checker = UpdateChecker(
                currentVersion: "1.0.0",
                releaseTag: "v1.0.0",
                defaults: makeDefaults(),
                request: { _ in
                    UpdateHTTPResponse(data: response, statusCode: 200, etag: nil)
                }
            )
            await checker.checkIfDue()
            XCTAssertNil(checker.availableRelease)
        }
    }

    private func version(_ value: String) throws -> ReleaseVersion {
        try XCTUnwrap(ReleaseVersion(value))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "UpdateCheckerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    nonisolated private static func releaseJSON(
        tag: String,
        body: String = "Release notes",
        url: String = "https://github.com/pd95/MarkdownPreview/releases/tag/v1.1.0",
        draft: Bool = false,
        prerelease: Bool = false
    ) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "tag_name": tag,
            "name": "MarkLens \(tag)",
            "body": body,
            "html_url": url,
            "draft": draft,
            "prerelease": prerelease,
        ])
    }
}
#endif

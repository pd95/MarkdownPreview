import Foundation

public enum WikiLinkResolverError: LocalizedError, Sendable {
    case invalidTarget
    case missingTarget(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTarget:
            return "This wikilink target is not valid."
        case .missingTarget(let target):
            return "No Markdown document named \(target) was found in the selected wiki folder."
        }
    }
}

public struct WikiLinkResolver: Sendable {
    public static let defaultMarkdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn"
    ]

    private let markdownExtensions: Set<String>

    public init(markdownExtensions: Set<String> = defaultMarkdownExtensions) {
        self.markdownExtensions = Set(markdownExtensions.map { $0.lowercased() })
    }

    public func matches(
        for target: String,
        in root: URL,
        shouldCancel: @Sendable () -> Bool = { false }
    ) throws -> [URL] {
        if shouldCancel() { throw CancellationError() }
        guard let query = normalized(target) else {
            throw WikiLinkResolverError.invalidTarget
        }

        let isPathQualified = query.target.contains("/")
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw WikiLinkResolverError.missingTarget(target)
        }

        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        var matches: [URL] = []
        for case let candidate as URL in enumerator {
            if shouldCancel() { throw CancellationError() }
            let values = try? candidate.resourceValues(forKeys: resourceKeys)
            guard values?.isRegularFile == true,
                  values?.isSymbolicLink != true,
                  markdownExtensions.contains(candidate.pathExtension.lowercased()) else {
                continue
            }

            let canonicalCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath()
            guard contains(canonicalCandidate, in: canonicalRoot) else { continue }

            var candidateValue = isPathQualified
                ? relativePath(of: canonicalCandidate, in: canonicalRoot)
                : canonicalCandidate.lastPathComponent
            if query.hasExplicitExtension == false {
                candidateValue = (candidateValue as NSString).deletingPathExtension
            }
            if candidateValue.compare(
                query.target,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame {
                matches.append(canonicalCandidate)
            }
        }

        guard matches.isEmpty == false else {
            throw WikiLinkResolverError.missingTarget(target)
        }
        if shouldCancel() { throw CancellationError() }
        return matches.sorted {
            relativePath(of: $0, in: canonicalRoot).localizedStandardCompare(
                relativePath(of: $1, in: canonicalRoot)
            ) == .orderedAscending
        }
    }

    public func relativePath(of url: URL, in root: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let fileComponents = url.standardizedFileURL.pathComponents
        return fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }

    private func normalized(_ target: String) -> (target: String, hasExplicitExtension: Bool)? {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.isEmpty == false,
              target.hasPrefix("/") == false,
              target.hasPrefix("~") == false else {
            return nil
        }
        let components = target.split(separator: "/", omittingEmptySubsequences: false)
        guard components.allSatisfy({ $0.isEmpty == false && $0 != "." && $0 != ".." }) else {
            return nil
        }
        return (target, URL(fileURLWithPath: target).pathExtension.isEmpty == false)
    }

    private func contains(_ file: URL, in folder: URL) -> Bool {
        let fileComponents = file.standardizedFileURL.pathComponents
        let folderComponents = folder.standardizedFileURL.pathComponents
        return fileComponents.starts(with: folderComponents)
            && fileComponents.count > folderComponents.count
    }
}

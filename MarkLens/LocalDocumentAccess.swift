import Combine
import Foundation

final class LocalDocumentAccess: ObservableObject {
#if os(macOS)
    private static let bookmarksKey = "AuthorizedLocalDocumentFoldersV2"

    private struct AccessedFolder {
        let securityScopedURL: URL
        let canonicalURL: URL
    }

    private var accessedFolders: [AccessedFolder] = []
    private var bookmarks: [Data] = []
    @Published private(set) var hasAuthorizedFolders = false

    init() {
        restoreBookmarks()
    }

    deinit {
        accessedFolders.forEach { $0.securityScopedURL.stopAccessingSecurityScopedResource() }
    }

    func authorize(folder: URL) throws {
        let canonicalFolder = Self.canonical(folder)
        guard accessedFolders.contains(where: { $0.canonicalURL == canonicalFolder }) == false else {
            folder.stopAccessingSecurityScopedResource()
            return
        }

        let bookmark: Data
        do {
            bookmark = try folder.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            folder.stopAccessingSecurityScopedResource()
            throw error
        }
        // NSOpenPanel returns a URL whose security-scoped access is already active.
        // Retain that scope and balance it exactly once when access is revoked.
        accessedFolders.append(AccessedFolder(
            securityScopedURL: folder,
            canonicalURL: canonicalFolder
        ))
        bookmarks.append(bookmark)
        persistBookmarks()
        hasAuthorizedFolders = true
    }

    func revokeAll() {
        accessedFolders.forEach { $0.securityScopedURL.stopAccessingSecurityScopedResource() }
        accessedFolders.removeAll()
        bookmarks.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.bookmarksKey)
        UserDefaults.standard.removeObject(forKey: "AuthorizedLocalDocumentFolders")
        hasAuthorizedFolders = false
    }

    func hasAccess(to file: URL) -> Bool {
        accessedFolders.contains { Self.contains(file, in: $0.canonicalURL) }
    }

    static func contains(_ file: URL, in folder: URL) -> Bool {
        let fileComponents = canonical(file).pathComponents
        let folderComponents = canonical(folder).pathComponents
        return fileComponents.starts(with: folderComponents) && fileComponents.count > folderComponents.count
    }

    static func sameFolder(_ lhs: URL, _ rhs: URL) -> Bool {
        canonical(lhs) == canonical(rhs)
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func restoreBookmarks() {
        let storedBookmarks = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] ?? []
        var restoredFolders = Set<URL>()

        for storedBookmark in storedBookmarks {
            var isStale = false
            guard let resolvedURL = try? URL(
                resolvingBookmarkData: storedBookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                continue
            }

            let folder = Self.canonical(resolvedURL)
            guard restoredFolders.insert(folder).inserted,
                  resolvedURL.startAccessingSecurityScopedResource() else {
                continue
            }

            let bookmark: Data
            if isStale,
               let refreshed = try? folder.bookmarkData(
                   options: .withSecurityScope,
                   includingResourceValuesForKeys: nil,
                   relativeTo: nil
               ) {
                bookmark = refreshed
            } else {
                bookmark = storedBookmark
            }
            accessedFolders.append(AccessedFolder(
                securityScopedURL: resolvedURL,
                canonicalURL: folder
            ))
            bookmarks.append(bookmark)
        }

        persistBookmarks()
        hasAuthorizedFolders = accessedFolders.isEmpty == false
    }

    private func persistBookmarks() {
        UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
    }
#else
    let hasAuthorizedFolders = false
    init() {}
#endif
}

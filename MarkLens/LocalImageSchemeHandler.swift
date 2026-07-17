import Foundation
import UniformTypeIdentifiers
import WebKit

#if os(macOS)
final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    var documentURL: URL?
    var allowedImageURLs: Set<URL> = []
    var permissionDenied: ((URL) -> Void)?

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let sourceValue = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
              let sourceURL = URL(string: sourceValue),
              sourceURL.isFileURL,
              sourceURL.host?.isEmpty != false || sourceURL.host == "localhost",
              let documentRoot = documentURL?.deletingLastPathComponent() else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }

        // Canonicalize once and use that exact URL for validation and reading. The selected
        // document folder is treated as user-controlled, but not as concurrently adversarial.
        let canonicalURL = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        guard allowedImageURLs.contains(canonicalURL),
              LocalDocumentAccess.contains(canonicalURL, in: documentRoot),
              let imageType = UTType(filenameExtension: canonicalURL.pathExtension),
              Self.allowedImageTypes.contains(where: { imageType.conforms(to: $0) }) else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }

        do {
            let data = try Data(contentsOf: canonicalURL)
            guard let mimeType = LocalImageData.validatedMIMEType(for: data) else {
                urlSchemeTask.didFailWithError(URLError(.cannotDecodeContentData))
                return
            }
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            if Self.isPermissionError(error) {
                permissionDenied?(canonicalURL)
            }
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private static let allowedImageTypes: [UTType] = [
        .png,
        .jpeg,
        .gif,
        .webP,
    ]

    private static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == CocoaError.fileReadNoPermission.rawValue {
            return true
        }
        if error.domain == NSPOSIXErrorDomain, error.code == EACCES || error.code == EPERM {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPermissionError(underlying)
        }
        return false
    }
}
#endif

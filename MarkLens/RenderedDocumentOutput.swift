import Foundation
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct RenderedDocumentOutputRequest: Equatable, Identifiable {
    enum Destination: Equatable {
        case print
        case preview
        case pdf(URL)
    }

    let id = UUID()
    let destination: Destination
}

#if os(macOS)
enum RenderedDocumentExportFormat: String {
    case pdf
    case html

    init(contentType: UTType?) {
        self = contentType?.conforms(to: .html) == true ? .html : .pdf
    }

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .pdf
    }

    var contentType: UTType {
        switch self {
        case .pdf: .pdf
        case .html: .html
        }
    }

    var pathExtension: String {
        switch self {
        case .pdf: "pdf"
        case .html: "html"
        }
    }

    func normalizedURL(_ url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension(pathExtension)
    }
}

enum ExportPreferences {
    static let lastFormatKey = "LastRenderedDocumentExportFormat"

    static func rememberedFormat(in defaults: UserDefaults = .standard) -> RenderedDocumentExportFormat {
        RenderedDocumentExportFormat(storedValue: defaults.string(forKey: lastFormatKey))
    }

    static func remember(
        _ format: RenderedDocumentExportFormat,
        in defaults: UserDefaults = .standard
    ) {
        defaults.set(format.rawValue, forKey: lastFormatKey)
    }
}
#endif

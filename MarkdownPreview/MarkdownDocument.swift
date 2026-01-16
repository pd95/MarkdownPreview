//
//  MarkdownDocument.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated struct MarkdownDocument: FileDocument {
    var text: String
    let filename: String?

    init(text: String = "") {
        self.text = text
        self.filename = nil
    }

    static let readableContentTypes = [
        UTType.appMarkdown
    ]
    static let writableContentTypes = [
        UTType.appMarkdown
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
        self.filename = configuration.file.preferredFilename
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

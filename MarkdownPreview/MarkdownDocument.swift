//
//  MarkdownDocument.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

final class MarkdownDocument: ReferenceFileDocument {
    typealias Snapshot = String

    @Published var text: String
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

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
        self.filename = configuration.file.preferredFilename
    }

    func snapshot(contentType: UTType) throws -> String {
        text
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

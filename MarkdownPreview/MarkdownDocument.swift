//
//  MarkdownDocument.swift
//  MarkdownPreview
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated struct MarkdownDocument: FileDocument {
    var data: Data
    let filename: String?

    init(data: Data = Data()) {
        self.data = data
        self.filename = nil
    }

    static let readableContentTypes = [
        UTType.appMarkdown
    ]
    static let writableContentTypes: [UTType] = []

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        self.filename = configuration.file.preferredFilename
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        fatalError("Writing not supported!")
        //return .init(regularFileWithContents: data)
    }
}

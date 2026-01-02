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

    init(data: Data = Data()) {
        self.data = data
    }

    static let readableContentTypes = [
        UTType(importedAs: "net.daringfireball.markdown"),
    ]
    static let writableContentTypes: [UTType] = []

    var html: String {
        TemplateBuilder(data).html
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        fatalError("Writing not supported!")
        //return .init(regularFileWithContents: data)
    }
}

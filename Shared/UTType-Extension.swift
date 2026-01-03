//
//  UTType-Extension.swift
//  MarkdownPreview
//
//  Created by Philipp on 03.01.2026.
//

import UniformTypeIdentifiers

nonisolated extension UTType {
    static var appMarkdown: UTType {
        // Prefer a tag lookup (works when the system knows .md),
        // otherwise fall back to the well-known identifier.
        if let byTag = UTType(tag: "md", tagClass: .filenameExtension, conformingTo: .plainText) {
            return byTag
        }
        return UTType(importedAs: "net.daringfireball.markdown")
    }
}

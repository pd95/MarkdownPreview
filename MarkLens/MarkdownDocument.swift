//
//  MarkdownDocument.swift
//  MarkLens
//
//  Created by Philipp on 02.01.2026.
//

import SwiftUI
import Combine
import MarkdownPipeline
import UniformTypeIdentifiers

final class MarkdownDocument: ReferenceFileDocument {
    typealias Snapshot = String

    private(set) var text: String
    @Published private(set) var renderedHTML: String
    @Published private(set) var renderedResources: [HTMLResource]
    @Published private(set) var containsWikiLinks: Bool
    let filename: String?

    private static let renderingPipeline = MarkdownPipeline(
        plugins: [.wikiLinks(), .syntaxHighlighting(), .math(), .mermaid()]
    )

    init(text: String = "") {
        self.text = text
        self.filename = nil
        let rendering = Self.renderHTML(from: text, title: nil)
        self.renderedHTML = rendering.html
        self.renderedResources = rendering.resources
        self.containsWikiLinks = rendering.containsWikiLinks
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
        let rendering = Self.renderHTML(from: text, title: configuration.file.preferredFilename)
        self.renderedHTML = rendering.html
        self.renderedResources = rendering.resources
        self.containsWikiLinks = rendering.containsWikiLinks
    }

    func snapshot(contentType: UTType) throws -> String {
        text
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }

    func updateText(_ newText: String) {
        guard text != newText else {
            return
        }

        text = newText
        let rendering = Self.renderHTML(from: newText, title: filename)
        renderedHTML = rendering.html
        renderedResources = rendering.resources
        containsWikiLinks = rendering.containsWikiLinks
    }

    private static func renderHTML(
        from markdown: String,
        title: String?
    ) -> (html: String, containsWikiLinks: Bool, resources: [HTMLResource]) {
        let context = PipelineContext(title: title)
        if let document = try? renderingPipeline.renderHTML(from: .string(markdown), context: context) {
            return (document.html, document.containsWikiLinks, document.resources)
        }
        return (renderFailureHTML, false, [])
    }

    private static let renderFailureHTML = "<!doctype html><html><body><pre>Unable to render document.</pre></body></html>"
}

import Foundation

public struct MarkdownPipeline {
    public init() {}

    public static func defaultHTML(theme: PipelineContext.Theme = .auto) -> MarkdownPipeline {
        MarkdownPipeline()
    }

    public func render(input: MarkdownInput, context: PipelineContext) throws -> HTMLDocument {
        let title = context.title
        let html = "<!doctype html><html><head><meta charset=\"utf-8\"></head><body></body></html>"
        return HTMLDocument(html: html, title: title, baseURL: context.baseURL)
    }
}

enum MarkdownPipelineError: Error {
    case invalidStringEncoding
}

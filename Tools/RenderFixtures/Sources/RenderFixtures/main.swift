import Foundation
import MarkdownPipeline

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 2 else {
    print("usage: RenderFixtures <output-dir> <markdown-file>...")
    exit(64)
}

let outputDirectory = URL(filePath: String(arguments.first!))
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let pipeline = MarkdownPipeline(
    defaultTheme: .auto,
    plugins: [.wikiLinks(), .syntaxHighlighting(), .math(), .mermaid(), .customCSS()]
)

for path in arguments.dropFirst() {
    let inputURL = URL(filePath: String(path))
    let title = inputURL.lastPathComponent
    let document = try pipeline.renderHTML(
        from: .file(inputURL),
        context: PipelineContext(title: title, baseURL: inputURL.deletingLastPathComponent())
    )

    let outputURL = outputDirectory
        .appending(path: inputURL.deletingPathExtension().lastPathComponent)
        .appendingPathExtension("html")
    try document.write(to: outputURL)
    print(outputURL.path)
}

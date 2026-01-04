import Markdown

struct SwiftMarkdownParser {
    func parse(markdown: String) -> Document {
        Document(parsing: markdown)
    }
}

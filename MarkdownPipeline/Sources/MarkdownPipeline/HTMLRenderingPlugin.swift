import Foundation
import Markdown

struct HTMLPluginContribution {
    var styles = ""
    var scripts = ""
    var resources: [HTMLResource] = []
    var containsWikiLinks = false
    var overrideStyles: String?
}

struct HTMLTextEnvironment {
    let allowsWikiLinks: Bool
}

protocol HTMLRenderingPlugin: AnyObject, Sendable {
    var identifier: String { get }
    func makeSession(context: PipelineContext) -> any HTMLRenderingPluginSession
}

protocol HTMLRenderingPluginSession: AnyObject {
    func preprocess(_ markdown: String) -> String
    func restoreLiteral(_ text: String) -> String
    func renderStandaloneParagraph(_ text: String) -> String?
    func renderText(
        _ text: String,
        environment: HTMLTextEnvironment,
        next: (String) -> String
    ) -> String
    func renderCodeBlock(_ codeBlock: CodeBlock, restoredSource: String) -> String?
    func contribution() throws -> HTMLPluginContribution
}

extension HTMLRenderingPluginSession {
    func preprocess(_ markdown: String) -> String { markdown }
    func restoreLiteral(_ text: String) -> String { text }
    func renderStandaloneParagraph(_ text: String) -> String? { nil }

    func renderText(
        _ text: String,
        environment: HTMLTextEnvironment,
        next: (String) -> String
    ) -> String {
        next(text)
    }

    func renderCodeBlock(_ codeBlock: CodeBlock, restoredSource: String) -> String? { nil }
    func contribution() throws -> HTMLPluginContribution { HTMLPluginContribution() }
}

final class HTMLPluginCoordinator {
    private let sessions: [any HTMLRenderingPluginSession]

    init(plugins: [any HTMLRenderingPlugin], context: PipelineContext) {
        sessions = plugins.map { $0.makeSession(context: context) }
    }

    func preprocess(_ markdown: String) -> String {
        sessions.reduce(markdown) { result, session in
            session.preprocess(result)
        }
    }

    func restoreLiteral(_ text: String) -> String {
        sessions.reversed().reduce(text) { result, session in
            session.restoreLiteral(result)
        }
    }

    func renderStandaloneParagraph(_ text: String) -> String? {
        for session in sessions {
            if let rendered = session.renderStandaloneParagraph(text) {
                return rendered
            }
        }
        return nil
    }

    func renderText(_ text: String, allowsWikiLinks: Bool) -> String {
        renderText(text, environment: HTMLTextEnvironment(allowsWikiLinks: allowsWikiLinks), at: 0)
    }

    private func renderText(_ text: String, environment: HTMLTextEnvironment, at index: Int) -> String {
        guard index < sessions.count else {
            return text.encodedHTMLEntities()
        }
        return sessions[index].renderText(text, environment: environment) { remaining in
            self.renderText(remaining, environment: environment, at: index + 1)
        }
    }

    func renderCodeBlock(_ codeBlock: CodeBlock) -> String? {
        let source = restoreLiteral(codeBlock.code)
        for session in sessions {
            if let rendered = session.renderCodeBlock(codeBlock, restoredSource: source) {
                return rendered
            }
        }
        return nil
    }

    func contribution() throws -> HTMLPluginContribution {
        try sessions.reduce(into: HTMLPluginContribution()) { result, session in
            let contribution = try session.contribution()
            if contribution.styles.isEmpty == false {
                result.styles += contribution.styles + "\n"
            }
            if contribution.scripts.isEmpty == false {
                result.scripts += contribution.scripts + "\n"
            }
            result.resources += contribution.resources
            result.containsWikiLinks = result.containsWikiLinks || contribution.containsWikiLinks
            if let overrideStyles = contribution.overrideStyles {
                result.overrideStyles = overrideStyles
            }
        }
    }
}

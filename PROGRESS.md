# MarkdownPipeline Progress

This document tracks implementation progress against `PLAN.md` milestones.

## Milestone 1 — Create the Swift Package skeleton
Status: Done

- Package created at `MarkdownPipeline/`.
- `Package.swift` updated with platform constraints, resources, and `swift-markdown` dependency.
- Web resources copied into `MarkdownPipeline/Sources/MarkdownPipeline/Resources/WebResources/`.
- Build verified via `swift build`.

Relevant commits:
- Create MarkdownPipeline package with resources and stub API

## Milestone 2 — Define the core data structures
Status: Done

- `MarkdownInput`, `PipelineContext`, `HTMLDocument`, `MarkdownPipeline` implemented.
- `HTMLDocument.write(to:)` and `writeToTemporaryFile()` implemented.

Relevant commits:
- Create MarkdownPipeline package with resources and stub API

## Milestone 3 — Front Matter extraction (YAML)
Status: Done

- `FrontMatterExtractor` added with strict leading front matter parsing.
- Flat `key: value` parsing for `title` and `theme`.
- Unit tests cover no front matter, valid front matter, and malformed front matter.

Relevant commits:
- Extract YAML front matter and add coverage

## Milestone 4 — Parser stage using Swift Markdown AST
Status: Done

- `SwiftMarkdownParser` uses `Markdown.Document(parsing:)`.
- AST is kept internal to the module.

Relevant commits:
- Render Markdown to HTML with template-based emitter

## Milestone 5 — HTML emitter (baseline, no highlighting yet)
Status: Done

- `HTMLVisitor` ported from `Shared/MarkdownParser.swift` with sanitization, tables, lists, and paragraph handling.
- `HTMLEmitter` loads `template.html` and injects body HTML, CSS, and title.

Relevant commits:
- Render Markdown to HTML with template-based emitter

## Milestone 6 — Code block highlighting as a transform stage (JavaScriptCore)
Status: Done

- `HLJSHighlighter` implemented with JSContext and `highlight.min.js`.
- Language alias normalization and `NSCache` caching implemented.
- Code-block highlighting integrated via a pre-pass visitor and HTMLVisitor support.
- Theme CSS selection implemented in HTML emission.

Relevant commits:
- Highlight code blocks via highlight.js transform

Notes:
- Highlight cache is per `MarkdownPipeline` instance; consider a shared cache if needed.

## Milestone 7 — Public convenience API for your app + QuickLook
Status: Done

- `MarkdownPipeline.defaultHTML(theme:)` factory provided.
- `renderHTML(from:context:)` convenience method added.
- `HTMLDocument.writeToTemporaryFile()` already provided.

Relevant commits:
- Add convenience render API and pipeline tests

## Milestone 8 — Replace current implementation in the main project
Status: Done

- `MarkdownPreview` and `QuickLookPreview_macOS` now render via `MarkdownPipeline`.
- Legacy `TemplateBuilder` stays as a fallback behind a local feature flag.

Relevant commits:
- Adopt MarkdownPipeline in app and QuickLook targets

## Milestone 9 — Tests & golden fixtures
Status: Done

- Tests added for front matter, sanitization, HTML rendering, and convenience APIs.
- Fixture-based test added using `sample.md` (pipeline-level assertions).
- Golden/fixture-style tests now present via fixtures.

Relevant commits:
- Extract YAML front matter and add coverage
- Add convenience render API and pipeline tests
- Add HTML rendering suite for pipeline coverage
- Group front matter tests into a suite
- Add convenience API test suite
- Add optional code highlighting toggle and test
- Add fixture-based pipeline tests

## Commit → Milestone Map

- Create MarkdownPipeline package with resources and stub API → Milestones 1–2
- Extract YAML front matter and add coverage → Milestone 3 (and tests for Milestone 9)
- Render Markdown to HTML with template-based emitter → Milestones 4–5
- Highlight code blocks via highlight.js transform → Milestone 6
- Add convenience render API and pipeline tests → Milestone 7 (and tests for Milestone 9)
- Add HTML rendering suite for pipeline coverage → Milestone 9
- Group front matter tests into a suite → Milestone 9
- Add convenience API test suite → Milestones 7 & 9
- Add optional code highlighting toggle and test → Milestones 6 & 9
- Update swift-markdown dependency source and version → Maintenance
- Add fixture-based pipeline tests → Milestone 9

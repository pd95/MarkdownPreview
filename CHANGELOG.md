# Changelog

## 1.3.0

- Added LaTeX math rendering with KaTeX.
- Added Mermaid diagram rendering for fenced code blocks.
- Added appearance settings for custom preview styles, including font family, font size, line height, content width, and custom CSS.
- Improved preview typography scaling so custom font sizes apply consistently throughout rendered documents.

## 1.2.0

- Added support for local Markdown links and linked images, resolved relative to the current document.
- Added privacy-focused folder access prompts with persistent permissions that can be managed in Settings.
- Added wiki-style links using `[[note]]`, `[[folder/note]]`, and `[[note|Display text]]` syntax.
- Added recursive wiki-page discovery within a selected folder, including a searchable chooser for duplicate names.
- Added in-place wiki browsing with Back and Forward navigation while keeping linked pages read-only.

## 1.1.0

- Renamed the app from MarkdownPreview to MarkLens.
- Added automated Xcode Cloud release builds.
- Added Developer ID notarization for direct downloads.
- Added GitHub Release uploads for release candidate and final tags.
- Added release tag and commit metadata to the About panel.

## 1.0.6

- Added search in the rendered Markdown preview and raw editor.
- Open Markdown links in the browser.
- Improved rendering performance.
- Fixed bugs in Markdown preview and editing workflows.

## 1.0.5

- Added support for embedded images using `data:image` URLs.

## 1.0.4

- Added printing and page setup support, including macOS PDF generation through the print workflow.
- Added syntax-highlighted Markdown rendering through the shared Markdown pipeline.
- Added copy buttons for rendered code blocks.
- Added raw Markdown editing inside the app.
- Improved Quick Look preview rendering and shared app/extension resources.

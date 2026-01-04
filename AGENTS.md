# Repository Guidelines

## Project Structure & Module Organization
- `MarkdownPreview/` contains the main SwiftUI app target (document handling, views, and app entry point).
- `QuickLookPreview/` hosts the Quick Look extension used for markdown previews.
- `Shared/` holds shared Swift code (UTType helpers, app constants).
- `Icon/` contains source icon assets and design files.
- `MarkdownPreview.xcodeproj/` is the Xcode project workspace and build metadata.

## Build, Test, and Development Commands
- `open MarkdownPreview.xcodeproj` to work in Xcode (recommended for running and debugging).
- `xcodebuild -project MarkdownPreview.xcodeproj -scheme MarkdownPreview -configuration Debug build` builds the app from the CLI.
- `xcodebuild -project MarkdownPreview.xcodeproj -scheme QuickLookPreview -configuration Debug build` builds the Quick Look extension.
- There are currently no automated tests wired into the project.
- If `xcodebuild` crashes during device discovery, reset simulator device sets:
  `for DEVICES_SET in playgrounds previews ib test default; do xcrun simctl --set $DEVICES_SET delete all; done`
- To test Quick Look on macOS from the CLI after building, run:
  `qlmanage -r` and `qlmanage -p README.md`.

## Coding Style & Naming Conventions
- Swift code uses 4-space indentation and standard Swift formatting as applied by Xcode.
- Types and protocols use UpperCamelCase (e.g., `MarkdownDocument`); properties and functions use lowerCamelCase (e.g., `stringFromResource`).
- Keep file names aligned with their primary type (e.g., `MarkdownWebView.swift`).
- Aim for best-practice Swift implementations on both iOS and macOS (modern APIs, clear concurrency boundaries, and platform-appropriate design).

## Testing Guidelines
- No test targets are present. If adding tests, follow Xcode conventions with `*Tests` targets and place files under a `Tests/` group in the project.
- Name tests with `test` prefixes (e.g., `testRendersMarkdownLinks`) and keep coverage focused on parser behavior and template rendering.
- Raw HTML is sanitized for GFM-disallowed tags in `MarkdownPipeline/Sources/MarkdownPipeline/HTMLVisitor.swift`; keep tests aligned with that behavior.

## Commit & Pull Request Guidelines
- Recent commits use short, imperative summaries (e.g., "Remove print() and disable \"drawsBackground\"").
- Keep commits focused on a single change area.
- Use multi-line commit messages: a short title plus 2–4 bullets describing the main changes.
- PRs should include a brief description, steps to validate, and screenshots for UI changes in the preview rendering.
- Link related issues when applicable and call out any manual testing performed in Xcode.

## Security & Configuration Tips
- The markdown parser sanitizes link and image URLs; be cautious when changing `HTMLVisitor` link handling.

## Testing Notes
- Prefer `@Suite` groupings in `MarkdownPipelineTests` for related behaviors (e.g., Front Matter, HTML Rendering, Convenience API).
- Keep HTML rendering tests at the pipeline level (string input → HTML output) instead of constructing ASTs directly.
- Avoid code highlighting assertions in HTML rendering tests unless explicitly requested; keep those tests separate.

## Helper Documents
- `PROGRESS.md` tracks MarkdownPipeline progress against `PLAN.md`.

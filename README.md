# MarkdownPreview

A SwiftUI app for macOS and iOS, plus a Quick Look extension for previewing Markdown files.

## Features
- Live rendering of Markdown documents in a lightweight SwiftUI interface.
- Bundled HTML/CSS templates for consistent styling.
- Quick Look extension for Finder previews.

## Requirements
- Xcode 26.2+
- macOS and iOS devices with SwiftUI support

## Build
```sh
open MarkdownPreview.xcodeproj
```

CLI builds:
```sh
xcodebuild -project MarkdownPreview.xcodeproj -scheme MarkdownPreview -configuration Debug build
xcodebuild -project MarkdownPreview.xcodeproj -scheme QuickLookPreview -configuration Debug build
```

## Project Layout
- `MarkdownPreview/` app sources
- `QuickLookPreview/` Quick Look extension
- `Shared/` shared Swift code and web assets

## License
MIT. See `LICENSE`.

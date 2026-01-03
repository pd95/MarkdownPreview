# MarkdownPreview

View Markdown documents in iOS and macOS (plus a Quick Look extension for fast previews in Finder!).

## Features
- Markdown rendering with a lightweight SwiftUI UI app.
- Bundled HTML/CSS/JS templates for consistent styling.
- Quick Look extension for Finder previews.

## Requirements
- Xcode 26
- macOS 15.6 or an iOS 18.6 device

## Build
Open the project:
```sh
open MarkdownPreview.xcodeproj
```

Build from the CLI:
```sh
xcodebuild -project MarkdownPreview.xcodeproj -scheme MarkdownPreview -configuration Debug build
```

## Project Layout
- `MarkdownPreview/` app sources
- `QuickLookPreview_macOS/` Quick Look extension
- `Shared/` shared Swift code and web assets

## License
MIT. See `LICENSE`.

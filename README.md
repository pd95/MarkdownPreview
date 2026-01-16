# MarkdownPreview

View Markdown documents in iOS and macOS (plus a Quick Look extension for fast previews in Finder!).

## Features
- Markdown rendering with a lightweight SwiftUI app.
- Raw markdown editor with toolbar shortcuts for quick edits.
- Bundled HTML/CSS/JS templates for consistent styling.
- Copy buttons on code blocks.
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

## Future Tasks
- Consider adding a custom print panel accessory for header/footer toggles and margin presets.

## License
MIT. See `LICENSE`.

## Third-Party Notices
See `THIRD_PARTY_NOTICES`.

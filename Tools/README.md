# Rendering Fixtures

Use this tooling to inspect Markdown HTML/CSS/JavaScript changes without launching the app.

Install the Node dependencies once:

```bash
npm install --prefix Tools
npm --prefix Tools exec playwright install chromium  # Linux/container default
npm --prefix Tools exec playwright install webkit    # macOS default
```

```bash
Tools/render-fixtures.sh
```

By default, the script renders the UI-test markdown fixtures into `tmp/rendered/` and writes screenshots to `tmp/screenshots/`.

You can render specific markdown files by passing paths:

```bash
Tools/render-fixtures.sh MarkLensUITests/Fixtures/search-sample.md
```

The Playwright pass injects the bundled `highlight.min.js` before capturing screenshots, so Linux-rendered HTML gets browser-side syntax highlighting for visual inspection.

## Matching macOS Fonts

Linux Chromium cannot render `system-ui` exactly like macOS unless the same fonts are available. To make screenshots closer to the app’s macOS rendering, place local San Francisco font files in `Tools/Fonts/`.

Example filenames detected by the renderer:

- `SF-Pro-Text-Regular.otf`
- `SF-Pro-Text-Semibold.otf`
- `SF-Mono-Regular.otf`
- `SF-Mono-Semibold.otf`

These files are ignored by git. The font override is injected only during Playwright screenshots; it does not change the generated HTML or production CSS.

Linux and macOS still rasterize text differently. For screenshots that should visually match the macOS app more closely, run this tooling on macOS instead of in the Linux container.

By default, the screenshot pass uses WebKit on macOS and Chromium elsewhere:

```bash
Tools/render-fixtures.sh
```

You can override the browser explicitly:

```bash
RENDER_FIXTURES_BROWSER=chromium Tools/render-fixtures.sh
RENDER_FIXTURES_BROWSER=webkit Tools/render-fixtures.sh
```

Screenshots are generated as full-page captures using these CSS width presets:

- `mac-preview`: `1000px` wide, minimum viewport height `760px`
- `narrow`: `720px` wide, minimum viewport height `760px`

The page is captured to its full rendered height, but short documents still use at least the minimum viewport height. Screenshots use `deviceScaleFactor: 2`, so PNG pixel dimensions are doubled. This keeps the layout comparable to app-window point sizes while producing Retina-style screenshots.

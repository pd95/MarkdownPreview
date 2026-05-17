# Local Screenshot Fonts

Put local font files here if you want Linux/Chromium screenshots to match macOS more closely.

This directory is intentionally ignored except for this README. Do not commit licensed system fonts.

The renderer detects common San Francisco font names, for example:

- `SF-Pro-Text-Regular.otf`
- `SF-Pro-Text-Semibold.otf`
- `SF-Mono-Regular.otf`
- `SF-Mono-Semibold.otf`

When these files are present, `Tools/render-fixtures.sh` injects them only into the Playwright screenshot page. The app CSS and generated HTML are unchanged.

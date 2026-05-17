#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_DIR="$ROOT/tmp/rendered"
DEFAULT_BROWSER="chromium"
if [ "$(uname -s)" = "Darwin" ]; then
    DEFAULT_BROWSER="webkit"
fi

if [ ! -d "$ROOT/Tools/node_modules/@playwright/test" ]; then
    cat >&2 <<EOF
Missing Playwright dependency.

Install the rendering-tool dependencies once with:

    npm install --prefix "$ROOT/Tools"
    npm --prefix "$ROOT/Tools" exec playwright install $DEFAULT_BROWSER

Then rerun:

    Tools/render-fixtures.sh
EOF
    exit 69
fi

if [ "$#" -eq 0 ]; then
    set -- \
        "$ROOT/MarkdownPreviewUITests/Fixtures/sample.md" \
        "$ROOT/MarkdownPreviewUITests/Fixtures/search-sample.md"
fi

mkdir -p "$HTML_DIR" "$ROOT/tmp/screenshots"
rm -f "$HTML_DIR"/*.html

swift run --package-path "$ROOT/Tools/RenderFixtures" RenderFixtures "$HTML_DIR" "$@"
node "$ROOT/Tools/render-fixtures-playwright.js"

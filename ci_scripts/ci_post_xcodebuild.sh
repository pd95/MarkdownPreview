#!/bin/zsh
set -euo pipefail

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-pd95/MarkLens}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
GITHUB_UPLOADS_URL="${GITHUB_UPLOADS_URL:-https://uploads.github.com}"
APP_NAME="${APP_NAME:-MarkLens}"
SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
CHANGELOG_FILE="${CHANGELOG_FILE:-$REPOSITORY_ROOT/CHANGELOG.md}"

if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]]; then
    echo "Not an archive action; skipping GitHub Release upload."
    exit 0
fi

if [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]]; then
    echo "xcodebuild did not finish successfully; skipping GitHub Release upload."
    exit 0
fi

if [[ -z "${CI_TAG:-}" ]]; then
    echo "No CI_TAG set; skipping GitHub Release upload."
    exit 0
fi

TAG_NAME="${CI_TAG#refs/tags/}"
TAG_VERSION="${TAG_NAME#v}"
BASE_VERSION="${TAG_VERSION%%-*}"

if [[ "$TAG_VERSION" == *-test* ]]; then
    echo "Test tag '$TAG_NAME'; skipping GitHub Release upload."
    exit 0
fi

if [[ -z "${GITHUB_RELEASE_TOKEN:-}" ]]; then
    echo "error: GITHUB_RELEASE_TOKEN is not set."
    echo "Add it as a secret environment variable in the Xcode Cloud release workflow."
    exit 1
fi

ARTIFACT_PATH="${CI_DEVELOPER_ID_SIGNED_APP_PATH:-}"
if [[ -z "$ARTIFACT_PATH" || ! -e "$ARTIFACT_PATH" ]]; then
    echo "error: CI_DEVELOPER_ID_SIGNED_APP_PATH is empty or does not exist."
    echo "This upload script expects the Xcode Cloud archive to export a Developer ID signed Mac app."
    exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/marklens-release.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ASSET_NAME="${APP_NAME}-${TAG_NAME}.zip"
ASSET_PATH="$WORK_DIR/$ASSET_NAME"

APP_PATH="$ARTIFACT_PATH"
if [[ -d "$ARTIFACT_PATH" && "$ARTIFACT_PATH" != *.app ]]; then
    APP_PATH="$ARTIFACT_PATH/$APP_NAME.app"
fi

if [[ ! -d "$APP_PATH" || "$APP_PATH" != *.app ]]; then
    echo "error: Could not find $APP_NAME.app in CI_DEVELOPER_ID_SIGNED_APP_PATH."
    echo "CI_DEVELOPER_ID_SIGNED_APP_PATH=$ARTIFACT_PATH"
    exit 1
fi

echo "Packaging $APP_PATH as $ASSET_NAME"
if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --keepParent "$APP_PATH" "$ASSET_PATH"
elif command -v zip >/dev/null 2>&1; then
    (cd "$(dirname "$APP_PATH")" && zip -qry "$ASSET_PATH" "$(basename "$APP_PATH")")
else
    echo "error: Could not find ditto or zip to create $ASSET_NAME"
    exit 1
fi

IS_PRERELEASE=false
if [[ "$TAG_VERSION" == *-* ]]; then
    IS_PRERELEASE=true
fi

RELEASE_NAME="$APP_NAME $TAG_NAME"
RELEASE_NOTES=""
if [[ -f "$CHANGELOG_FILE" ]]; then
    RELEASE_NOTES="$(python3 - "$CHANGELOG_FILE" "$BASE_VERSION" <<'PY'
import re
import sys

path, version = sys.argv[1:]
heading = re.compile(r"^##\s+\[?" + re.escape(version) + r"\]?\s*$")
next_heading = re.compile(r"^##\s+")

with open(path, encoding="utf-8") as handle:
    lines = handle.readlines()

start = None
for index, line in enumerate(lines):
    if heading.match(line.strip()):
        start = index + 1
        break

if start is None:
    sys.exit(0)

end = len(lines)
for index in range(start, len(lines)):
    if next_heading.match(lines[index].strip()):
        end = index
        break

notes = "".join(lines[start:end]).strip()
if notes:
    print(notes)
PY
)"
fi

if [[ -z "$RELEASE_NOTES" ]]; then
    RELEASE_NOTES="Automated Xcode Cloud release for $TAG_NAME."
fi

if [[ -n "${CI_BUILD_URL:-}" ]]; then
    RELEASE_NOTES="$RELEASE_NOTES"$'\n\n'"Xcode Cloud build: $CI_BUILD_URL"
fi

auth_header="Authorization: Bearer $GITHUB_RELEASE_TOKEN"
api_version_header="X-GitHub-Api-Version: 2022-11-28"
accept_header="Accept: application/vnd.github+json"

release_json="$WORK_DIR/release.json"
release_status="$WORK_DIR/release.status"

echo "Looking up GitHub Release for $TAG_NAME"
http_code="$(curl --silent --show-error --location \
    --header "$accept_header" \
    --header "$auth_header" \
    --header "$api_version_header" \
    --output "$release_json" \
    --write-out "%{http_code}" \
    "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/releases/tags/$TAG_NAME")"

if [[ "$http_code" == "404" ]]; then
    echo "Creating GitHub Release for $TAG_NAME"
    python3 - "$WORK_DIR/create-release.json" "$TAG_NAME" "$RELEASE_NAME" "$RELEASE_NOTES" "$IS_PRERELEASE" <<'PY'
import json
import sys

output_path, tag_name, name, body, prerelease = sys.argv[1:]
is_prerelease = prerelease == "true"
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "tag_name": tag_name,
            "name": name,
            "body": body,
            "draft": False,
            "prerelease": is_prerelease,
            "generate_release_notes": True,
            "make_latest": "false" if is_prerelease else "true",
        },
        handle,
    )
PY

    http_code="$(curl --silent --show-error --location \
        --request POST \
        --header "$accept_header" \
        --header "$auth_header" \
        --header "$api_version_header" \
        --header "Content-Type: application/json" \
        --data @"$WORK_DIR/create-release.json" \
        --output "$release_json" \
        --write-out "%{http_code}" \
        "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/releases")"
fi

if [[ "$http_code" -lt 200 || "$http_code" -gt 299 ]]; then
    echo "error: GitHub release lookup/create failed with HTTP $http_code"
    python3 -m json.tool "$release_json" || cat "$release_json"
    exit 1
fi

release_id="$(python3 - "$release_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("id", ""))
PY
)"
if [[ -z "$release_id" || "$release_id" == "null" ]]; then
    echo "error: GitHub release response did not include an id."
    python3 -m json.tool "$release_json" || cat "$release_json"
    exit 1
fi

echo "Checking for existing release asset named $ASSET_NAME"
assets_json="$WORK_DIR/assets.json"
http_code="$(curl --silent --show-error --location \
    --header "$accept_header" \
    --header "$auth_header" \
    --header "$api_version_header" \
    --output "$assets_json" \
    --write-out "%{http_code}" \
    "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/releases/$release_id/assets")"

if [[ "$http_code" -lt 200 || "$http_code" -gt 299 ]]; then
    echo "error: GitHub asset lookup failed with HTTP $http_code"
    python3 -m json.tool "$assets_json" || cat "$assets_json"
    exit 1
fi

existing_asset_id="$(python3 - "$assets_json" "$ASSET_NAME" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    assets = json.load(handle)

for asset in assets:
    if asset.get("name") == sys.argv[2]:
        print(asset.get("id", ""))
        break
PY
)"
if [[ -n "$existing_asset_id" ]]; then
    echo "Deleting existing release asset $ASSET_NAME"
    http_code="$(curl --silent --show-error --location \
        --request DELETE \
        --header "$accept_header" \
        --header "$auth_header" \
        --header "$api_version_header" \
        --output "$release_status" \
        --write-out "%{http_code}" \
        "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/releases/assets/$existing_asset_id")"

    if [[ "$http_code" -lt 200 || "$http_code" -gt 299 ]]; then
        echo "error: GitHub asset deletion failed with HTTP $http_code"
        cat "$release_status"
        exit 1
    fi
fi

echo "Uploading $ASSET_NAME to GitHub Release $TAG_NAME"
upload_json="$WORK_DIR/upload.json"
http_code="$(curl --silent --show-error --location \
    --request POST \
    --header "$accept_header" \
    --header "$auth_header" \
    --header "$api_version_header" \
    --header "Content-Type: application/zip" \
    --data-binary @"$ASSET_PATH" \
    --output "$upload_json" \
    --write-out "%{http_code}" \
    "$GITHUB_UPLOADS_URL/repos/$GITHUB_REPOSITORY/releases/$release_id/assets?name=$ASSET_NAME")"

if [[ "$http_code" -lt 200 || "$http_code" -gt 299 ]]; then
    echo "error: GitHub asset upload failed with HTTP $http_code"
    python3 -m json.tool "$upload_json" || cat "$upload_json"
    exit 1
fi

browser_download_url="$(python3 - "$upload_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("browser_download_url", ""))
PY
)"
echo "Uploaded GitHub Release asset: $browser_download_url"

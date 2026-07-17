#!/usr/bin/env bash
# Compare upstream y1_launcher releases with published jj_auto ROM releases.
# Usage: prepare-build-matrix.sh <all|new_only>
#
# Writes releases.json and, when GITHUB_OUTPUT is set:
#   has_new, matrix, latest_tag
set -euo pipefail

MODE="${1:-new_only}"
ROM_REPO="${ROM_REPO:-ryan-specter/jj_y2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$MODE" != "all" ] && [ "$MODE" != "new_only" ]; then
    echo "usage: $0 <all|new_only>" >&2
    exit 1
fi

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: missing required command: $1" >&2
        exit 1
    }
}

require_cmd python3

"$SCRIPT_DIR/list-launcher-releases.sh" > releases.json

python3 - "$MODE" "$ROM_REPO" <<'PY'
import json
import os
import sys
import urllib.request

mode, rom_repo = sys.argv[1:3]
with open("releases.json", encoding="utf-8") as handle:
    upstream = json.load(handle)

token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if not token:
    raise SystemExit("GITHUB_TOKEN is required")

headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/vnd.github+json",
    "User-Agent": "jj-launcher-rom-build/1.0",
}

existing = set()
page = 1
while True:
    url = f"https://api.github.com/repos/{rom_repo}/releases?per_page=100&page={page}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request) as response:
        batch = json.load(response)

    if not batch:
        break

    for release in batch:
        tag_name = release.get("tag_name", "")
        if tag_name.startswith("launcher-"):
            existing.add(tag_name.removeprefix("launcher-"))

    page += 1

new_items = [item for item in upstream if item["tag"] not in existing]
build_items = upstream if mode == "all" else new_items
has_new = len(build_items) > 0
latest_tag = upstream[-1]["tag"] if upstream else ""

matrix = [
    {
        "tag": item["tag"],
        "name": item["name"],
        "apk_name": item["apk_name"],
        "apk_url": item["apk_url"],
    }
    for item in build_items
]

print(f"Mode: {mode}")
print(f"Upstream releases: {[item['tag'] for item in upstream]}")
print(f"Published ROM releases: {sorted(existing)}")
print(f"Build targets: {[item['tag'] for item in build_items]}")

github_output = os.environ.get("GITHUB_OUTPUT")
if github_output:
    with open(github_output, "a", encoding="utf-8") as handle:
        handle.write(f"has_new={'true' if has_new else 'false'}\n")
        handle.write(f"matrix={json.dumps(matrix)}\n")
        handle.write(f"latest_tag={latest_tag}\n")

if not has_new:
    print("No ROM builds required.")
PY

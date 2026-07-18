#!/usr/bin/env bash
# Compare upstream launcher releases with published ROM releases.
# Usage: prepare-build-matrix.sh <all|new_only>
#
# Env:
#   ROM_REPO              Where ROM releases are published (default: this fork)
#   LAUNCHER_REPO         Upstream APK source (default: ismileblue/y1_launcher)
#   MIN_LAUNCHER_VERSION  Only build tags >= this semver (default: 0.11.2)
#                         Y2 MicroSD / StoragePaths support starts at 0.11.2.
#
# Writes releases.json and, when GITHUB_OUTPUT is set:
#   has_new, matrix, latest_tag
set -euo pipefail

MODE="${1:-new_only}"
ROM_REPO="${ROM_REPO:-ryan-specter/jj_auto}"
LAUNCHER_REPO="${LAUNCHER_REPO:-ismileblue/y1_launcher}"
MIN_LAUNCHER_VERSION="${MIN_LAUNCHER_VERSION:-0.11.2}"
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

export LAUNCHER_REPO
"$SCRIPT_DIR/list-launcher-releases.sh" > releases.json

python3 - "$MODE" "$ROM_REPO" "$MIN_LAUNCHER_VERSION" <<'PY'
import json
import os
import re
import sys
import urllib.request

mode, rom_repo, min_version = sys.argv[1:4]
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


def parse_semver(tag: str):
    """Return (major, minor, patch) or None if not a version-like tag."""
    raw = tag.strip()
    if raw.startswith("launcher-"):
        raw = raw[len("launcher-") :]
    if raw.startswith("v") or raw.startswith("V"):
        raw = raw[1:]
    # Allow tags like 0.11.2, 0.11.2-y2, 0.11
    m = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?", raw)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)


min_tuple = parse_semver(min_version)
if min_tuple is None:
    raise SystemExit(f"invalid MIN_LAUNCHER_VERSION: {min_version}")

filtered = []
skipped = []
for item in upstream:
    ver = parse_semver(item["tag"])
    if ver is None or ver < min_tuple:
        skipped.append(item["tag"])
        continue
    filtered.append(item)

print(f"MIN_LAUNCHER_VERSION={min_version} -> skipped pre-Y2 tags: {skipped}")
upstream = filtered

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
print(f"ROM_REPO: {rom_repo}")
print(f"Upstream releases (>= {min_version}): {[item['tag'] for item in upstream]}")
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

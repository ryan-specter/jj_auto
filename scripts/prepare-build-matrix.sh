#!/usr/bin/env bash
# Build a flattened ROM job matrix from launcher APK releases.
# Usage: prepare-build-matrix.sh <all|new_only>
#
# Rules (upstreamable to ismileblue/y1_launcher):
#   version <  Y2_MIN (default 0.11.2)
#       → APK from ismileblue/y1_launcher, ROM types a + b only (Y1)
#   version >= Y2_MIN
#       → APK from this repo when not ismileblue; types a + b + y2
#       → when GITHUB_REPOSITORY is ismileblue/y1_launcher: APK from self, types a+b+y2
#
# Env:
#   ROM_REPO              Where ROM releases are published
#   Y1_LAUNCHER_REPO      Source of pre-Y2 APKs (default: ismileblue/y1_launcher)
#   Y2_LAUNCHER_REPO      Source of Y2-capable APKs (default: GITHUB_REPOSITORY / ryan-specter/jj_auto)
#   Y2_MIN_VERSION        First version that may receive type y2 (default: 0.11.2)
#
# Writes releases.json and GITHUB_OUTPUT: has_new, matrix, release_matrix, latest_tag
set -euo pipefail

MODE="${1:-new_only}"
ROM_REPO="${ROM_REPO:-${GITHUB_REPOSITORY:-ryan-specter/jj_auto}}"
Y1_LAUNCHER_REPO="${Y1_LAUNCHER_REPO:-ismileblue/y1_launcher}"
Y2_MIN_VERSION="${Y2_MIN_VERSION:-0.11.2}"
# On ismileblue, Y2 APKs come from the same repo; on the fork, from this fork's releases.
if [ -z "${Y2_LAUNCHER_REPO:-}" ]; then
    if [ "${GITHUB_REPOSITORY:-}" = "ismileblue/y1_launcher" ]; then
        Y2_LAUNCHER_REPO="ismileblue/y1_launcher"
    else
        Y2_LAUNCHER_REPO="${GITHUB_REPOSITORY:-ryan-specter/jj_auto}"
    fi
fi
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

export Y1_LAUNCHER_REPO Y2_LAUNCHER_REPO

python3 - "$MODE" "$ROM_REPO" "$Y1_LAUNCHER_REPO" "$Y2_LAUNCHER_REPO" "$Y2_MIN_VERSION" <<'PY'
import json
import os
import re
import sys
import urllib.request

mode, rom_repo, y1_repo, y2_repo, y2_min = sys.argv[1:6]
token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if not token:
    raise SystemExit("GITHUB_TOKEN is required")

headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/vnd.github+json",
    "User-Agent": "jj-launcher-rom-build/1.0",
}


def parse_semver(tag: str):
    raw = tag.strip()
    if raw.startswith("launcher-"):
        raw = raw[len("launcher-") :]
    if raw.startswith("v") or raw.startswith("V"):
        raw = raw[1:]
    m = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?", raw)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)


def fetch_apk_releases(repo: str):
    url = f"https://api.github.com/repos/{repo}/releases?per_page=100"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request) as response:
        releases = json.load(response)
    items = []
    for release in releases:
        if release.get("draft"):
            continue
        apk_assets = [
            a for a in release.get("assets", [])
            if a.get("name", "").startswith("app-release") and a.get("name", "").endswith(".apk")
        ]
        if not apk_assets:
            continue
        asset = apk_assets[0]
        items.append({
            "tag": release["tag_name"],
            "name": release.get("name") or release["tag_name"],
            "apk_name": asset["name"],
            "apk_url": asset["browser_download_url"],
            "body": release.get("body") or "",
            "html_url": release.get("html_url", ""),
            "published_at": release.get("published_at", ""),
            "launcher_repo": repo,
        })
    return items


y2_min_tuple = parse_semver(y2_min)
if y2_min_tuple is None:
    raise SystemExit(f"invalid Y2_MIN_VERSION: {y2_min}")

# Catalog: Y1-only tags from upstream ismileblue; Y2-capable from fork/self.
y1_items = fetch_apk_releases(y1_repo)
y2_items = fetch_apk_releases(y2_repo)

by_tag = {}
for item in y1_items:
    ver = parse_semver(item["tag"])
    if ver is None:
        continue
    if ver < y2_min_tuple:
        item = dict(item)
        item["types"] = ["a", "b"]
        by_tag[item["tag"]] = item

for item in y2_items:
    ver = parse_semver(item["tag"])
    if ver is None:
        continue
    if ver >= y2_min_tuple:
        item = dict(item)
        item["types"] = ["a", "b", "y2"]
        by_tag[item["tag"]] = item

catalog = sorted(by_tag.values(), key=lambda i: i.get("published_at") or i["tag"])

# Persist merged catalog for release notes.
with open("releases.json", "w", encoding="utf-8") as handle:
    json.dump(catalog, handle, ensure_ascii=False)

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

new_items = [item for item in catalog if item["tag"] not in existing]
build_items = catalog if mode == "all" else new_items
has_new = len(build_items) > 0
latest_tag = catalog[-1]["tag"] if catalog else ""

# Flatten to one GHA job per (tag, type).
flat = []
for item in build_items:
    for rom_type in item["types"]:
        flat.append({
            "tag": item["tag"],
            "name": item["name"],
            "apk_name": item["apk_name"],
            "apk_url": item["apk_url"],
            "launcher_repo": item["launcher_repo"],
            "type": rom_type,
            "types": item["types"],
        })

release_matrix = [
    {
        "tag": item["tag"],
        "name": item["name"],
        "types": item["types"],
        "include_y2": "y2" in item["types"],
    }
    for item in build_items
]

print(f"Mode: {mode}")
print(f"ROM_REPO: {rom_repo}")
print(f"Y1_LAUNCHER_REPO: {y1_repo} (tags < {y2_min} → types a,b)")
print(f"Y2_LAUNCHER_REPO: {y2_repo} (tags >= {y2_min} → types a,b,y2)")
print(f"Catalog tags: {[(i['tag'], i['types'], i['launcher_repo']) for i in catalog]}")
print(f"Published ROM releases: {sorted(existing)}")
print(f"Build jobs: {[(j['tag'], j['type']) for j in flat]}")

github_output = os.environ.get("GITHUB_OUTPUT")
if github_output:
    with open(github_output, "a", encoding="utf-8") as handle:
        handle.write(f"has_new={'true' if has_new else 'false'}\n")
        handle.write(f"matrix={json.dumps(flat)}\n")
        handle.write(f"release_matrix={json.dumps(release_matrix)}\n")
        handle.write(f"latest_tag={latest_tag}\n")

if not has_new:
    print("No ROM builds required.")
PY

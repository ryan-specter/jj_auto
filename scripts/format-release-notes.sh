#!/usr/bin/env bash
# Format upstream JJ Launcher release notes for a ROM release page.
# Usage: format-release-notes.sh <releases.json> <tag> > RELEASE_NOTES.md
set -euo pipefail

RELEASES_JSON="${1:-}"
TAG="${2:-}"

if [ -z "$RELEASES_JSON" ] || [ -z "$TAG" ]; then
    echo "usage: $0 <releases.json> <tag>" >&2
    exit 1
fi

python3 - "$RELEASES_JSON" "$TAG" <<'PY'
import json
import sys

releases_path, tag = sys.argv[1:3]
with open(releases_path, encoding="utf-8") as handle:
    releases = json.load(handle)

match = next((item for item in releases if item["tag"] == tag), None)
if not match:
    raise SystemExit(f"release tag not found: {tag}")

body = (match.get("body") or "").strip()
upstream_name = match.get("name") or tag
upstream_url = match.get("html_url") or "https://github.com/ismileblue/y1_launcher/releases"
apk_name = match.get("apk_name") or "app-release.apk"

print(f"# JJ Launcher ROM — {tag}")
print()
print("Flashable Innioasis Y1 firmware that boots directly into JJ Launcher.")
print("No Rockbox, no stock launcher, and no post-flash ADB steps required.")
print()
print("## Downloads")
print()
print("- `rom.zip` — Type A (devices that shipped with stock firmware **2.0.0 or later**)")
print("- `rom_type_b.zip` — Type B (devices that shipped with stock firmware **prior to 2.0.0**)")
print()
print(f"- Bundled launcher APK: `{apk_name}`")
print()
print("## Upstream JJ Launcher release")
print()
print(f"- Release: [{upstream_name}]({upstream_url})")
print(f"- Source repository: [ismileblue/y1_launcher](https://github.com/ismileblue/y1_launcher)")
print()
print("### Changelog")
print()
if body:
    print(body)
else:
    print("_No release notes were published for this upstream release._")
PY

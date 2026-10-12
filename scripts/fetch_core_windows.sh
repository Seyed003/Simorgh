#!/usr/bin/env bash
# Downloads the official sing-box Windows binary into windows/core/.
# Usage: scripts/fetch_core_windows.sh [amd64|arm64]
set -euo pipefail

arch="${1:-amd64}"
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/scripts/core_version.txt")"
name="sing-box-${version}-windows-${arch}"
url="https://github.com/SagerNet/sing-box/releases/download/v${version}/${name}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $url"
curl -fL --retry 3 -o "$tmp/core.zip" "$url"
unzip -q "$tmp/core.zip" -d "$tmp"
mkdir -p "$root/windows/core"
cp "$tmp/$name/sing-box.exe" "$root/windows/core/sing-box.exe"
echo "sing-box $version installed to windows/core/sing-box.exe"

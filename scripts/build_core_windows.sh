#!/usr/bin/env bash
# Builds sing-box.exe from source (fallback when release downloads are
# blocked). Requires Go >= 1.25. Usage: scripts/build_core_windows.sh [amd64|arm64]
set -euo pipefail

arch="${1:-amd64}"
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/scripts/core_version.txt")"
src="$root/.core-build/sing-box"
tags="with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_clash_api,badlinkname,tfogo_checklinkname0"

if [ ! -d "$src/.git" ]; then
  git clone --depth 1 --branch "v$version" https://github.com/SagerNet/sing-box.git "$src"
fi
mkdir -p "$root/windows/core"
(
  cd "$src"
  CGO_ENABLED=0 GOOS=windows GOARCH="$arch" go build -trimpath -tags "$tags" \
    -ldflags "-s -w -buildid= -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=$version" \
    -o "$root/windows/core/sing-box.exe" ./cmd/sing-box
)
echo "Built windows/core/sing-box.exe ($version, $arch)"

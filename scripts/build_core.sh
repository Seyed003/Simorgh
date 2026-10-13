#!/usr/bin/env bash
# Builds the sing-box command-line core (with the Xray outbound) for any
# platform. Usage: scripts/build_core.sh <goos> <goarch> <output>
# e.g. scripts/build_core.sh linux amd64 build/core/sing-box (used by tests)
set -euo pipefail

goos="$1"
goarch="$2"
root="$(cd "$(dirname "$0")/.." && pwd)"
output="$(cd "$(dirname "$3")" 2>/dev/null && pwd || (mkdir -p "$(dirname "$3")" && cd "$(dirname "$3")" && pwd))/$(basename "$3")"
version="$(tr -d '[:space:]' < "$root/scripts/core_version.txt")"
src="$root/.core-build/sing-box"
tags="with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_xray,badlinkname,tfogo_checklinkname0"
if [ "$goos" = windows ]; then
  tags="$tags,with_dhcp"
fi

"$root/scripts/prepare_core_source.sh"
(
  cd "$src"
  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" go build -trimpath -tags "$tags" \
    -ldflags "-s -w -buildid= -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=$version" \
    -o "$output" ./cmd/sing-box
)
echo "Built $output (sing-box $version with Xray, $goos/$goarch)"

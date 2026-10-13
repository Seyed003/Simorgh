#!/usr/bin/env bash
# Prepares .core-build/sing-box: sing-box (scripts/core_version.txt) plus the
# "xray" outbound from core/xray, built on Xray-core (scripts/xray_version.txt)
# so configs with Xray-only transports (XHTTP, mKCP) work. Run by the build
# scripts; safe to run again.
# Requires Go >= 1.25 (a newer toolchain is fetched automatically if needed).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/scripts/core_version.txt")"
xray_version="$(tr -d '[:space:]' < "$root/scripts/xray_version.txt")"
src="$root/.core-build/sing-box"
export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"

if [ ! -d "$src/.git" ]; then
  git clone --depth 1 --branch "v$version" https://github.com/SagerNet/sing-box.git "$src"
fi

cd "$src"
mkdir -p protocol/xray
cp "$root/core/xray/outbound.go" protocol/xray/outbound.go
cp "$root/core/xray/include_xray.go.txt" include/xray.go
cp "$root/core/xray/include_xray_stub.go.txt" include/xray_stub.go
if ! grep -q 'registerXrayOutbound(registry)' include/registry.go; then
  sed -i.bak 's/^\tregisterQUICOutbounds(registry)$/\tregisterXrayOutbound(registry)\n\tregisterQUICOutbounds(registry)/' include/registry.go
  rm -f include/registry.go.bak
  grep -q 'registerXrayOutbound(registry)' include/registry.go || {
    echo "Could not hook the xray outbound into include/registry.go" >&2
    exit 1
  }
fi
if ! grep -q "github.com/xtls/xray-core $xray_version" go.mod; then
  go get "github.com/xtls/xray-core@$xray_version"
  go mod tidy
fi
echo "sing-box $version + Xray-core $xray_version ready in .core-build/sing-box"

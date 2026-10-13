#!/usr/bin/env bash
# Builds android/app/libs/libbox.aar (sing-box for Android, via gomobile),
# with the Xray outbound (see scripts/prepare_core_source.sh).
#
# Requirements: Go >= 1.25, JDK 17+, Android SDK with an NDK installed
# (ANDROID_HOME or ANDROID_SDK_ROOT set; ANDROID_NDK_HOME optional).
# Usage: scripts/build_libbox.sh [android|android/arm64,android/amd64]
set -euo pipefail

targets="${1:-android/arm64,android/arm,android/amd64}"
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/scripts/core_version.txt")"
src="$root/.core-build/sing-box"
gomobile_version="v0.1.13"
# Only what the app uses; OpenVPN + OpenConnect add ~2 MB to the APK,
# tailscale/naive would add ~40 MB.
tags="with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_openvpn,with_openconnect,with_xray,badlinkname,tfogo_checklinkname0"

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
  export ANDROID_NDK_HOME
fi
if [ ! -f "${ANDROID_NDK_HOME:-}/source.properties" ]; then
  echo "Android NDK not found. Install one with: sdkmanager 'ndk;28.2.13676358'" >&2
  exit 1
fi

"$root/scripts/prepare_core_source.sh"

gobin="$(go env GOPATH)/bin"
if [ ! -x "$gobin/gomobile" ] || [ ! -x "$gobin/gobind" ]; then
  go install "github.com/sagernet/gomobile/cmd/gomobile@$gomobile_version"
  go install "github.com/sagernet/gomobile/cmd/gobind@$gomobile_version"
fi
export PATH="$gobin:$PATH"

mkdir -p "$root/android/app/libs"
(
  cd "$src"
  gomobile bind -v \
    -o "$root/android/app/libs/libbox.aar" \
    -target "$targets" \
    -androidapi 24 \
    -javapkg=io.nekohasekai \
    -libname=box \
    -trimpath -buildvcs=false \
    -ldflags "-s -w -buildid= -checklinkname=0 -X github.com/sagernet/sing-box/constant.Version=$version" \
    -tags "$tags" \
    ./experimental/libbox
)
echo "Built android/app/libs/libbox.aar (sing-box $version)"

#!/usr/bin/env bash
# Builds windows/core/sing-box.exe from source with the Xray outbound (see
# scripts/prepare_core_source.sh); the official release lacks it.
# Requires Go >= 1.25. Usage: scripts/build_core_windows.sh [amd64|arm64]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build_core.sh" windows "${1:-amd64}" "$root/windows/core/sing-box.exe"

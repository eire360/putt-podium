#!/bin/bash
set -euo pipefail
# Exact app models/store are compiled, not copied into a mock implementation.
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
STUDIO_SDK="$(xcrun --sdk macosx --show-sdk-path)"
if [[ $# -gt 0 ]]; then
    STUDIO_WORK="$1"
    mkdir -p "$STUDIO_WORK"
else
    STUDIO_WORK="$(mktemp -d "${TMPDIR:-/tmp}/puttpodium-checks.XXXXXX")"
    trap 'rm -rf "$STUDIO_WORK"' EXIT
fi
xcrun swiftc -parse-as-library -sdk "$STUDIO_SDK" \
    -module-cache-path "$STUDIO_WORK/module-cache" \
    "$STUDIO_ROOT/putt podium/RoundModels.swift" \
    "$STUDIO_ROOT/putt podium/RoundStore.swift" \
    "$STUDIO_ROOT/Verification/ModelChecks.swift" \
    -o "$STUDIO_WORK/model-checks"
"$STUDIO_WORK/model-checks"

#!/bin/bash
# Runs the complete shared Core suite without resolving the Mac app's WhisperKit dependency.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/speakaway-core-tests.XXXXXX")
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 143' INT TERM HUP

mkdir -p "$WORK/app/Sources" "$WORK/app/Tests"
ln -s "$REPO/ios" "$WORK/ios"
ln -s "$REPO/app/Sources/SpeakAwayCore" "$WORK/app/Sources/SpeakAwayCore"
ln -s "$REPO/app/Tests/SpeakAwayCoreTests" "$WORK/app/Tests/SpeakAwayCoreTests"
cat > "$WORK/app/Package.swift" <<'PACKAGE'
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SpeakAwayCoreChecks",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SpeakAwayCore"),
        .testTarget(name: "SpeakAwayCoreTests", dependencies: ["SpeakAwayCore"]),
    ]
)
PACKAGE
swift test --package-path "$WORK/app" "$@"

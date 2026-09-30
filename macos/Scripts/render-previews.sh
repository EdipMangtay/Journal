#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_TOOLCHAIN=/Library/Developer/CommandLineTools
TASK_SOURCES=()
while IFS= read -r source; do TASK_SOURCES+=("$source"); done < <(find LiquidityEdge -name '*.swift' ! -name LiquidityEdgeApp.swift -print | sort)
mkdir -p build/previews
DEVELOPER_DIR="$TASK_TOOLCHAIN" "$TASK_TOOLCHAIN/usr/bin/swiftc" -swift-version 5 -target arm64-apple-macosx14.0 -sdk "$TASK_TOOLCHAIN/SDKs/MacOSX.sdk" -plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins -parse-as-library "${TASK_SOURCES[@]}" Scripts/render-previews.swift -o build/previews/render
build/previews/render "$PWD/build/previews"

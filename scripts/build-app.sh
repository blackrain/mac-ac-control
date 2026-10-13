#!/bin/bash
# Builds GreeBar.app into ./build. Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product GreeBar
BIN="$(swift build -c release --show-bin-path)"
APP="build/GreeBar.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GreeBar" "$APP/Contents/MacOS/GreeBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/GreeBar.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/GreeBar.app"
fi

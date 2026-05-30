#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="ClaudeUsage.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/ClaudeUsage" "$APP/Contents/MacOS/ClaudeUsage"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Gebaut: $APP"
echo "Starten mit: open $APP"

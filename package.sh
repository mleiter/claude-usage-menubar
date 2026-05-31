#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP="ClaudeUsage.app"
ZIP="ClaudeUsage.zip"

# Universal build (Apple Silicon + Intel), damit die App auf jedem Mac läuft.
echo "Baue universal (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

# Bundle zusammensetzen.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/ClaudeUsage" "$APP/Contents/MacOS/ClaudeUsage"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc-Signatur: macht das Bundle auf anderen Macs startbar (ohne Apple Developer ID).
echo "Signiere (ad-hoc)…"
codesign --force --sign - "$APP"

# Verteilbares Zip (ditto erhält die Bundle-Struktur korrekt).
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Fertig:"
echo "  Lokal starten:   open $APP"
echo "  Architekturen:   $(lipo -archs "$APP/Contents/MacOS/ClaudeUsage")"
echo "  Zum Verteilen:   $ZIP  (auf den anderen Mac kopieren)"

#!/bin/bash
# Builds SleepTracker in release mode and packages it as a proper .app bundle
# (with icon + Info.plist) in dist/SleepTracker.app.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build -c release"
swift build -c release

APP="dist/SleepTracker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/SleepTracker "$APP/Contents/MacOS/SleepTracker"
cp AppResources/Info.plist "$APP/Contents/Info.plist"
cp AppResources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so Gatekeeper/Dock treat it as a normal, stable app bundle
# (matters for Dock persistence and for launching without a "damaged app" warning).
codesign --force --deep --sign - "$APP"

echo "==> built $APP"

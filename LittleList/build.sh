#!/bin/zsh
set -eu
cd "${0:A:h}"
BUILD_DIR=$(mktemp -d /private/tmp/little-list-build.XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/Little List.app/Contents/MacOS"
xcrun swiftc -target arm64-apple-macos14.0 Sources/main.swift -o "$BUILD_DIR/Little List.app/Contents/MacOS/LittleList" -framework AppKit -framework SwiftUI -framework ServiceManagement -module-cache-path /tmp/little-list-module-cache
cat > "$BUILD_DIR/Little List.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LittleList</string>
<key>CFBundleIdentifier</key><string>local.marco.littlelist</string>
<key>CFBundleName</key><string>Little List</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
xattr -cr "$BUILD_DIR/Little List.app"
codesign --force --sign - "$BUILD_DIR/Little List.app"

ditto "$BUILD_DIR/Little List.app" "Little List.app"
ditto "$BUILD_DIR/Little List.app" /private/tmp/little-list-install/"Little List.app"

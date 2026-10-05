#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=ClaudeUsageBar.app
rm -rf $APP; mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp AppIcon.icns $APP/Contents/Resources/
swiftc -O main.swift -o $APP/Contents/MacOS/ClaudeUsageBar
cat > $APP/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClaudeUsageBar</string>
<key>CFBundleIdentifier</key><string>local.claudeusagebar</string>
<key>CFBundleName</key><string>ClaudeUsageBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
P
# Sign with a stable identity (so a Keychain "Always Allow" survives rebuilds) and the hardened runtime.
# Override with CODESIGN_IDENTITY; falls back to the first Apple Development cert, then ad-hoc.
ID="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)}"
codesign --force --options runtime --sign "${ID:--}" $APP
echo "Built $APP (signed: ${ID:-ad-hoc})"

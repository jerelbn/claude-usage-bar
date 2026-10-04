#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=ClaudeUsageBar.app
rm -rf $APP; mkdir -p $APP/Contents/MacOS
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
echo "Built $APP"

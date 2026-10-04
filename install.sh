#!/bin/zsh
# Builds ClaudeUsageBar and installs it to ~/Applications, then launches it.
set -e
cd "$(dirname "$0")"
DEST="${INSTALL_DIR:-$HOME/Applications}"

./build.sh

pkill -x ClaudeUsageBar 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/ClaudeUsageBar.app"
cp -R ClaudeUsageBar.app "$DEST/"
open "$DEST/ClaudeUsageBar.app"
echo "Installed to $DEST/ClaudeUsageBar.app"
echo "To start at login: System Settings > General > Login Items > add ClaudeUsageBar."

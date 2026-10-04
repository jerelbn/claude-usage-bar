#!/bin/zsh
# Quits ClaudeUsageBar and removes the installed app. Does not touch your Claude Code login.
set -e
DEST="${INSTALL_DIR:-$HOME/Applications}"

pkill -x ClaudeUsageBar 2>/dev/null || true
rm -rf "$DEST/ClaudeUsageBar.app"
echo "Removed $DEST/ClaudeUsageBar.app"
echo "If you added it to Login Items, remove it in System Settings > General > Login Items."
echo "Optional: in Keychain Access, open 'Claude Code-credentials' > Access Control and remove ClaudeUsageBar."

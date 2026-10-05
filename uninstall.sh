#!/bin/zsh
# Quits ClaudeUsageBar and removes the installed app, its caches and its Spotlight/Launchpad registration.
# Does not touch your Claude Code login.
DEST="${INSTALL_DIR:-$HOME/Applications}"
ID="local.claudeusagebar"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pkill -x ClaudeUsageBar 2>/dev/null || true

# Every place the app may live (custom INSTALL_DIR, ~/Applications, /Applications, build output)
for app in "$DEST/ClaudeUsageBar.app" "$HOME/Applications/ClaudeUsageBar.app" \
           "/Applications/ClaudeUsageBar.app" "${0:A:h}/ClaudeUsageBar.app"; do
  "$LSREGISTER" -u "$app" 2>/dev/null || true   # drop stale Spotlight/Launchpad entry
  if [ -e "$app" ]; then rm -rf "$app" && echo "Removed $app"; fi
done

# App data, keyed by bundle id
defaults delete "$ID" 2>/dev/null || true
rm -rf "$HOME/Library/HTTPStorages/$ID" \
       "$HOME/Library/HTTPStorages/$ID.binarycookies" \
       "$HOME/Library/Preferences/$ID.plist" \
       "$HOME/Library/Caches/$ID" \
       "$HOME/Library/Application Support/$ID" \
       "$HOME/Library/Saved Application State/$ID.savedState" \
       "$HOME/Library/WebKit/$ID" \
       "$HOME/Library/Containers/$ID"
echo "Removed app data for $ID"

echo "If you added it to Login Items, remove it in System Settings > General > Login Items."
echo "Optional: in Keychain Access, open 'Claude Code-credentials' > Access Control and remove ClaudeUsageBar."

# ClaudeUsageBar

A tiny macOS menu bar app that shows your Claude plan usage as two bars:
the top bar is your **current session**, the bottom bar is your **weekly** limit.
Click the icon for percentages and reset times.

## Build & run

Requires macOS and Xcode command line tools.

```sh
./build.sh
open ClaudeUsageBar.app
```

To start at login, add `ClaudeUsageBar.app` in System Settings → General → Login Items.

## How it works

Every 2 minutes the app reads the Claude Code OAuth login from your macOS Keychain
(`Claude Code-credentials`) and calls `https://api.anthropic.com/api/oauth/usage`,
the same endpoint Claude Code uses. The token stays in memory and is only sent to `api.anthropic.com`.

You must have signed in with Claude Code (`claude`) at least once. macOS will ask once for Keychain
access; choose **Always Allow**.

## Caveats

The usage endpoint is undocumented and may change or break without notice.
This project is unofficial and not affiliated with Anthropic.

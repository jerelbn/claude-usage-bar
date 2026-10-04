# ClaudeUsageBar

A tiny macOS menu bar app that shows your Claude plan usage as two bars:
the top bar is your **current session**, the bottom bar is your **weekly** limit.
Click the icon for percentages and reset times.

## Install

Requires macOS and Xcode command line tools (`xcode-select --install`). Sign in with Claude Code (`claude`) at least once.

```sh
./install.sh
```

This builds the app, copies it to `~/Applications`, and launches it. To start it at login, add it in
System Settings → General → Login Items. To only build without installing, run `./build.sh`.

## Uninstall

```sh
./uninstall.sh
```

This quits the app and deletes it from `~/Applications`. Your Claude Code login is not touched.

## Staying secure

- When macOS asks for Keychain access, check that the prompt names **ClaudeUsageBar**, then choose **Always Allow**.
- Don't grant "Always Allow" to any other program (such as `security` or Terminal) for the "Claude Code-credentials" item.
- Build from source yourself and review `main.swift`. Don't run prebuilt copies from other people.
- Never share your Claude Code login or paste it anywhere.

## How it works

Every 2 minutes the app calls `https://api.anthropic.com/api/oauth/usage`, the same endpoint Claude Code uses,
with the login Claude Code stored in your Keychain.

## Caveats

The usage endpoint is undocumented and may change or break without notice.
This project is unofficial and not affiliated with Anthropic.

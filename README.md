<p align="center">
  <img src="assets/prompt-attachments/app-assets/app-icon.PNG" alt="yo!nk app icon" width="128">
</p>

<h1 align="center">yo!nk</h1>

<p align="center">
  <b>Tiny floating squares for the text you paste all the time.</b><br>
  Hover to read. Click to copy. Yoink.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="Status: early days" src="https://img.shields.io/badge/status-early%20days-orange">
</p>

---

## The problem

You have those three commands. That email sign-off. That API key format you can never remember. You keep it in a notes app, a text file, or your shell history, and you dig for it about forty times a day.

## The fix

yo!nk is a small native macOS menu-bar app. Every snippet gets its own little floating square that sits above your other windows, on whichever display you like.

- **Hover** a square to read the whole snippet beside it, line breaks and all.
- **Click** it to copy the complete text, then paste with ⌘V wherever you want.

That's the whole trick. yo!nk only copies. It never runs, pastes, or opens anything, so a snippet that looks like a Terminal command is still just text. (Yes, on purpose.)

## What you get

- **Squares, not a window.** One translucent floating square per snippet. No title bar, no chrome, no big panel hogging your screen.
- **Short labels.** One to four letters, numbers, symbols, or emoji. Three characters or fewer sit on one line, and a four-character label stacks as two rows of two, so `ABCD` fits as `AB` over `CD`.
- **Hover preview.** The complete text, line breaks kept. Very long snippets wrap and end with "… N more lines".
- **Click to copy,** with a short sound and your pick of a checkmark, a burst, or no visual change at all.
- **Drag them anywhere,** across multiple displays. Positions are remembered. Lock them if your mouse has opinions.
- **Your size, your see-through.** Squares default to a tidy 40 pt, and you can go from 30 to 160 pt. Opacity runs from 30 to 100%.
- **Global shortcuts** for individual squares, with no Accessibility permission needed.
- **Hide/Show All** (⌃⌥H) and **Snap to Grid** (⌃⌥G). Both shortcuts are changeable.
- **Show in screenshots.** Squares are always on your screen, so there's a switch that leaves them out of screenshots and screen recordings while keeping them visible to you. It's on by default. (It relies on macOS, so a capture tool that does its own thing may ignore it.)
- **A right-click menu** on every square: Edit…, Duplicate, Delete, Lock/Unlock Positions, Hide this square, Hide All Squares.
- **Undo and redo** (⌘Z / ⇧⌘Z) for edits, moves, settings, and Snap to Grid. Because everyone fat-fingers a drag.
- **A proper Settings window** with search, snippet history, and a launch-at-login switch.

## Status

Early days. This is version 0.2.0, which means initial development: things can still change. There are no download builds yet, so for now you build it yourself. It takes one command.

## Requirements

- macOS 14 Sonoma or later
- To build it: Xcode 27 with Swift 6.4 (Apple Silicon)

## Build and run

From the repository root:

```sh
zsh yoink/scripts/build-app.zsh
```

This makes a Release build and writes `dist/yo!nk.app`, signed ad hoc so it runs on your own Mac. Developer ID signing and notarization for distribution are separate, manual steps.

> **Heads up:** the app's name contains a `!`, so quote the path in your shell: `open 'dist/yo!nk.app'`.

yo!nk lives in your menu bar. Choose **Settings…** from its icon to add and edit squares. You'll only see a Dock icon while Settings is open.

### Trying it without touching your real data

By default, yo!nk keeps its data in `~/Library/Application Support/com.dweebzxx.yoink/`. For development or testing, point it at another folder:

```sh
open -n 'dist/yo!nk.app' --args --config-dir "$PWD/yoink/.build/smoke-config"
```

`YOINK_CONFIG_DIR=/some/folder` works too. Only one running copy can use a given folder at a time.

## Tests

```sh
swift test --package-path yoink
```

Covers the product logic without launching the app. Writes only to `yoink/.build/test-tmp/`.

## Project layout

```text
yoink/
├── Package.swift
├── Sources/
│   ├── YoinkCore/        # product state, rules, persistence, undo, grid, history (Foundation only)
│   └── yoink/            # AppKit app: squares, previews, menu bar, hotkeys
│       └── Settings/     # SwiftUI Settings window, hosted by AppKit
├── Tests/YoinkCoreTests/ # Swift Testing suites and JSON fixtures
└── scripts/build-app.zsh # builds dist/yo!nk.app
assets/                   # app icon, square art, menu-bar icon, sound
```

## Privacy

Short version: it's your text, and it stays on your Mac.

- Squares, snippets, history, and settings live in one local file that only your user account can read.
- No accounts, no sync, no network, no analytics.
- Snippet history holds only texts you saved in yo!nk, never anything else from your clipboard. Remove entries or clear it any time in Settings.

## Credits

© 2026 dweebzxx. Released under the [MIT License](LICENSE).

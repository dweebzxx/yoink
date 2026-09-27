# Changelog

## [Unreleased]

## [0.2.1] - 2026-09-27
### Changed
- The release zip is now named `yoink-0.2.1.zip`, an ASCII filename that needs no quoting or escaping in a shell. The app bundle inside it is unchanged: still `yo!nk.app`.

## [0.2.0] - 2026-09-27
### Added
- Floating squares: one independent, translucent, always-on-top square per snippet, with a label of one to four characters. A four-character label is shown on two rows of two characters.
- Hover a square to see the complete text beside it, and click it to copy the complete text. The app only copies; it never runs, pastes, or opens anything.
- Copy feedback: a short sound, plus a checkmark, a burst, or no visual change.
- Drag squares anywhere across multiple displays, with positions remembered. Lock positions, and Snap to Grid.
- Square size from 30 pt to 160 pt (default 40 pt) and opacity from 30% to 100%.
- Per-square keyboard shortcuts, Hide/Show All, and hiding a single square.
- A "Show in screenshots" setting, on by default. When it is turned off, squares and their hover preview and click-feedback overlays are left out of screenshots and screen recordings while staying visible on screen.
- A right-click menu, undo and redo, and a Settings window with search, snippet history, and launch at login.
- All data stays in one local file on the Mac. No accounts, sync, network, or analytics.

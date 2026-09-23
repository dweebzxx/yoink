# yo!nk — v1 product specification

`yo!nk` is a small, native macOS menu-bar utility that keeps frequently used text snippets one click away, as tiny independent floating squares.

Each square holds one saved snippet. It shows a short label, stays above normal windows, reveals the full text on hover, and copies that text to the clipboard when clicked.

`yo!nk` never runs, pastes, or interprets snippets. Its only job is to make grabbing text extremely fast:

> See the tiny marker, hover if you need to verify it, click it, and the text is yours.

This is a plain-language summary. The authoritative, detailed rules live in `docs/` (Decision Log, MVP scope, and the source-of-truth files). If this page and the docs disagree, the docs win.

## Floating squares

- One independent floating square per snippet, not a panel of items.
- Stays above normal app windows, with no title bar or window chrome.
- Translucent. Size and opacity apply to all squares.
- Starts at 70 × 70 pt, adjustable from 70 to 160 pt. Opacity starts at 85%, adjustable from 30% to 100%.
- Drag each square anywhere, on any connected display. Positions are remembered.
- Each square stays on the desktop (Space) where you put it and does not appear over full-screen apps. After a relaunch, all squares appear on the current desktop, because macOS doesn't let apps choose.
- If a square's display is unplugged, the square moves to the main display and goes back when that display returns.
- **Snap to Grid** lines every square up neatly on its own display. It's available from the menu bar, Settings, and ⌃⌥G.
- **Hide/Show All** hides or shows every square at once. It's available from the menu bar, the right-click menu, and ⌃⌥H, and is remembered across relaunch.

Example layout:

```text
MacBook display:        External display:
S  O                    C  CL  A
```

## Labels

- One or two characters: letters, numbers, symbols, accented letters, or emoji.
- A label can't be empty or only spaces. Two squares may share a label.
- The label is only a visual marker. It never changes what a square does.

## Snippets

- Any plain text: commands, paths, URLs, email addresses, sentences, code, or multiline text.
- Text is kept exactly as typed, including line breaks, through saving, preview, and copying.

## Hover

- Hovering shows the complete snippet beside the square, with line breaks preserved.
- It never takes focus from the app you're using.
- Very long snippets wrap and fill the screen at most, ending with "… N more lines". The full text is always copied and visible in Settings.

## Click, drag, and shortcuts

- A click copies the complete snippet to the clipboard. It never runs it, pastes it, opens Terminal, or changes it.
- Dragging an unlocked square moves it without copying. When squares are locked, they can't move, and a slightly shaky click still copies.
- Each square can have its own keyboard shortcut, set in Settings, that copies it from any app. None are set at first.
- Right-clicking a square offers Edit…, Duplicate, Delete, Lock/Unlock Positions, and Hide All Squares. Right-clicking never copies.

```text
click square  →  snippet copied  →  ⌘V where you want it
```

## Copy feedback

- Sound: the "hehe" clip plays on every successful copy. A Settings switch turns it off. It's on at first.
- Visual effect, one of:
  - **Checkmark** (default): the label briefly becomes a checkmark drawn in the app's art style, the square gives a small shake, then the label returns.
  - **Burst:** a quick, light pop radiates from the square.
  - **None:** no visual change.
- With macOS Reduce Motion on, there's no shake or burst animation.
- Feedback appears only after the copy actually succeeds.

## Menu bar and Dock

- `yo!nk` lives in the menu bar. Its menu has Settings…, Hide/Show All Squares, Snap to Grid, Undo, and Quit.
- There's no Dock icon, except while the Settings window is open.

## Settings window

A real macOS Settings window:

- **Squares:** list, search, add, edit (label and full multiline text), delete, duplicate, set a keyboard shortcut per square, and a Snap to Grid button.
- **Appearance:** square size and opacity.
- **Interaction:** copy effect, sound on or off, lock positions, and the Hide/Show All and Snap to Grid shortcuts.
- **History:** every snippet text ever used in a square, including ones since edited or deleted. You can copy one, add it back as a square, remove entries, or clear the history.
- **General:** launch at login (off at first).

⌘Z and ⇧⌘Z undo and redo any change, including moves and Snap to Grid, for the current session.

No one ever needs to edit files or code to manage squares.

## Starter squares

`yo!nk` starts with five fully editable squares:

| Label | Snippet |
| :--- | :--- |
| `S` | `cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp` |
| `O` | `cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp/spicy-project-manager/outputs` |
| `C` | `codex --yolo` |
| `CL` | `claude --dangerously-skip-permissions` |
| `A` | `cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground-beta/spicedanime-webapp-docs` then, on a new line, `agy --dangerously-skip-permissions` |

## Saved data and privacy

- Everything stays on the Mac, in `~/Library/Application Support/com.dweebzxx.yoink/`. There's no account, cloud, sync, or tracking.
- Saved: squares, labels, snippets, positions and displays, size, opacity, lock state, copy effect, sound setting, shortcuts, hidden state, history, and launch at login.
- If the saved data is ever damaged, `yo!nk` asks whether to Quit, Show the file in Finder, or Start Fresh, keeping a backup. It never overwrites your data without asking.

## Technical direction

- Swift, as a native macOS app.
- AppKit for the app, squares, previews, menu bar, and shortcuts. SwiftUI only inside the Settings window.
- Built with Xcode 27 and Swift 6.4 on macOS 27. Runs on macOS 14 (Sonoma) and later.
- Distributed as a notarized direct download named `yo!nk.app` (ID `com.dweebzxx.yoink`), outside the Mac App Store.

## v1 includes

Editable snippets · add/edit/delete/duplicate · 1–2 character labels · independent translucent floating squares · size and opacity controls · full-text hover preview · click-to-copy · sound and checkmark/burst/none feedback · dragging · position locking · remembered positions · multiple displays · per-square keyboard shortcuts · Hide/Show All · right-click menu · Snap to Grid · undo/redo · Settings search · snippet history · persistent local configuration · a real Settings window · launch at login.

`yo!nk` v1 is small in scope, but not in polish.

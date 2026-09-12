# yoink — v1 product specification

`yoink` is a lightweight macOS utility that keeps frequently used text snippets immediately accessible as small, independent floating squares.

Each square represents one saved snippet. The square displays a short identifier, stays above normal windows, reveals the full saved text on hover, and copies that text to the clipboard when clicked.

The app does not execute commands or automatically paste them. Its job is to make grabbing frequently used text extremely fast.

## Floating squares

Each snippet exists as its own independent floating square rather than as an item inside a larger panel.

Squares:

- stay above normal application windows
- have no traditional title bar or surrounding window chrome
- use a translucent appearance
- can be dragged independently
- remember their positions
- can be placed anywhere on the desktop
- can be distributed across multiple monitors
- remain independent from one another

A user with multiple displays should be able to put some squares on one display and others on another.

Example:

```text
Display 1                  Display 2

   S                           C
   O                           CL
                               A
```

The app should remember where the squares were placed.

## Square labels

Every square has a user-defined short label.

The label can contain up to **two characters**.

Characters may include:

- letters
- numbers
- symbols

Examples:

```text
S

C

C1

CL

>

//

$
```

The label does not determine what the snippet contains. It is simply the visual identifier for that square.

## Saved text

Every square stores arbitrary text chosen by the user.

This can include:

- Terminal commands
- filesystem paths
- URLs
- email addresses
- frequently reused sentences
- multiline text
- code fragments
- any other plain text

For example:

```text
C
```

could contain:

```text
codex --yolo
```

while:

```text
A
```

could contain:

```text
cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground-beta/spicedanime-webapp-docs
agy --dangerously-skip-permissions
```

There should be no requirement that snippets contain commands.

## Hover behavior

Hovering over a square reveals its complete stored text.

The hover preview should:

- appear beside the square
- show the entire snippet
- preserve multiline text
- use a readable presentation appropriate for snippets and commands
- disappear when the pointer leaves
- avoid unnecessarily taking focus away from the active application

The square itself remains compact; the full text only appears when needed.

## Click behavior

Clicking a square copies its complete stored text to the macOS clipboard.

It does not:

- execute the text
- automatically paste it
- open Terminal
- change the contents of the snippet

The expected workflow is:

```text
click square
      ↓
snippet copied
      ↓
⌘V
```

## Click feedback

A successful click should have both visual and audible feedback.

The app should support three visual feedback modes:

### Checkmark

The square temporarily changes from its normal label:

```text
C
```

to:

```text
✓
```

and then returns to its label.

### Burst

A short visual burst radiates outward from the square when the snippet is copied.

The burst should feel quick and lightweight rather than like a large animation.

### None

The square does not visually change after being clicked.

The click interaction should also play a short sound so the user receives immediate confirmation that the copy succeeded.

The desired visual feedback mode should be configurable in Settings.

## Appearance controls

The user should be able to adjust the appearance of the floating squares.

At minimum:

- square size
- opacity

Changing these settings should affect the actual floating squares rather than only a preview.

The squares should remain visually minimal even at larger sizes.

## Positioning

Squares can be dragged freely when positioning is enabled.

The app should remember their locations between launches.

A position-locking option should prevent accidental movement during normal use.

When positions are locked:

- clicking copies normally
- hovering works normally
- dragging does not reposition the square

## Multiple-display support

Multiple monitors are a first-version requirement.

Squares are not restricted to the primary display.

A user should be able to distribute them however they want:

```text
MacBook display:
S  O

External display:
C  CL  A
```

Their saved placement should include which display they belong to as well as their location on that display.

## Settings window

`yoink` should have a real macOS Settings window.

It should not rely solely on a menu-bar dropdown or right-click menus for configuration.

Settings should provide access to the application's major controls, including:

### Squares

View and manage the current squares.

Users should be able to:

- add a square
- edit a square
- delete a square
- duplicate a square
- change its one- or two-character label
- change its stored text

### Appearance

Configure:

- square size
- opacity

### Interaction

Configure:

- click feedback mode
  - checkmark
  - burst
  - none
- position locking

### App behavior

Provide application-level controls such as:

- launch at login

The Settings window should be a normal, deliberate part of the product rather than an afterthought.

## Editing

Editing is part of v1.

The user should not need to modify configuration files or source code to change the squares.

A square can be changed to contain whatever the user wants.

At minimum, editing a square includes:

```text
Label:
[ CL ]

Text:
┌──────────────────────────────────────────┐
│ claude --dangerously-skip-permissions    │
└──────────────────────────────────────────┘
```

Multiline snippets must also be supported.

## Initial configuration

The app can initially contain the five snippets that motivated the project:

### S

```text
cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp
```

### O

```text
cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp/spicy-project-manager/outputs
```

### C

```text
codex --yolo
```

### CL

```text
claude --dangerously-skip-permissions
```

### A

```text
cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground-beta/spicedanime-webapp-docs
agy --dangerously-skip-permissions
```

These are simply initial saved snippets. Every part of them can be changed through the app.

## Persistence

`yoink` should preserve its state between launches.

That includes:

- squares
- labels
- snippet contents
- positions
- display placement
- size
- opacity
- position-lock state
- selected click-feedback behavior
- other application preferences

Everything remains local to the Mac.

## Technical direction

The planned implementation remains:

**Rust + egui/eframe**, with macOS-specific integration where necessary.

Rust handles the application data, state, persistence, clipboard behavior, settings, and most interface logic.

macOS-specific code can be used where necessary to get the floating-window behavior exactly right, especially for:

- independent floating windows
- multiple-display behavior
- window focus behavior
- native system integration

The fact that this is a first Rust project should not dictate an artificially simplistic product design.

The implementation can be developed incrementally while still targeting the complete v1 specification.

## v1 scope

Version 1 should already include:

- editable snippets
- add/delete/duplicate squares
- labels of up to two letters, numbers, or symbols
- independent floating squares
- transparent/translucent appearance
- adjustable square size
- adjustable opacity
- hover preview of complete text
- click-to-copy
- visual click feedback
- click sound
- checkmark, burst, or no visual feedback
- independent dragging
- position locking
- remembered positions
- full multi-monitor placement
- persistent configuration
- proper Settings window
- launch-at-login control

`yoink` v1 should therefore be a small application in scope, but not a remedial one in capability or polish.

Its defining interaction remains:

> See the tiny marker, hover if you need to verify it, click it, and the text is yours.
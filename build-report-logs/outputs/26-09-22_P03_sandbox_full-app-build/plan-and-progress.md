# P03 — Plan and Progress Log (26-09-22_P03_sandbox_full-app-build)

## Implementation choices (to be recorded as Decisions #46+)

- Structure: one Swift package at repo root `yoink/` (the existing empty technical dir) with targets
  `YoinkCore` (library, Foundation only), `yoink` (executable, AppKit + SwiftUI Settings), `YoinkCoreTests`.
  `scripts/build-app.zsh` assembles and ad-hoc signs `dist/yo!nk.app`. No Xcode project.
- Tests: Swift Testing via `swift test` (no app host).
- Persistence: JSON (`Codable`), schema version 1, `config.json`, dir 0700, file 0600, atomic write.
  Override with `--config-dir <path>` (or `YOINK_CONFIG_DIR`) for isolated runs; lock file prevents a second writer.
- Display identity: `CGDisplayCreateUUIDFromDisplayID` UUID string. Position: square's top-left offset from
  the display's top-left, plus the display size at save time (for the relative fallback).
- Sound: AVAudioPlayer preloaded. Shortcut recorder: in-house AppKit NSView wrapped for SwiftUI.
- Visual: square art = cropped `floating-button*.PNG`; drag = GIF in a click-through child overlay;
  label = SF Rounded heavy, Burnt Orange 700; checkmark = vector drawing in code (orange, 3D style).

## Milestones

| # | Milestone | Acceptance | Proof command |
|---|---|---|---|
| M1 | Package skeleton, .gitignore, build script | `swift build` ok; `dist/yo!nk.app` assembled + ad-hoc signed | `zsh scripts/build-app.zsh` |
| M2 | Core: model, labels, persistence, migration hook, corrupt classification, history, search, undo, grid, placement resolver, copy service | All Core suites pass | `swift test` |
| M3 | App shell: menu bar, main menu, squares (panel, hover, click/drag, lock, feedback, sound), hotkeys, hide/show, context menu | App launches in isolated dir with 5 seeds; screenshot | `open -n 'dist/yo!nk.app' --args --config-dir …` |
| M4 | Settings (SwiftUI in NSWindowController): Squares/Appearance/Interaction/History/General/About | Visual check via screenshot | same |
| M5 | Visual checks 70/160 pt, 30% opacity, menu-bar icon, window levels | Screenshots | `screencapture` |
| M6 | Independent review + fixes | Findings triaged | subagent |
| M7 | Docs, decisions, AGENTS.md verified commands, report | Report complete | — |

## Progress log

- [x] Branch checks (`gala`/`gala`), prompt saved.
- [x] Read AGENTS.md, all core docs, skills, brand files; inspected assets.
- Human rules added mid-pass: never work outside the repo without permission; report goes to `.yoink-private/build-report-logs/reports/` using `.yoink-private/workflow-templates/pass-report-template.md`; app launch approved (config in `yoink/.build/smoke-config`); Orca screen control declined (screenshots + read-only window listings only).
- [x] M1: `yoink/Package.swift` (YoinkCore, yoink, YoinkCoreTests), `.gitignore` covers `.build/`, `build/`, `dist/`, `.swiftpm/`.
- [x] M2: Core written; `swift test --package-path yoink` → 46 tests in 4 suites passed (fixed: history dates rounded to whole seconds for exact round trip).
- [x] M3: App written (SystemPorts, Displays, Art, SquareWindow, Overlays, SquaresController, AppController, main); `swift build` clean, no warnings.
- [x] M4: Settings written (window controller, Squares/Appearance/Interaction/History/General/About panes, snippet editor, shortcut recorder).
- [x] Build script `yoink/scripts/build-app.zsh` → `dist/yo!nk.app`, ad-hoc signed, `codesign --verify --strict` passes.
- [x] M5 (partial, no screen control): launch shows 5 seed squares (screenshot 01), squares on layer 3 = floating, Finder stays frontmost; clean quit via Apple event keeps config; 160 pt / 30% / locked relaunch (screenshot 02) shows locked art + hover preview (multiline kept, 480 pt wrap). Fixed: overlay level order (preview now layer 4). Checkmark preview rendered (`checkmark-art-preview.png`). No files written to real Application Support / Preferences / Saved State.
- [x] M6: independent review done — 6 findings; fixed 4 (hotkeys stay paused after Settings close; unknown fields dropped on save; preview clipping of wide chars/tabs; no-display first launch) + added History persistence test; 2 recorded as unresolved.
- [x] M7: Decisions #46–#55 added to the Decision Log; affected docs updated (Coding_AI_Context, MVP, floating-windows SOT, persistence SOT, failure SOT, privacy spec, architecture spec, visual spec, fixtures doc, runbook, test plan).
- [x] Product-behavior SOT + test plan updated; AGENTS.md verified commands added (5 commands).
- [x] Final clean-state verification (`rm -rf yoink/.build dist`): `swift test --package-path yoink` → 49 tests / 4 suites passed; `swift build --package-path yoink` clean; `zsh yoink/scripts/build-app.zsh` ok, codesign verified; launch shows 5 seeds on layer 3, config mode 0600; clean quit. Evidence: `verification-log.txt`, screenshots (cropped to app region).
- [x] Host Pass Report written: `.yoink-private/build-report-logs/reports/26-09-22_P03_sandbox_full-app-build-report.md`.
- PASS COMPLETE (product result: partial — manual hardware checks + Human approvals outstanding; see report).
- [x] Follow-up (Human): minimum square size 50 pt → Decision #56 (range 50–160, default 70); code, tests (50 passing), docs, and report updated; rebuilt, verified at 50 pt (`screenshots/04-50pt-minimum.png`). Noted a Human-launched instance (no `--config-dir`, live data) that was left untouched.
- [x] Follow-ups (Human): min size 40 pt (Decision #57); Settings relayout (no title band, inline shortcut rows, clean sliders, bordered label field), verified by capturing each tab with `--open-settings`; About wording, © 2026 dweebzxx, version without build number; README.md at repo root. Tests 50/50; app rebuilt.

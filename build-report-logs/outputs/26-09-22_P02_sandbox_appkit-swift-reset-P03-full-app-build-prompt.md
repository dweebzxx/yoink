P03 — Build yo!nk v1, end to end

## Goal

Build the complete v1 of yo!nk, a native macOS menu-bar utility, exactly as specified in this repository's core documents. Deliver a working, locally runnable app bundle at `/Volumes/etcetera/etceteraOS/ai-projects/code-playground/yoink/dist/yo!nk.app`, backed by automated tests, and finish with a pass report that shows the evidence.

Work autonomously through to the end. Don't stop after scaffolding or after the first working feature. The pass is finished only when the Definition of Done below is met or you hit a genuine blocker.

## Before you write any code

1. Follow `AGENTS.md` (also loaded as `CLAUDE.md`). This pass runs under its Override Mode. Complete these before anything else:
   - Run the branch checks from the repository root. Both must print `gala`, or stop.
   - Your artifact stem is `<YY-MM-DD>_P03_sandbox_full-app-build`, using today's date.
   - Save this entire prompt verbatim to `build-report-logs/prompts/<stem>-prompt.txt`.
2. Read the authoritative documents in the order `AGENTS.md` lists them, then every file under `docs/01_source_of_truth/`, `docs/02_app_specs/`, `docs/03_testing/`, and `docs/04_operations/`. The Decision Log (Decisions #1–#45) is the highest authority. `yoink — v1 product specification.md` at the repository root is only a plain-language summary. If it disagrees with the docs, the docs win.
3. Read the project skills in `.agents/skills/` (`macos-patterns`, `macos-build`, `macos-settings-ui`, `macos-development`, `macos-release`). They were adapted for this project, but the docs override them.
4. Inspect the assets and brand files listed below with your own eyes before designing any visuals.
5. Write your implementation plan as milestones, each with acceptance checks and the command that proves it. Keep that plan and a running progress log current in `build-report-logs/outputs/<stem>/` (this is the pass's nonstandard deliverable folder). Then execute it.

## Inputs

- **Specs:** `docs/` (via the repository-root symlink) and `AGENTS.md`.
- **App assets:** `/Volumes/etcetera/etceteraOS/ai-projects/code-playground/yoink/assets/prompt-attachments/app-assets`
  - `app-icon.PNG`: the app icon source (3024 px, transparent).
  - `floating-button.PNG`: the square at rest. `floating-button-locked.PNG`: the square when positions are locked. `floating-button-when-dragged-moving.gif`: the square while it is being dragged (46 frames, 50 ms, looping; the mascot's limbs reach beyond the square's body).
  - `menu-bar-icon.svg` (plus PNG renditions): the menu-bar icon.
  - `audio-hehe.mp3`: the copy confirmation sound.
- **Brand and colors:** `/Volumes/etcetera/etceteraOS/ai-projects/code-playground/yoink/brand`, containing `asset_color_system.md` (full palette, light and dark tokens, measured contrast ratios) and `yoink App Asset Palette.md`.
- **Missing asset:** Decision #33 requires a checkmark drawn in the style of the app art. It doesn't exist yet. Create it yourself from the brand palette and the existing art style. Flag it in the report for the Human's visual approval.
- **Developer machine:** MacBook Air M3, macOS 27, Xcode 27, Swift 6.4. Deployment target is macOS 14.

## Output

- The app bundle goes in `/Volumes/etcetera/etceteraOS/ai-projects/code-playground/yoink/dist/`, as `yo!nk.app` with bundle identifier `com.dweebzxx.yoink` (Decision #35). Building it must be reproducible from one documented command or script.
- Source code, tests, and build scripts go in the repository, in a layout you choose. Build products and intermediate files must not be committed. Make sure they're git-ignored.

## Decisions left to you

The docs deliberately leave some implementation details open: project structure, test framework, persistence encoding and schema number, display-identity encoding, sound playback API, the shortcut-recorder control, typography, and exact animation timings. Choose what you judge best. Record each choice that affects stored data, the build, or anything the user can see as a new numbered decision in `docs/00_project/Decision_Log_and_Open_Questions.md`, and update the affected docs in the same pass. Also add each build or test command you actually ran successfully to `AGENTS.md` → "Working Directories and Verified Commands".

If a real product-behavior gap or a conflict between documents appears, don't invent behavior. Pick the most conservative option consistent with the docs, keep building, and list it under Unresolved Issues in the report for the Human.

## Hard constraints

- IMPORTANT: Never touch the real user configuration. Every launch, test, and smoke check you run must use an isolated, temporary storage location, not `~/Library/Application Support/com.dweebzxx.yoink/`.
- The copy-only safety boundary is absolute. Never execute, paste, or interpret snippet text. Never log snippet or clipboard contents.
- No third-party dependencies unless the docs approve them. Prefer Apple frameworks.
- Human-only operations, which you must not perform:
  - Developer ID signing and notarization;
  - git commit or push;
  - installing into `/Applications`;
  - registering real login items. Launch at login is verified by the Human.

  Ad-hoc "sign to run locally" signing of the `dist/` build is allowed so the app launches on Apple Silicon.
- Stay inside v1 scope. Don't add features the docs don't list.

## Definition of Done

1. Every v1 requirement in `docs/00_project/MVP_Scope_and_Roadmap.md` (success criteria 1–21) and every decision in the Decision Log is implemented.
2. The automated tests cover everything `docs/03_testing/Test_Plan_and_Acceptance_Criteria.md` assigns to automated suites, including persistence round-trips, multiline clipboard fidelity, validation, undo, the grid, and history. They pass from a clean build.
3. A clean build produces `dist/yo!nk.app`. It launches as a menu-bar app, shows the five seed squares in isolated storage, and quits cleanly. Show evidence: the command output, plus a screenshot of the running app that you captured yourself.
4. Check what you can observe yourself (window levels, the menu bar icon, the Settings window, how the squares look at 70 pt and 160 pt), and fix what you find. Everything that needs human hands or eyes goes into the report's Manual Verification Checklist, mapped to the test plan's manual checks. That includes focus with another app frontmost, multiple displays, sound, launch at login, and visual approval of the checkmark art.
5. Before you finish, run an independent review of the whole diff in a fresh context (a subagent, or `/code-review`). Check it against the Decision Log and the test plan. Fix only findings that affect correctness or stated requirements.
6. The docs are updated to match what was built, every new decision is recorded, and the Host Pass Report is complete at `build-report-logs/reports/<stem>-report.md`, using the template in `.yoink-private/workflow-templates/pass-report-template.md` as `AGENTS.md` describes. The report cites evidence (commands, outputs, screenshots) rather than just claiming success.

## Working style

- After each milestone, build and run the tests. If anything fails, fix the root cause before moving on. Never suppress an error or weaken a test to make it pass.
- Commit to an approach and see it through. Revisit a decision only if new information contradicts it.
- If your context gets long, rely on the progress log in `build-report-logs/outputs/<stem>/` to keep track of where you are.

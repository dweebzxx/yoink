# yoink v1 — assets needed

Product name is `yoink` (lowercase). This list is derived from the v1 product specification and the P01 core documents. It names files the app must ship or the Human must supply. It does not approve a specific illustration, icon design, or sound take.

Drawn-at-runtime UI is listed so it is not mistaken for missing image files.

## Required shipped assets

| Asset | Kind | Why v1 needs it | Status |
| :--- | :--- | :--- | :--- |
| App icon | Image / macOS `.icns` (and source PNG/SVG) | Finder, Dock, and the `.app` bundle. The release runbook requires an icon once assets are approved. | Needed. Design, sizes, and filename are not approved. |
| Copy-success sound | Short audio (typically `.caf` or `.aiff`) | A successful clipboard copy plays a short confirmation sound. | Needed. Which take, and whether mute is independent, is Open Question 3. Do not treat a placeholder clip as the v1 sound. |

Suggested icon raster sizes when the Human supplies art: 16, 32, 64, 128, 256, 512, and 1024 px, plus 2× variants as required by `iconutil`. This is packaging practice, not an approved visual design.

## Conditional assets

These are needed only if the matching open question is resolved that way. Do not produce them as v1 requirements until then.

| Asset | Kind | Condition | Status |
| :--- | :--- | :--- | :--- |
| Menu-bar extra icon | Template image (monochrome PNG, 18 pt / 36 px 2× typical) | Open Question 1 chooses a menu-bar entry point, alone or with the Dock. | Not required until OQ1 is answered. |
| Alternate Dock tile | Image | Only if OQ1 chooses a Dock mark that is not the app icon. | Not expected; the app icon usually covers this. |
| Independent mute / off sound | Audio or none | Only if OQ3 adds an audible-feedback off switch. Off is silence, not a second clip, unless the owner says otherwise. | Not required until OQ3 is answered. |

## Runtime-drawn — not image or audio files

Implement in code (`egui` / native). Do not add sprite sheets or movies unless a later approved decision says so.

| Element | How it is produced |
| :--- | :--- |
| Floating square body | Translucent, chrome-free vector/rounded rect at the application size and opacity. |
| Square label | Up to two letters, numbers, or symbols, centered. |
| Hover preview | Text overlay beside the square, including multiline content. |
| Checkmark feedback | Temporary `✓` replacing the saved label. |
| Burst feedback | Short lightweight outward burst drawn around the square. Honors Reduce Motion by not radiating. |
| Settings window chrome | Normal macOS window, not a square graphic. |
| Position-lock, size, and opacity controls | Standard Settings controls. |

## Not needed for v1

Do not add these as product assets without an approved decision.

- Backend, cloud, or account artwork
- Onboarding illustration set
- Marketing site images as app dependencies
- Error-failure sound (failed copy is silence plus no visual success)
- Per-square custom images or badge art
- Sound pack beyond the single success clip
- Clipboard-history icons
- Terminal or “run command” glyphs (labels are not command types)

## Human-supplied vs generated

| Item | Who supplies it |
| :--- | :--- |
| App icon art | Human / designer. Not invented by an implementation pass. |
| Success sound take | Human. Blocked by Open Question 3. |
| Menu-bar template image | Human, only if OQ1 requires it. |
| Square, preview, checkmark, burst | Implementation, rendered. |
| Seed snippet text | Already specified in the MVP; not an audio/visual asset. |

## Open questions that change this list

1. Persistent system entry point (Dock, menu bar, both, or another pattern) — may add a menu-bar template image.
2. Square size and opacity ranges — affect rendering, not a shipped bitmap.
3. Confirmation sound and independent mute — selects the required audio file.

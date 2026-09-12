# Brand Color System
Teal Burnt Orange Periwinkle Warm Amber Warm Clay  |  Earthy palette Colorblind-safe

Applies to UI, UX, icons, design systems, data visualization, game assets, print, and marketing.
Every contrast ratio in this file is measured, not estimated. Ratios are WCAG 2.x: **4.5:1** for
body text, **3:1** for large text, icons, and meaningful UI boundaries.

### BRAND COLORS — PRIMARY
*Any of the three primary colors can be used as the main color choice.*

| Color Name | Hex | R | G | B | Role / Use | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Dark Teal | #254F58 | 37 | 79 | 88 | brand anchor | |
| Burnt Orange | #8F4218 | 143 | 66 | 24 | warm contrast | |
| Periwinkle | #4C62A8 | 76 | 98 | 168 | blue-violet accent | |

### BRAND COLOR — EXTENDED

| Color Name | Hex | R | G | B | Role / Use | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Warm Amber | #C08A18 | 192 | 138 | 24 | extended brand color | Badges, rewards, attention accents use sparingly |
| Warm Clay | #B86048 | 184 | 96 | 72 | extended brand color | Earthy terracotta distinct value and hue from orange |

### STATUS COLORS — IF NEEDED

| Color Name | Hex | R | G | B | Role / Use | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Forest Green | #3A7848 | 58 | 120 | 72 | Positive, on-target, confirmations | RESERVED — not for categorical use. Muted to match earthy palette tone. |
| Dark Ochre | #A87820 | 168 | 120 | 32 | Caution, near-threshold, alert | RESERVED — not for categorical use. No vivid yellow — earthy golden. |
| Crimson | #B03828 | 176 | 56 | 40 | Bad, failure, negative | RESERVED — not for categorical use. Never a series color. Lightened from #611F14 for legibility. |

---

# LIGHT MODE

Warm off-white ground. Accents use the **700** stop.

| Token | Hex | Use |
| :--- | :--- | :--- |
| Canvas / Page | #FAF7F2 | Page background |
| Surface | #F0EBE3 | Cards, panels, raised areas |
| Surface Sunken | #E8E2D9 | Wells, insets, code blocks, track backgrounds — a ground, not a boundary |
| Grid Lines | #E0D9D0 | Chart grid, faint dividers, decorative rules |
| Border / Axis | #C4BDB5 | Default borders, axis lines, input outlines |
| Border Strong | #8F887F | Emphasis borders, focused inputs, meaningful boundaries — 3.28:1, meets non-text contrast |
| Text Primary | #1A1E22 | Body copy, headings |
| Text Secondary | #4D5259 | Labels, captions, secondary copy |
| Text Muted | #8A9098 | Placeholder, disabled, non-essential |

**Measured on Canvas #FAF7F2**

| Color (700) | Ratio | Safe for |
| :--- | ---: | :--- |
| Dark Teal #254F58 | 8.41:1 | body text, icons, lines |
| Burnt Orange #8F4218 | 6.64:1 | body text, icons, lines |
| Periwinkle #4C62A8 | 5.43:1 | body text, icons, lines |
| Crimson #B03828 | 5.71:1 | body text, icons, lines |
| Forest Green #3A7848 | 4.96:1 | body text, icons, lines |
| Warm Clay #B86048 | 4.09:1 | **fills and icons only — not body text** |
| Dark Ochre #A87820 | 3.66:1 | **fills and icons only — not body text** |
| Warm Amber #C08A18 | 2.85:1 | **large fills only — fails 3:1, no text, no thin lines** |

**Warm Amber is the trap in this palette.** At 2.85:1 on canvas it fails even the 3:1 UI
threshold. Use it for large filled shapes where nothing depends on reading an edge. When amber
must carry text or a thin line on a light ground, substitute **Warm Amber 900 #664808** (7.87:1).
Same substitution for Dark Ochre → **#584008** (9.13:1) and Warm Clay → **#5C2820** (11.04:1).

---

# DARK MODE

Neutral warm-grey ground — not black. Accents shift up the ramp: **300 for text and icons,
500 for fills**. The 700 stops are unusable here (1.63–2.76:1) and must never be placed on a
dark ground.

| Token | Hex | Ratio on Surface | Use |
| :--- | :--- | ---: | :--- |
| Canvas / Page | #1E2022 | — | Page background |
| Surface | #26292C | — | Cards, panels, raised areas |
| Surface Elevated | #303438 | 1.17:1 | Modals, popovers, hover surfaces |
| Grid Lines | #3A3F44 | 1.37:1 | Chart grid, faint dividers |
| Border / Axis | #4E545B | 1.91:1 | Default borders, axis lines — decorative |
| Border Strong | #727982 | 3.32:1 | **Meaningful boundaries, focused inputs, control outlines** |
| Text Primary | #F2EEE9 | 12.66:1 | Body copy, headings |
| Text Secondary | #BFC4C9 | 8.33:1 | Labels, captions |
| Text Muted | #8B9198 | 4.60:1 | Placeholder, disabled |

**Lines and such — pick by job, not by habit.** `Border / Axis #4E545B` is the everyday line:
it reads as structure without competing, but at 1.91:1 it is decorative and must not be the only
thing communicating a boundary. When a line *carries meaning* — a focused input, a selected
state, the edge of an interactive control — use `Border Strong #727982` (3.32:1), which meets
the non-text contrast requirement.

**Measured on Surface #26292C**

| Color | 300 (text + icons) | 500 (fills) | 700 |
| :--- | :--- | :--- | :--- |
| Dark Teal | #96C8D0 — 7.99:1 | #488FA0 — 3.98:1 | 1.63:1 ✗ |
| Burnt Orange | #D4906A — 5.57:1 | #B86030 — 3.31:1 | 2.06:1 ✗ |
| Periwinkle | #9AAAD8 — 6.35:1 | #6878C0 — 3.51:1 | 2.52:1 ✗ |
| Warm Amber | #EECC78 — 9.43:1 | #D4A030 — 6.18:1 | 4.80:1 |
| Warm Clay | #D8A898 — 6.95:1 | #C07858 — 4.23:1 | 3.35:1 |
| Forest Green | #80C498 — 7.15:1 | #509870 — 4.22:1 | 2.76:1 ✗ |
| Dark Ochre | #E0C060 — 8.27:1 | #C09030 — 5.07:1 | 3.74:1 |
| Crimson | #E09888 — 6.28:1 | #C86858 — 3.88:1 | 2.40:1 ✗ |

Warm Amber inverts between modes: the weakest color on light is one of the strongest on dark.

**Dark-mode colorblind warning.** The palette's colorblind safety does *not* survive the shift to
the 300 stops. Measured perceptual distance between the lighter tints:

| Pair (300 stops) | Normal | Deuteranopia | Protanopia |
| :--- | ---: | ---: | ---: |
| Teal + Orange | 54.9 | 47.7 | 36.8 |
| Orange + Periwinkle | 58.3 | 62.4 | 52.7 |
| **Teal + Periwinkle** | 26.0 | **17.0** | **21.3** |

Teal and Periwinkle at the 300 stop are effectively the same color to a deuteranope. **Never use
Teal 300 and Periwinkle 300 as two categories in the same dark-mode view.** Separate them by
value (one at 300, the other at 500) or replace one with Burnt Orange.

---

# ACCENT SCENARIOS

Three interchangeable schemes. Pick one per product, surface, or asset family and hold it.
Each names a **lead**, a **secondary accent** drawn from the other two primaries, and a
**supporting color** from the extended range. Secondary accents were chosen by measured
separation, including under simulated color vision deficiency.

### Scenario A — Teal Led
*Calm, technical, institutional. Default for dashboards, tooling, documentation.*

| Role | Color | Light | Dark |
| :--- | :--- | :--- | :--- |
| Lead accent | Dark Teal | #254F58 | #96C8D0 / #488FA0 |
| Secondary accent | Burnt Orange | #8F4218 | #D4906A / #B86030 |
| Supporting | Warm Amber | #664808 text / #C08A18 fill | #EECC78 / #D4A030 |
| Neutral ground | Canvas + Border/Axis | #FAF7F2 / #C4BDB5 | #1E2022 / #4E545B |

Separation: Teal + Orange = 64.5 normal, 56.8 deuteranopia, 39.9 protanopia. Safe.
Periwinkle is deliberately absent — against a teal lead it measures only 40.8 and drops to 35.7
under deuteranopia.

### Scenario B — Burnt Orange Led
*Warm, energetic, human. Suits consumer surfaces, game UI, marketing, physical print.*

| Role | Color | Light | Dark |
| :--- | :--- | :--- | :--- |
| Lead accent | Burnt Orange | #8F4218 | #D4906A / #B86030 |
| Secondary accent | Periwinkle | #4C62A8 | #9AAAD8 / #6878C0 |
| Supporting | Warm Amber | #664808 text / #C08A18 fill | #EECC78 / #D4A030 |
| Neutral ground | Canvas + Border/Axis | #FAF7F2 / #C4BDB5 | #1E2022 / #4E545B |

Separation: Orange + Periwinkle = 81.3 normal, 89.2 deuteranopia, 75.9 protanopia. **The
strongest pairing in the system** — it gets *better* under deuteranopia. Use this scenario when
color must survive poor screens, projection, or print.

### Scenario C — Periwinkle Led
*Cool, modern, editorial. Suits data-heavy products, reports, information design.*

| Role | Color | Light | Dark |
| :--- | :--- | :--- | :--- |
| Lead accent | Periwinkle | #4C62A8 | #9AAAD8 / #6878C0 |
| Secondary accent | Burnt Orange | #8F4218 | #D4906A / #B86030 |
| Supporting | Warm Amber | #664808 text / #C08A18 fill | #EECC78 / #D4A030 |
| Neutral ground | Canvas + Border/Axis | #FAF7F2 / #C4BDB5 | #1E2022 / #4E545B |

Same 81.3 separation as Scenario B with the roles reversed: Periwinkle carries identity, Orange
carries emphasis.

**Variant C2 — all-cool with a warm supporting.** Lead Periwinkle, secondary **Dark Teal**,
supporting **Warm Clay #B86048**. This is the only configuration that gives Warm Clay a
categorical role, because no orange is present. Teal + Periwinkle measure only 40.8, so the two
must be separated by value — lead at 700/300, secondary at 500 — never both at the same stop.

### Where Warm Clay belongs

Warm Clay measures **ΔE 16.6 from Burnt Orange** — they are value siblings, not distinct hues.
Because Burnt Orange appears in Scenarios A, B, and C, Clay is not a categorical accent in any
of them. Its real roles:

- warm surface tinting and background washes
- hover, pressed, and secondary states of Burnt Orange
- material and terrain tones in game assets, where hue proximity reads as cohesion
- a second warm in any composition that contains **no** Burnt Orange (see C2)

Never encode Clay and Orange as two different meanings in one view.

---

# SEQUENTIAL PALETTES
Darker = higher value on light backgrounds   Stop 700 = brand anchor color

### BRAND COLOR PALETTES

| Color | 100 | 300 | 500 | 700 ← base | 900 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Dark Teal | #EBF4F6 | #96C8D0 | #488FA0 | #254F58 | #122A30 |
| Burnt Orange | #FBF0E8 | #D4906A | #B86030 | #8F4218 | #4A2010 |
| Periwinkle | #EEEFF8 | #9AAAD8 | #6878C0 | #4C62A8 | #263060 |
| Warm Amber | #FDF4E0 | #EECC78 | #D4A030 | #C08A18 | #664808 |
| Warm Clay | #F8EDE8 | #D8A898 | #C07858 | #B86048 | #5C2820 |

### STATUS COLOR PALETTES

| Color | 100 | 300 | 500 | 700 ← base | 900 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Forest Green | #EAF3EC | #80C498 | #509870 | #3A7848 | #1C4028 |
| Dark Ochre | #FAF3DC | #E0C060 | #C09030 | #A87820 | #584008 |
| Crimson | #FCECEA | #E09888 | #C86858 | #B03828 | #581810 |

**Stop selection by ground:** 100 for tinted fills on light · 700 for accents on light ·
300 for accents on dark · 500 for fills on either · 900 for text on light where the 700 is too weak.

---

# APPLICATION

### UI and UX

| Element | Light | Dark |
| :--- | :--- | :--- |
| Primary action | Lead 700, text #FAF7F2 | Lead 500, text #1E2022 |
| Secondary action | Border Strong #8F887F, text Lead 700 | Border Strong #727982, text Lead 300 |
| Focus ring | Periwinkle 500 #6878C0 (3.90:1) | Periwinkle 500 #6878C0 (3.51:1) |
| Selected row | Lead 100 | Lead 700 at reduced opacity over Surface |
| Disabled | Text Muted on Surface Sunken | Text Muted on Surface |
| Destructive | Crimson #B03828 | Crimson 300 #E09888 |

Periwinkle 500 is the focus ring in both modes — the only accent clearing 3:1 against light and
dark grounds simultaneously, so focus behaves identically across themes.

### Icons

Stroke icons take the accent at text weight: 700 on light, 300 on dark. Filled icons may use 500
in either mode. An icon that carries meaning alone needs 3:1 against its ground — check Warm
Amber on light, which does not meet it.

### Design systems and tokens

Map to semantic names, not color names, so scenarios can be swapped without touching components:
`--accent-lead`, `--accent-secondary`, `--accent-supporting`, `--surface`, `--surface-elevated`,
`--border`, `--border-strong`, `--text-primary`, `--text-secondary`, `--text-muted`.
Switching scenario means rebinding three variables. Switching mode means rebinding the ramp stop
for accents and the whole neutral set.

### Data visualization

Categorical order stays Teal → Orange → Periwinkle → Amber → Clay, capped at three series where
color alone distinguishes them. Beyond three, add shape, texture, or direct labels. In dark mode
apply the Teal/Periwinkle warning above. Sequential encodings use one column of the ramp,
100 → 900. Status colors never enter a categorical sequence.

### Game assets

Scenario B or C2 suit game surfaces: B for warm-led worlds, C2 for cool-led. Warm Clay and Warm
Amber carry material and terrain tone; the three primaries carry faction, team, or state
identity where players must tell them apart at speed and small size — use the 700/300 stops for
those, never 500 against a mid-value background. Reserve the status trio for player feedback
only, so green/ochre/crimson never read as decoration.

---

# USAGE GUIDE — Brand Color System
How to use colors:

### RULES & PRINCIPLES

| Rule | Guideline |
| :--- | :--- |
| 01 Color order | Always assign in order: Teal → Orange → Periwinkle → Amber → Clay. Skipping colors is allowed, as long as the end result is balanced for the visual's intended use. |
| 02 Consistency | Ensure consistency with exact color properties. |
| 03 Category limit | Ensure color balance and harmony at all times. Three categorical colors maximum where color alone carries the distinction. |
| 04 Sequential palettes | Use single-color sequential strips (100–900) for gradation. |
| 05 Status isolation | Crimson (#B03828) = error only. Dark Ochre (#A87820) = warning only. Forest Green (#3A7848) = success only. Use for creating specific assets with this brand color system. |
| 06 Colorblind safety | Teal + Orange + Periwinkle are safe at the 700 stops. At the 300 stops used in dark mode, Teal + Periwinkle fail (ΔE 17.0 deuteranopia) — separate by value or substitute Orange. Warm Amber and Warm Clay are similar under protanopia. |
| 07 Stop by ground | 700 accents on light, 300 accents on dark. Never place a 700 accent on a dark ground. |
| 08 Contrast floor | 4.5:1 body text, 3:1 large text / icons / meaningful boundaries. Warm Amber on light canvas meets neither — substitute the 900 stop. |
| 09 One scenario | One accent scenario per product, surface, or asset family. Mixing leads dissolves the identity. |
| 10 Clay placement | Warm Clay is never a categorical partner to Burnt Orange (ΔE 16.6). Tint, state, and material only. |

### QUICK REFERENCE — COLOR ORDER FOR CHART SERIES

* Dark Teal  #254F58  →  primary
* Burnt Orange  #8F4218  →  primary #2
* Periwinkle  #4C62A8  →  primary #3
* Warm Amber  #C08A18  →  extended
* Warm Clay  #B86048  →  extended
* Forest Green  #3A7848  →  reserved, positive
* Dark Ochre  #A87820  →  reserved, caution/alert states
* Crimson  #B03828  →  reserved, bad/failure/negative only


This file installs to `assets/prompt-attachments/brand/asset_color_system.md` in the target
project, where it is read-only reference material for the Prompt Agent and Code Agent per
§3.2/§3.3 of `cli_host_workflow_guide-v2.4.1.md`.

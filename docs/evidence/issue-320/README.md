# Issue #320 — deeper purple and darker cool-gray Light theme

Candidate **v0.1.0.85**, recorded 2026-10-10 against accepted `main`
`8b4a11ff1cf68bd570c61f54585788dd45bbaedc` (owner-merged PR #321).
Linux/KDE, Godot 4.7.2, NVIDIA RTX 3070 Ti. **Pending owner implementation review.**

Issue #320 was the top and only Ready item. Its exact existing issue-linked branch
`320-ux-theme-refine-light-theme-clarity-with-deeper-purple-and-darker-cool-gray-surfaces`
was already checked out, clean, and equal to accepted main before edits. Required
#310/#316 work, including owner-merged PR #319, was present. Previous PR #321 was
verified merged and present, remote references were pruned, and the completed
local #318 branch was already absent. No replacement branch was created.

## Flagged pin option and owner approval

The initial full-UI options explicitly distinguished
[retaining the existing #7956C8 Simulation/pin accent](options/keep-7956c8.png)
from [sharing #563493 between the heading and all three pins](options/shared-563493-approved.png).
These are proposal images, not final implementation screenshots.
The owner replied **“Approve shared #563493 heading/pin accents (recommended)”**
before production pin accents changed. This authorizes the shared accent choice;
final implementation acceptance still awaits owner review.

## Palette and component decisions

The [current theme guide](../../APPLICATION_THEMES.md) lists the before/after roles.
The shaded foundation is #E1E3EA, gradient highlight #EEF0F5, inputs #D6DBE6 and
dialogs #E5E8EF. Deep heading/accent ink is #563493; expanded/selected heading
ink is #452776. Secondary and muted labels deepen while primary/numeric ink,
focus, disabled, status, tier and separate identity colors stay unchanged.

This retains brighter panel highlights rather than flattening every gray into
#E1E3EA. Input/dropdown boundaries use the shared active-border role, within
existing margins. Light switches gain white knobs, and enabled slider thumbs
gain a white outline against the darker track; their dimensions do not change.
Dark follows the original code branches and original artwork.

An early #D1C5E5 pressed proposal reduced success-ink contrast to 4.12:1. The
chosen #D9D0E9 retains the semantic-state checks while giving distinct pressed
feedback. Stronger accents and outlines improve separation; physical comfort
and whether the overall balance feels too heavy remain owner judgments.

Fonts, geometry, navigation, pin silhouettes/hover motion, theme persistence,
About assets, scientific resources, capture/export code and data behavior remain
unchanged. The theme audit now explicitly commits the mixed fixture before
scientific comparison, avoiding a possible comparison of empty opening frames.
No production loading behavior changes.

## Focused validation

| Check | Result |
| --- | --- |
| Accepted main native Forward+ theme audit | 61,778 checks, clean completion |
| Candidate native Forward+ theme audit | 61,779 checks, clean completion |
| Candidate native Compatibility theme audit | 61,779 checks, clean completion |
| Semantic palette arithmetic | 119 pairs passed in both source audits |
| Actual native control/state/layout comparisons | 29 sampled comparisons passed; inactive dropdown reported as an exception |
| Active input/dropdown boundaries | Four resolved boundary/fill comparisons ≥3:1 |
| Enabled switch/slider artwork | Four resolved source-artwork comparisons ≥3:1 |
| Three pins, Space twice each | All toggle and restore checks passed on accepted/candidate |
| Dark theme resource descriptions / restored Dark screenshot | Identical to accepted main |
| Loaded scientific viewport before/after | Pixel-identical on the committed mixed fixture |
| Capture bytes during each measurement/audit | Unchanged SHA-256 |
| Candidate Compatibility package cycle | 61,773 assertions, zero failures; **strict wrapper failed on shutdown diagnostics** |
| Accepted main Compatibility package cycle | 61,772 assertions, zero failures; same shutdown diagnostics |
| Candidate packaged fresh Light / Dark restart | 4 / 2 checks, clean completion |
| Version tests / Python compilation / whitespace | Two version tests passed; compilation and `git diff --check` passed |

The source audits exercise empty/loaded shell, three workspaces, expanded and
scrolled panels at ordinary/compact sizes, dialogs, selected menu, native hover,
focus, disabled controls, Light↔Dark geometry/state restoration, saved preferences,
About resources, and viewport-only scientific isolation. The additional fixture
assertion accounts for the one-check difference from the accepted-main audit.
This is a shared-theme subsystem change, so these connected UI paths are relevant;
unrelated camera, payload-format, playback-core and export suites were not run.

[Raw checks](checks/) retain renderer reports, palette pairs, logs, before/after
resource/sample records, package artifact hashes, and hashes of untouched tracked
viewer/exporter files. Package binaries, captures, caches and profiles are excluded.
The original #310/#316/#318 reports are preserved as historical records.

## Measured pairs and interpretation

[Contrast comparison JSON](checks/contrast-comparison.json) records full precision,
individual gradient samples, control tint, before ratios and applicable exceptions.
Foreground values are resolved theme ink multiplied by recorded control modulation;
backgrounds are actual rendered blank-area pixels. Antialiased glyph-edge pixels
are not used as foreground colors. Switch/slider SVG pairs and resolved borders
are reported separately from raster background sampling.

| Sample | Before | Candidate |
| --- | --- | --- |
| Simulation across ordinary/compact/2× gradient samples | 4.64–4.68:1 | 7.91–7.98:1 |
| Resting pins, including 0.94 tint | 4.88–5.14:1 | 7.95–8.54:1 |
| Dropdown normal | 10.39:1 | 9.48:1 |
| Dropdown hover | 10.29:1 | 10.17:1 |
| Dropdown pressed, including 0.94 tint | 6.19:1 | 7.49:1 |
| Numeric input normal/focus | 11.55:1 | 10.49:1 |
| Numeric selected text | 6.60:1 | 8.13:1 |
| Read-only numeric ink | 6.43:1 | 7.36:1 |
| Disabled dropdown | 3.74:1 | 3.41:1 (inactive exception) |
| Enabled switch knob versus on/off track, resolved artwork | — | 9.10 / 5.14:1 |
| Slider outline versus track, resolved artwork | — | 5.14:1 |

Darker backgrounds reduce contrast for some already dark text; these pairs retain
substantial headroom. The deeper accent gives more heading and selected-state
headroom. Criteria are [WCAG 2.2 text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
where applicable: normal text 4.5:1, meaningful non-text 3:1, with inactive and
decorative exceptions. This measured subset is not complete WCAG certification
and does not establish prolonged-session comfort.

## Before / after images

- Empty: [before](before/empty-light.png) / [after](after/empty-light.png).
- Expanded ordinary: [before](before/expanded-light-1440.png) / [after](after/expanded-light-1440.png).
- Expanded compact: [before](before/expanded-light-970.png) / [after](after/expanded-light-970.png).
- Simulated 2×: [before](before/expanded-light-3840.png) / [after](after/expanded-light-3840.png).
- Fields: [before](before/fields-light.png) / [after](after/fields-light.png).
- Meshes: [before](before/meshes-light.png) / [after](after/meshes-light.png).
- Focused/selected numeric input: [before](before/input-focus.png) / [after](after/input-focus.png).
- Read-only input: [before](before/input-readonly.png) / [after](after/input-readonly.png).
- Source probe: [before](before/source-probe.png) / [after](after/source-probe.png).
- Global effects: [before](before/global-effects.png) / [after](after/global-effects.png).
- About: [before](before/about-light.png) / [after](after/about-light.png).
- Dropdown [hover](after/dropdown-hover.png), [pressed](after/dropdown-pressed.png), [disabled](after/dropdown-disabled.png); matching before images retained.
- Further candidate states: [menu selection](after/view-menu-selected-light.png), [disclosure hover](after/disclosure-hover-light.png), [compact scrolled](after/scrolled-970x600-light.png), [warning](after/status-warning-light.png), [error](after/status-error-light.png), [Jobs](after/jobs-light.png), [Video Export](after/video-light.png).
- Restored Dark: [before](before/dark-restored.png) / [after](after/dark-restored.png), pixel-identical.

## Failures, unavailable checks and reproduction

The strict package cycle emits four engine shutdown errors disconnecting
`focus_entered`/`tree_exited` connections from the root Window. Accepted main
reproduces the same diagnostics; neither package cycle is counted as a clean pass.
Independent packaged fresh Light/Dark processes complete cleanly. Forward+
packaged execution was not run; Compatibility is the focused package boundary.

An initial source import recreated five already-missing shell UID sidecars from
cache. A warm import completed without warnings/errors; the incidental sidecars
are excluded from this issue. A disposable preview harness that drove the normal
paused `_process` path stalled awaiting a rendered frame after idle pacing took
effect. It timed out and is not counted as validation. Later review measurements
use a synchronous committed synthetic sample and complete cleanly. Early preview
harness iterations also corrected an abandoned alternative's Dark-token lookup
and reused-fixture path handling; those are not production changes or test passes.

The requested 3840×2160 native window was clamped by the compositor to **2560×1394**.
The image named `expanded-light-3840.png` records that actual raster at 2× content
scale. It is simulated scaling evidence, **not physical KDE/4K acceptance**.
No physical mouse/keyboard, mixed-DPI, other-OS or prolonged comfort session was
performed. Automated input events test the production callbacks, not physical feel.

Reproduce source audits with `tools/validate_application_theme.py --godot <external-godot>
--renderer forward_plus|gl_compatibility --output-dir <new-directory>`; add
`--package` for the disposable package. Review measurements use
`python docs/evidence/issue-320/run_measurements.py --godot <external-godot>
--output <new-directory>`; `--project <accepted-archive>/viewer` supplies the baseline.
Run `compare_measurements.py <before-directory> <after-directory> --output <json>`
for the sampled comparison (Python/Pillow required). Original binaries/templates
remain external.

## Owner verification before acceptance

1. On the physical KDE/4K display, select Light before opening a capture. Inspect
   toolbar/transport/Simulation grouping and the shared heading/all-three-pin ink.
2. Open a representative capture; compare Particles, Fields and Meshes. Expand
   Rendering and Color Mapping, then resize to compact and scroll. Inspect labels,
   numeric inputs, dropdown outlines and disabled states at normal desktop scaling.
3. Hover and keyboard-focus headings, pins, switches, sliders and dropdowns. Toggle
   each pin by mouse and Space, exercise edge reveal, and confirm familiar behavior.
4. Review Source probe, Global effects, About, Jobs and Video Export. Check input
   selection/read-only contrast, status meanings and the unchanged About artwork.
5. Toggle Light→Dark→Light without reloading. Confirm Dark appearance, scientific
   colors and camera/data state remain familiar; restart to confirm saved choice.
6. Use Light for a comfortable viewing session. Judge the stronger outlines,
   differentiated grays and deeper accents together before approving the PR.

No merge, auto-merge, issue closure or Project transition was performed.

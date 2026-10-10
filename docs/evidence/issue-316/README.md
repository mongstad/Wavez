# Issue #316 — Simulation heading and pin accent

Candidate **v0.1.0.83** awaits owner review. The sole Ready issue was #316,
**UX-THEME — Align Simulation heading with pin accent in Light theme**.
Its existing linked branch
`316-ux-theme-align-simulation-heading-with-pin-accent-in-light-theme` was clean,
checked out and equal to accepted `main` at
`9927d6386c1a1bc390508222d9a47ef48508d1e7` (owner-merged PR #317).
No required predecessor work was missing; no prior local issue branch remained.

## Measured baseline and implementation

The Light Simulation heading resolved to `text.title` **#7050B8**, while all
three pin controls (top/right/bottom) resolved to `accent.primary` **#7956C8** in
normal, hover, pressed, hover-pressed, focus and disabled states. Pinned/unpinned
silhouettes share this same ink. Existing pin hover modulation remains unchanged.

The heading now uses a dedicated `SimulationTitle` variation that inherits
`PanelTitle` typography and uses the existing pin accent in Light. In Dark it
retains **#7270D8**. Other headings, theme tokens and pin definitions are unchanged.
The only production edits are the role definition, the Simulation label binding
and the required candidate build increment from accepted build 82 to 83.

At ordinary size the rendered heading background is **#F0F1F5**:

| Heading ink | Contrast against #F0F1F5 |
| --- | ---: |
| Previous #7050B8 | 5.27:1 |
| Existing pin accent / candidate heading #7956C8 | 4.68:1 |

Across normal, compact and simulated 2× layouts, sampling the rendered background
beside the heading at its top/center/bottom gives a candidate minimum of **4.64:1**.
The existing pin color is adequate against this actual heading background, so it
was preserved. Matching the pin accent slightly lowers numerical contrast from
the previous darker title ink; this is an accent-consistency change, not a claimed
contrast-ratio increase or accessibility certification. Subjective readability
and physical-display approval remain owner checks.

## Before/after evidence

Native Forward+ / KDE Wayland, Godot 4.7.2, RTX 3070 Ti. Accepted-main copies were
archived/imported outside the implementation checkout. Root texture images are
unobstructed and show the heading with the existing pin controls.

| State | Before | After |
| --- | --- | --- |
| Light, 1440 × 900, pinned | [Before](before/light-1440-pinned.png) | [After](after/light-1440-pinned.png) |
| Light, 1440 × 900, unpinned | [Before](before/light-1440-unpinned.png) | [After](after/light-1440-unpinned.png) |
| Light, 970 × 600, pinned | [Before](before/light-970-pinned.png) | [After](after/light-970-pinned.png) |
| Light, simulated 3840 × 2160 / 2×, pinned | [Before](before/light-3840-pinned.png) | [After](after/light-3840-pinned.png) |

[Dark after](after/dark-1440-pinned.png) is pixel-identical to its accepted renderer
baseline, including typography and pin appearance.

## Focused validation

The retained measurement script instantiates the production viewer and records
14 layout states: Dark/Light, normal/compact/simulated 4K × pinned/unpinned, plus
hide/show reopening in each theme. It repeats Light ↔ Dark cycles, records all
three pins' six state colors/style metrics and glyph hashes, checks Space-toggle
and focus behavior, and records native hover. Separate fresh processes restore
Light and Dark from isolated preferences. The comparator validates recorded
geometry, typography, pins, other-title ink and pixel differences against the
corresponding accepted renderer baseline.

| Run | Result |
| --- | --- |
| Source Forward+ | 14 layout/pin/color states matched; keyboard/hover records unchanged; fresh Light/Dark restarts passed |
| Source Compatibility | Same focused measurements passed against accepted Compatibility baseline |
| Linux release review package Compatibility | Same focused measurements and fresh Light/Dark restarts passed |
| Native pixel comparison, each run | Dark images identical; Light changed pixels confined to heading bounds |
| Contrast, each run | Minimum 4.63547:1 at the sampled heading background |
| Application version | 2 Python tests, OK; candidate build is main + 1 |
| Whitespace / staged content | `git diff --check` passed; staged names/sizes/credential markers reviewed |

Package import/export passed. The isolated review entry scene instantiates the
production viewer/resources and runs without a source-project path; it is not a
release/distribution artifact. External Godot templates/binaries remain outside
the repository. [Raw reports, comparisons and logs](checks/) are retained.

An initial post-processing assertion incorrectly required hover to own keyboard
focus (the accepted baseline also had focus elsewhere). It was corrected to
compare hover and focus independently. Cross-renderer image comparison also
exposed RGB/RGBA and renderer output differences; comparisons now normalize RGB
channels and use a separate accepted Compatibility baseline. These were comparison
setup mistakes, not passing product checks. All final measurement runs/comparisons completed
cleanly; production code needed no correction after the initial narrow edit.
The required source import initially recreated five pre-existing missing UID
sidecars from cache. An unchanged warm import completed without diagnostics;
incidental sidecars for those unrelated scripts were excluded from this issue.

The scope is deliberately small: the changed label role, direct theme/pin/input
paths, native renderer output and one Linux resource-package boundary. No unrelated
playback, scientific-format, export-worker, camera/navigation or whole-application
regression suite was run. No permanent subsystem regression test was added.

### Reproduction

Set `GODOT` to your externally installed Godot executable, then:

```sh
GODOT=/path/to/godot python docs/evidence/issue-316/run_measurements.py --renderer forward_plus --output /tmp/heading-forward
GODOT=/path/to/godot python docs/evidence/issue-316/run_measurements.py --renderer gl_compatibility --package --output /tmp/heading-package-compat
```

For pixel comparison, run `measure.gd` through the same native renderer against a
fresh imported archive of baseline commit `9927d63`, storing reports/images in `before`
and `before-compat` under a baseline directory. Then run:

```sh
python docs/evidence/issue-316/compare_measurements.py /tmp/heading-forward /tmp/baseline-directory
```

The comparator selects `before-compat` when the candidate output directory name
contains `compat`; otherwise it selects `before`. Scripts and temporary profiles
are measurement aids, not application features.

## Limits and owner verification

Automated high-DPI is simulated. Physical KDE/4K comfort, mixed-DPI display
transitions, actual mouse/keyboard feel and non-Linux platforms remain unverified.
The package check used Compatibility; packaged Forward+ was not rerun for this
label-only change. The measurements use the empty shell, so loaded-scene playback
and scientific payload checks were not run. No scientific/rendering code changed;
pixel comparison confirms the empty viewport and all other visible chrome stayed
unchanged in the measured states.

1. Select **Edit → Preferences → Theme → Light**. Compare the Simulation heading
   with the top/sidebar/bottom pins at ordinary and compact sizes.
2. Pin/unpin each region; hover and keyboard-focus each pin, then toggle with
   Space. Confirm glyph, focus/hover feedback and pin/reveal behavior stay familiar.
3. Switch Light → Dark → Light, resize and hide/reveal the sidebar, and restart
   with each saved theme. Confirm other headings and Dark styling are unchanged.
4. Repeat on the physical KDE/4K and mixed-DPI setup. Judge heading readability
   and accent consistency before acceptance.

Earlier historical reports/evidence were preserved as written. No owner acceptance,
merge, auto-merge, issue closure or Project transition is claimed for this candidate.

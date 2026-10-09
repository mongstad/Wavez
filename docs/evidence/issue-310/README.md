# Issue #310 — cool light-gray Light palette

Candidate **v0.1.0.81**, based on accepted `main`
`ceb3ba2796538ee99562f3ac5b0fd696cfbf7463` (owner-merged PR #311).
Recorded 2026-10-09/10, Linux, Godot 4.7.2, RTX 3070 Ti.
**Pending owner physical review.**

Issue #310 was the only Ready item. The exact GitHub-linked branch
`310-ux-theme-soften-light-theme-to-cool-light-gray-surfaces` was already checked
out, clean and equal to accepted main. Required Light implementation PR #304 was
merged and included. Prior PR #311 was merged and present; references were pruned,
and no completed local issue branch remained. No branch replacement was made.

## Modification and boundary

The owner found the accepted Light chrome too white for prolonged use. Its
foundation `#F7F8FC` and dialog/highlight `#FAFAFF` are replaced with differentiated
cool gray surfaces. Only the shared Light color dictionary changes production
styling; the required application build advances once from 80 to 81.

| Role | Candidate |
| --- | --- |
| Shell foundation / shaded surface | `#E6E8EF` |
| Panel highlight / panel fill | `#F0F1F5` |
| Input/control fill | `#E2E5ED` |
| Dialog surface | `#ECEEF3` |
| Hover / selection | `#DDD5F0` |
| Pressed | `#D8CFEC` |
| Primary ink | `#25283A` (retained) |
| Primary accent | `#7956C8` (retained) |
| Section/title ink | `#7050B8` |
| Focus | `#596DBC` |

Muted/secondary/disabled ink, control borders, teal tier ink and semantic status
colors are adjusted for these darker surfaces. Icon tints derive from those same
tokens. White remains in the approved official Light About artwork and the
accent-button foreground. User-facing choice remains **Light**, with the existing
live switching and local persistence implementation.

Theme builders, Dark tokens, switching code, layouts, metrics, fonts, wording,
shortcuts, controllers, scientific resources and export implementation are
unchanged. `protected-files.json` records 631 tracked viewer/exporter files that
remain byte-identical to accepted main (excluding palette, build and test harness).
No new render pass, buffer, production node, per-frame update or dependency is added.

## Focused results

| Validation | Result |
| --- | --- |
| Accepted main source, each renderer | 61,778 checks, clean completion |
| Candidate source Forward+ | 61,778 checks, clean completion |
| Candidate source Compatibility | 61,778 checks, clean completion |
| Candidate Linux validation package cycle, each renderer | 61,772 UI assertions, 0 assertion failures; **strict wrapper failed on shutdown diagnostics** |
| Accepted main Linux package Forward+ cycle | Same 61,772 assertions and shutdown diagnostics; not counted as a clean pass |
| Candidate Linux package fresh Light restart, each renderer | 4 checks, clean completion |
| Candidate Linux package fresh Dark restart, each renderer | 2 checks, clean completion |
| Contrast arithmetic | 119 pairs passed: selected active text pairs ≥4.5:1; selected disabled/focus/boundary pairs ≥3:1 |
| Exact Dark/scientific image comparisons | 124 complete image pairs identical; 12 About pairs identical outside the required final build digit |
| Run-specific dialog images | 8 raw pairs retain differing paths; four additional shared-path Status details/file-picker pairs are pixel-identical (included in the 124) |
| Real PNG/MP4 regression, accepted/candidate × both renderers | 44 checks per run, 176 total; 8 MP4 jobs completed |
| Actual export comparison | 14 PNG pairs identical; four MP4 pairs have all 12 decoded RGB frames identical |
| Version / Python / whitespace | 2 unit tests passed, Python compilation and `git diff --check` passed |
| Normal production Linux build | Exported; hashes in `production-linux-build.json` |
| Logical 4K review | Actual 3840×2160 raster; clean test-only viewport-scale run |

The shell audit compares visible geometry, minimum sizes, font family/size,
tooltips, focus modes/order and VisualState across Dark → Light → Dark with a
mixed WVZ1 capture loaded. It covers all three Simulation workspaces; 1440×900
and 1024×640 shell/About; 970×600 and normal expanded/scrolled controls; native
pointer hover; focused Bloom; selected View menu; success/warning/error badges;
Jobs; Video Export; shortcuts; File Locations; Tools; Status details and embedded
file-picker fallback. Disabled controls are present in Jobs and empty/restart
states. It checks unchanged scientific legends, exact chrome-hidden mixed-scene
pixels and no idle theme rebuild loop. Source fixture hashes are checked unchanged.

Contrast is token arithmetic, not whole-product accessibility certification or
physical comfort testing. Actual focus/hover/status images supplement it. Existing
widget modulation, dimensions, timing and native OS picker integration are retained.

`pixel-comparisons.json` retains every raw difference. The only build mask is the
manually verified **12×16 pixel final About build digit**, never an entire dialog.
Status details and embedded picker paths differ between isolated directories;
`chrome-compare.gd` opens the same absolute capture/directory for both revisions
and proves those two Dark states exactly in both renderers. Eight chrome-hidden
mixed-scene render comparisons are included in the exact image count.

The existing selection PNG/video regression uses three 640×360 frames at 4 FPS,
normal and delayed rendering, restored PNG/inspection state and the real GPU/
FFmpeg worker. Both candidate runs use a saved Light preference. It checks source
checksums, timings, exact selection membership/positions and image/recipe hashes.
These video fixtures are particles plus selection markers; the mixed-scene pixel
audits cover fields/meshes. No new scientific or export implementation is involved.

## Evidence and reproduction

- Normal [before](before-shell-1440x900-0-light.png) / [after](after-shell-1440x900-0-light.png).
- Expanded [before](before-expanded-1440x900-light.png) / [after](after-expanded-1440x900-light.png).
- Minimum, scrolled [before](before-scrolled-970x600-light.png) / [after](after-scrolled-970x600-light.png), and [expanded minimum](expanded-970x600-light.png).
- [Dark reference](shell-1440x900-0-dark.png), [focused slider](global-focused-light.png), [menu selection](view-menu-selected-light.png), [hover](disclosure-hover-light.png).
- [Jobs](jobs-light.png), [Video Export](video-light.png), [warning](status-warning-light.png), [error](status-error-light.png).
- Packaged fresh About: [Forward+](forward-about-light.png), [Compatibility](compatibility-about-light.png).
- [Full 3840×2160 logical review image](light-3840x2160.png).

Reproduce the source or diagnostic release audits:

```bash
python tools/validate_application_theme.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /absolute/new/source-output
python tools/validate_application_theme.py --godot /absolute/path/to/godot \
  --package --renderer gl_compatibility --output-dir /absolute/new/package-output
```

Import a fresh source project with Godot `--headless --editor --import` first.
Repeat with the other renderer. Package validation changes only the staged entry
scene to drive packaged production resources, runs outside the development tree
without `--path`, and remains distinct from the normal production build.

The retained `chrome-compare.gd`, `finish-validation.py`, `final-matrix.py`
and `collect-evidence.py`
record the supplemental runs and comparison method. Raw run directories and the
normal candidate binary remain outside Git at
`/home/Nozba/Codex/Wavez/light-310/`. `sha256.json` covers retained evidence files.

## Failures and remaining limits

Final evidence inspection caught live status refresh replacing the synthetic
warning/error previews with Ready. The harness now pauses only its status refresh
while those previews are captured, restores processing afterward, and reruns the
accepted/source/package matrix. No application behavior was changed for this.

The initial accepted source launch lacked its imported-resource cache. It was
stopped after resource/preload errors, then imported and rerun cleanly. The first
candidate import regenerated five unrelated missing UID sidecars from cache;
these incidental files were removed, not added to this palette change.

Packaged cycles complete all UI assertions, then emit four engine diagnostics:
`Attempt to disconnect a nonexistent connection`, for root Window `focus_entered`
and `tree_exited`. The identical failure reproduced on accepted main with the
extended harness before correcting its status-preview refresh. Releasing focus/waiting for native frames and leaving the
viewer alive until tree teardown did not fix it; those ineffective experiments
were reverted. **Neither packaged full cycle is claimed as a clean pass.** The
separate package restart runs exit cleanly. The underlying shutdown cause is
unresolved, and normal production physical close behavior remains owner review.

One additional package import exited unsuccessfully after a complete log with no
error diagnostics; the unchanged retry imported/exported successfully. Its log is
retained. Full failed cycle logs and accepted-main comparison logs are retained.

Wayland clamps an oversized native window to the current display. The final 4K
image therefore uses test-only `CONTENT_SCALE_MODE_VIEWPORT` with a verified
3840×2160 render size. It is a logical-area preview, **not physical Fedora/KDE 4K
or mixed-DPI evidence**. No production scale behavior was changed.

Physical pointer/keyboard feel, long-session visual comfort, physical 4K/mixed-DPI,
other operating systems, long captures/videos and native OS file-picker appearance
were not verified. No unrelated camera/playback/cache/analysis full suite or GPU
benchmark was run: those implementations are unchanged and this is a palette-only
blast radius. Historical #289/#306 review reports and wording remain untouched.

## Owner verification

1. Run the normal `production-linux/WAVEZ.x86_64` with Forward+ and Compatibility
   on physical Fedora/KDE 4K. Inspect the full-size images above and judge prolonged
   Light comfort, surface hierarchy, lavender selection and readable ink.
2. Open a WVZ1 capture; switch Dark → Light → Dark. Inspect particles, fields,
   meshes, scientific legends and overlays; confirm Dark appearance is preserved.
3. Inspect normal, compact/minimum, expanded/scrolled panels, menus, hover,
   keyboard focus, disabled controls, Jobs and Video Export. Controls/layouts and
   interactions should match accepted main.
4. Restart in each theme; check the selected menu choice and official About logo,
   links, notices and closing behavior. Check physical window/app closure, given
   the diagnostic-entry shutdown limitation above.
5. Export the same scientific view in both themes and compare the image/video.

Keep the issue open and stop for owner review. No merge, auto-merge, issue closure
or Project transition is performed by this implementation.

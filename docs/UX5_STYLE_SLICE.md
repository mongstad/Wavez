# Violet visual-system review slice — #143

Issue [#143](https://github.com/mongstad/SimScope/issues/143) was the first and
only **Ready** item when selected on 2026-09-29. This implementation is a
representative production slice, **pending owner visual review**. The issue
requires approval of this slice before broader propagation. It does not claim
completion or acceptance of the whole application restyle.

The primary visual target is the owner-provided **SimScope Scientific UI Style
Reference**, attached to the issue. Its local source is
`SimScope Theme Package/simscope_scientific_ui_style_reference.png` outside the
repository. The reference supplies the visual direction, while the accepted
application layout and scientific controls retain their behavior.

## Implemented scope

- The real top application bar, its existing menus/submenus, and local pin.
- The right-panel foundation, header/pin, category segments and compact chooser.
- The existing particle **Rendering** and **Color Mapping** groups: sliders,
  switches, selectors, numeric inputs, disclosure headers and their popups.
- The real playback/status strip: sample actions, playhead, speed input, Loop,
  Jobs entry, status readout and bottom pin.

Navigation buttons in the viewport, Particle Filters, Advanced, Fields/Meshes,
Tools, Jobs content, dialogs/file pickers and About retain the accepted theme.
Purple-logo replacement and the remaining surfaces are deferred until slice
approval. Their retained styling is intentional at this review boundary.

![Production slice at 1440 by 900](evidence/issue-143/slice-1440.png)

![Production slice at 1024 by 640](evidence/issue-143/slice-1024.png)

Additional native review images: [keyboard focus](evidence/issue-143/focus-1440.png),
[View popup](evidence/issue-143/menu-1440.png),
[selector popup](evidence/issue-143/selector-1440.png) and
[empty capture with disabled transport](evidence/issue-143/disabled-empty.png).

## Component structure

[`violet_slice_theme.gd`](../viewer/ui/theme/violet_slice_theme.gd) derives from
the existing Theme builder. A single scoped palette owns graphite/navy surfaces,
primary/secondary text, subdued violet selection washes, periwinkle focus and
thin slider accents. The accepted Theme/token resources remain unchanged.
Existing fonts and numeric typography are reused; no font dependency is added.

[`violet_style_slice.gd`](../viewer/ui/shell/violet_style_slice.gd) installs that
Theme on the production slice only. Neutral icon actions have transparent,
borderless rest styles; hover lifts the surface, pressed/pinned states use a
soft violet wash, and keyboard focus keeps its visible two-pixel ring. Category
selection uses an underline plus the restrained wash. Switches use native
CheckButton icons with distinct knob positions, including disabled states.
Their theme keys follow the [Godot CheckButton contract](https://docs.godotengine.org/en/stable/classes/class_checkbutton.html).

Pin/unpin SVG imports now retain scalable SVG source, preserving their resource
UIDs. Their existing filled/rotated silhouettes stay distinct. The slice maps
shell-icon colors to neutral/active theme colors without rewriting the original
SVG artwork or changing actions/tooltips.

Pointer entry/exit triggers an 80 ms brightness fade on slice buttons. Each new
event cancels the preceding fade; the tween stops at its endpoint. There is no
animation process callback, shader time, idle loop or permanent redraw request.

## Preserved contracts

The shell still uses the existing controllers, macro layout, category routing,
source opening, draft/commit inputs, transport, menus and keyboard actions.
Pin state, 10-pixel edge zones, dwell/grace, fullscreen hiding and restoration
remain owned by #117's existing code. Only pin artwork presentation changes.

Scientific colormaps, legends, shaders, renderer settings, source values and
export sampling are unchanged. The timeline's accepted blue/teal readiness band
keeps its semantic colors and endpoint geometry; the playhead alone becomes
violet. Success/info/warning/error remain separate semantic colors, with icons
and text. No scientific rendering code reads the slice palette.

Candidate identity is **v0.1.0.10**, accepted baseline build 9 plus one. It is
unchanged across review commits; reconcile against main before owner merge.

## Validation and limits

The [evidence summary](evidence/issue-143/summary.json) records native Godot
4.7.2/NVIDIA RTX 3070 Ti results, source invariance and renderer comparisons.
All final logs are clean. Results:

| Suite | Forward+ | Compatibility |
|---|---:|---:|
| Slice states, contrast and isolation | 50 PASS | 50 PASS |
| Full shell, routing and scale geometry | 661 PASS | 661 PASS |
| Edge reveal, pins and fullscreen | 210 PASS | 210 PASS |
| Transport and committed clocks | 210 PASS | 210 PASS |
| Redraw pacing and offline isolation | 290 PASS | 290 PASS |
| Current scientific video | 235 PASS | 225 PASS |

Total: **3,302 native checks**, plus **2 Python version tests**. Every source
invariance check passed. Each backend recorded 34 stable idle phases with zero
additional draws per 1.2-second observation. Two mixed-scene scientific export
frames per backend match accepted main exactly, with identical timing manifests.
A 711,550-pixel Forward+ viewport crop also matches the accepted shell baseline.
These comparisons cover the small synthetic fixtures, not universal workloads.

Reproducible focused checks:

```sh
python tools/validate_violet_style_slice.py --godot /absolute/path/godot \
  --output-dir /absolute/new/output --renderer forward_plus
# Repeat with --renderer gl_compatibility.
```

The focused slice suite checks text contrast on five surfaces, flat icon states,
focus, native switch dimensions/state artwork, pin shapes/tooltips, stopped
hover fades, scoped theme boundaries and unchanged scientific state/clock/camera.
The existing shell suite exercises 1440×900, 1920×1080 and 1024×640 plus logical
scale factors 1, 1.25, 1.5 and 2 at the minimum window. Edge/fullscreen, transport,
redraw pacing and current scientific-video suites remain separate regressions.

Physical 4K/KDE or mixed-monitor scaling and subjective contrast/feel require
owner review. Logical scale checks do not establish physical-display quality.
No production-capture 30–60 second GPU utilization/power profile was rerun for
this styling slice; the synthetic redraw suite checks stable idle rendering.
Broader application styling and its full visual acceptance matrix remain deferred.

Initial restricted-display/import attempts were unavailable in the sandbox;
native checks were rerun with desktop access. The initial slice run found a
pin-icon import-type mismatch, and the focused test found missing hover metadata
and an overly broad state assertion including presentation width. These were
corrected before final validation. Historical reports/evidence remain as written.
Visual audit also caught inherited focus/typography falling back to native
defaults; the derived theme now explicitly initializes its parent builder, and
focused assertions lock the intended periwinkle focus and shared text tokens.
The accepted-main idle test also failed two legend-toggle assertions because
#137 starts legends hidden. Its setup now explicitly enables the legend before
testing an on-to-off redraw; product legend defaults remain unchanged.

## Owner verification before broad propagation

1. Run this branch, open a familiar SSC, and expand **Particles → Rendering**
   and **Color Mapping**. Compare with the issue's approved reference: darker
   foundation, quieter controls, restrained violet, comfortable labels/numbers.
2. Hover, click and Tab through the top/menu/pin actions, particle switches,
   selectors, sliders, speed input and playback controls. Review distinct rest,
   hover, focus, active/pressed and disabled states. Open a selector and a
   View submenu; check tooltip readability and keyboard navigation.
3. Play, pause, step, seek and toggle Loop. Verify the existing scientific
   mapping controls and source colormaps still behave normally; readiness and
   warning/error communication should remain distinct from UI selection.
4. Unpin each surface, let it hide, and dwell at each 10-pixel edge. Enter and
   exit fullscreen; verify saved pins/visibility return and temporary fullscreen
   pin changes are discarded.
5. Review 1440×900, 1024×640 and your actual 4K/KDE scaling on both renderers.
   Leave playback paused after hover ends and check idle usage settles normally.
6. Approve or adjust this representative slice. Broader propagation must wait
   for that visual decision and continue on the same issue branch/PR.

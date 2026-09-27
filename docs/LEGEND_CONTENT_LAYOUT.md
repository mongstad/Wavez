# Legend content and compact layout — issue #115

Implementation and validation on 2026-09-27; **pending owner review**.
Issue #115 (UX-LEGEND-002) was the only Ready item on SimScope Development.
The existing linked branch is
`115-ux-legend-002-improve-legend-overlay-content-clarity-and-compact-layout`,
based on accepted `main` at `e26af1ee79088fcbf4a87d51f5bab221d90d2e88`
(owner-merged PR #126, issue #125). Required predecessor work was present;
stale remote references were pruned and the previous local issue branch was
already absent. No replacement branch was created.

## Presentation

Previously, cards combined unlabeled object/type, channel/colormap and range/mapping
strings. A shared presentation formatter now labels Object, Channel, Colormap and
Color range, with linear/log/cyclic next to the range. Particle Range policy uses
the panel's existing canonical wording. Numerical formatting and effective bounds
continue to come from their existing controllers.

The ramp is 14 logical pixels high, above two aligned text columns with ordinary
field/mesh content in two rows. Particle policy adds a third row. Measured cards
at 1440×900 are 76 and 96 logical pixels high respectively. Card gaps are six
pixels; the existing 12-pixel outer clearance is preserved. The content width
caps at 520 logical pixels and shrinks with available scene width. Long values
wrap at the existing font size and cards grow upward. The existing bounded layer
scroll collection remains available when all cards cannot fit.

No reader, payload, scientific mapping calculation, preparation, playback,
recipe schema, panel controls or video-export architecture changed. Visibility
still follows the existing eligible layer and Show legend state, independent of
the panel; offline export still applies its overlay inclusion gate.

## Validation

Godot 4.7.2, native NVIDIA GeForce RTX 3070 Ti; small generated current SIMSCP4
fixtures. Full logs/captures/videos remain outside Git at
`/home/Nozba/Codex/SIMSCOPE/legend-ux-115/`.

- Headless editor import: passed; new script UID included.
- Expanded layer legend suite: **63 checks PASS on Forward+ and 63 on Compatibility**.
  Covers single/multiple cards, explicit labels, field channel/colormap/range/log
  changes, particle normalization policy and cyclic wording, eligibility,
  visibility, 1024×640 and 1440×900 layout, long values, upward growth, overflow,
  panel toggles, immersive mode, preferences and preparation-state invariance.
- Actual one-frame MP4 exports with overlays on/off: **4 exports completed**
  across both renderers; output frame hashes differ as expected. Fixture source
  SHA-256 remains unchanged after each renderer suite and export pair.
- Existing native legend visibility/fullscreen suite: **989 checks PASS, 16 KWin
  geometry stages PASS** on Forward+, including restoration and independent
  legend/panel visibility. Source SHA-256 unchanged.
- Existing headless recipe-state suite: **2,697 checks PASS**.
- Visually inspected single-field and multi-layer native screenshots.

[Machine evidence](evidence/issue-115/) retains the compact reports and two
screenshots. Reproduce with `tools/validate_layer_legends.py --godot GODOT
--output-dir NEW_DIR --renderer forward_plus --export` (repeat with
`gl_compatibility`), `tools/validate_immersive_desktop.py --godot GODOT --capture
FIXTURE --output-dir NEW_DIR --legend-visibility`, and
`tools/validate_recipe_state.py --godot GODOT --output-dir NEW_DIR`.

## Limits and owner checks

The final sandboxed editor import could not access local sockets or save Godot
user settings; rerunning with normal desktop permissions passed. No test failures
remain. Native desktop startup logged a libdecor GTK plugin
warning but completed; the Python desktop harness logged a Gio deprecation
warning. Fullscreen stages were run on Forward+ only; both renderers passed the
focused legend/export suite. Production-capture performance, all display scales
and other operating systems were not rerun for this presentation-only change.
Long identifiers can add rows and large collections still require scrolling;
compactness does not imply every card always fits simultaneously.

1. Open a current capture with a scalar field. Enable Show legend; compare its
   Object, Channel, Colormap and Color range with the right panel.
2. Change channel, colormap, range and valid linear/log mapping. Confirm the card
   updates without changing the selected scientific settings itself.
3. Enable scalar-colored particles and several eligible fields/meshes. Confirm
   the particle Range policy wording matches the panel, cards remain readable,
   and overflow cards can be reached by scrolling.
4. Hide/show individual legends and layers, collapse/reopen the panel, resize the
   window and enter/exit fullscreen. Check clearance from the transport and dock.
5. Export a short clip with overlays enabled, then disabled; confirm inclusion.

The handbook and current-status page describe this change. Historical layer,
placement, visibility and previous export review-time reports are intentionally
preserved. Passing validation is not owner acceptance; stop at PR review.

## Owner-review width adjustment

Before merge, the owner requested removing about 75% of the unused right-hand
space and making the containers equal width. Content width is now 460 instead
of 520 logical pixels: a 60-pixel reduction, approximately three quarters of the
marked 80-pixel spare region. Cards include 16 pixels of padding, giving a common
476-pixel outer width. Smaller viewports still constrain that width.

The layer scroll container now accounts for its gutter only when present and
places it outside the cards on the left. Single-field cards no longer consume an
unused scrollbar allowance; both edges align with the particle card, with and
without overflow. Text remains left-to-right with the same font and columns.

The final focused suite passes **72 checks on each renderer**, including nine new
width/alignment assertions. All four overlay-on/off one-frame MP4 exports pass;
source hashes remain unchanged. Screenshots were inspected. Evidence is in
[evidence/issue-115/width-review](evidence/issue-115/width-review/); the initial
review evidence above is retained. The previously passing recipe and native
fullscreen suites were not repeated for this width-only adjustment. Owner review
of the narrower layout remains pending.

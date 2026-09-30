# Residual violet UI cleanup — #147

Issue [#147](https://github.com/mongstad/SimScope/issues/147) was the only **Ready**
item when selected on 2026-09-30. This implementation is **pending owner review**
on the existing owner-linked branch
`147-ux5-cleanup-001-clean-up-residual-ui-inconsistencies-after-violet-redesign`.
The clean branch, local main and origin/main started at `d23f431`, owner-merged
PR #145. Remote refs were pruned; the previous local branch was already absent.
No acceptance-only branch/PR was created. Candidate identity is **v0.1.0.11**,
accepted main build 10 plus one.

## Current behavior

- **Particle Filters** uses compact violet `CheckBox` membership rows. The original
  type IDs, labels/tooltips, `control_checks` keys, toggled callbacks, hidden-type
  state and serialized visual-state representation are retained.
- Immediate boolean controls retain `CheckButton` and use the accepted violet
  switch artwork. A widget-only theme binding covers static forms and dynamic
  Fields/Meshes controls; capture/recipe rebuilds bind newly created controls.
  Hover fades remain bounded at 80 ms, with no idle animation or process loop.
- The top Source/info icon, bottom capture filename and bottom Details button
  are removed. No replacement passive source/path label is added.
- **File → Details…** opens the same existing **Status details** surface, including
  readiness, retained failures, controller diagnostics, full source path, capture
  information and color-mapping explanations. Its read-only text remains
  selectable/copyable. Details remains available before a capture is loaded.
  Jobs keeps its contextual job details and failure actions.
- Closing Details returns to a valid preceding focus owner. If none remains,
  the existing Frame scene action receives focus. No menu/tab traversal redesign
  is included; the menu retains native pointer opening and keyboard row navigation.
- About uses the owner's violet PNG, copied byte-for-byte. The resource path,
  import UID, 1254×1254 resolution, lossless mipmapped import, 112×112 logical
  placement and aspect-preserving layout are unchanged. Identity, notices, links
  and startup artwork retain their existing owners. See [asset provenance](../viewer/ui/about/README.md).

## Boolean audit

| Area | Meaning and presentation |
| --- | --- |
| Particle Filters | Independent type inclusion: checkbox membership rows |
| Particle Rendering / Color Mapping / Advanced | Immediate Point rendering, Invert, Show legend and history state: switches |
| Fields and rebuilt layers | Visible, Volume ray march, Show legend and world-plane clipping state: switches |
| Meshes and rebuilt layers | Visible, Wireframe and Show legend state: switches |
| Transport | Existing Loop state: switch |
| Tools | Existing mapping, slice, guides, Bloom and analysis form boolean options: switches |
| Export forms | Existing overlay/trail/retention/sidecar options: switches |

Form switches retain their existing effect and submission boundary: changing an
option never submits a numerical job or export by itself. Disclosure headers,
menu checks/radios, pins and selection actions keep their distinct existing
interactions. The audit changes boolean widget presentation only, not callback,
validation, source selection, persistence or scientific ownership. Dropdowns and
scientific colormaps/legends are unchanged.

## Validation

Focused evidence and final counts are recorded in
[evidence/issue-147/summary.json](evidence/issue-147/summary.json).

Native Godot 4.7.2 / Linux x86_64 / NVIDIA RTX 3070 Ti results:

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| Cleanup, boolean states and rebuilds | 1,099 PASS | 1,099 PASS |
| Full shell and menu contract | 667 PASS | 667 PASS |
| Edge reveal and fullscreen restoration | 210 PASS | 210 PASS |
| Redraw pacing and offline isolation | 290 PASS | 290 PASS |
| Native Wayland fullscreen File Details / Tools / clocks | 74 PASS | 74 PASS |
| About, identity, links and notices | 98 PASS | 98 PASS |
| Status and Jobs lifecycle | 257 PASS | 257 PASS |
| Current scientific video | 235 PASS | 225 PASS |

All **5,850 native assertions** and **two Python version tests** pass. Notice
synchronization, Python compilation and whitespace checks pass. All complete
fixture hashes are unchanged. Each backend records 34 stable idle phases with
zero additional draws. Two no-UI scientific export frames per backend, their
exact timing manifest and scientific evidence match accepted main byte-for-byte
at the decoded RGB/data level. UI-inclusive exports intentionally show the
updated production shell.

The board was rechecked before push and shows **In progress**; it was the sole
Ready item before implementation. No Project status writes were performed.


```sh
python tools/validate_violet_cleanup.py --godot /absolute/path/godot \
  --output-dir /absolute/new/output --renderer forward_plus
# Repeat with --renderer gl_compatibility.
```

The focused suite uses real production controls and complete small synthetic
SIMSCP4 fixtures. It checks native File popup dispatch and Details contents,
focus restoration, membership keyboard activation, disabled membership, JSON
visual-state round trips, layer-switch callbacks, source replacement and
recipe rebuilds. About is inspected at normal/compact sizes and 200% logical
scale. Existing shell, edge/fullscreen, redraw pacing, About, status and
scientific-video suites provide separate regressions.

Source fixtures are hashed before and after validation. Scientific export pixels
and timing are compared against a source snapshot of accepted main `d23f431`;
the snapshot is a validation artifact outside Git, not an implementation branch.
Original #143/#96 review reports and historical screenshots remain unchanged.
Current documentation points to this superseding behavior without relabeling
historical pending-review evidence.

## Owner verification

1. On both renderers, open a familiar capture. Under **Particles → Particle
   Filters**, toggle each member by pointer and focused Enter. Confirm independent
   inclusion/exclusion and the existing labels/tooltips; inspect checked/unchecked,
   hover, focus and a disabled option where applicable. Check your normal saved
   scientific visual-state workflow still restores its filter exclusions.
2. Expand **Fields → Rendering / Color Mapping** and **Meshes → Rendering / Color
   Mapping**. Inspect Visible, Volume ray march, Wireframe and Show legend. Verify
   the existing effects and constraints; open another capture or restore a recipe
   and confirm the rebuilt controls use the same switches. Inspect Invert, Loop,
   Bloom and representative Tools options.
3. Confirm there is no top Source icon, bottom filename or bottom Details button.
   Open **File → Details…**, select/copy the full source path, inspect status and
   diagnostics, then close with Esc. Confirm Jobs and its contextual details work.
4. Open **Help → About SimScope** before and after loading a capture. Check the
   violet logo, v0.1.0.11 candidate identity, notices and links at 1024×640 and
   your actual 4K/KDE scale. Check that the logo is crisp and uncropped.
5. Unpin/reveal the top, right and bottom surfaces. Enter Fullscreen, reveal the
   top File menu and use Details. Exit and confirm saved pin/visibility restoration.
   Pause after interactions and allow hover fades/preparation to settle; confirm
   the accepted idle behavior. Export a familiar clip with the intended overlay
   options and confirm normal scientific appearance and sampling.

Physical 4K/KDE, mixed-monitor quality, subjective readability and familiar
production-capture acceptance remain owner checks. Automated results establish
only the declared synthetic fixtures and local Linux/NVIDIA environment. No
owner acceptance, merge, Project move or later issue work is included.

A baseline keyboard probe found that focused Space on a Particle Filter row also
starts playback after its existing rebuild. Accepted main uses CheckButton and
this candidate uses CheckBox; both produce identical membership/playback results.
Focused Enter toggles the member without starting playback on both. This existing
interaction is retained under #147's playback/focus scope boundary and recorded
as a limitation, not a passing claim that Space leaves playback unchanged.

Status/job validation retains two existing encoder-PID cleanup diagnostics per
renderer through its pre-existing allowlist; all 257 assertions pass. Native
Wayland runs retain the known libdecor GTK fallback warning. These are recorded
in the summary rather than described as clean logs. A first Compatibility
fullscreen run passed its assertions but was rejected for shader-cache warmup;
the repeat passed. The initial restricted import, test declaration/reference
errors, stale compact-size assertions and a test-only shutdown resize crash are
recorded with their corrections in the evidence summary. Final authoritative
runs exited successfully.

Standalone release packaging, real browser dispatch, production GPU power
profiling and large production captures were not rerun. The About harness clears
the native window minimum only inside its isolated regression process; product
minimum size and About layout remain unchanged. It records an actual 432×416
dialog inside a 480×480 test viewport on both renderers. The scale-2 screenshot
records actual 2560×1394, not physical 4K acceptance.

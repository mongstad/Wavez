# Portable view presets — #138

Pending owner review. #138 was the only Ready Project item. Work uses the existing
`138-recipe-regression-001-revalidate-recipe-saveload-and-simplify-recipe-ux`
branch, initially clean at accepted main `26b680065f5a05796622156fbc943c182d72759d`
(PR #137). Main and the linked remote matched; fetch/prune completed and the
previous local issue branch was already absent. Candidate: **v0.1.0.5**.

## User workflow and compatibility boundary

State → **Save view preset…** → platform file picker → filename/location → save.
State → **Load view preset…** uses the same direct picker. The picker requests the
native platform implementation, with Godot's platform fallback. There is no
intermediate Save scene form, duplicate folder input, quota, deadline or Include
results checkbox in this workflow. Completion/errors appear in the themed,
copyable View preset details surface. Cancelling the picker changes nothing.

A preset is UTF-8 JSON with `kind: simscope-view-preset`, `version: 1` and a
`settings` object. Files are bounded to 64 KiB. Save writes a uniquely named
sibling temporary file, flushes/checks it, then renames it to the selected JSON
path. The file picker handles overwrite confirmation. Write errors are reported;
failed temporary files are removed. Only `.json` destinations are accepted.

This intentionally replaces the ordinary source-bound inspection recipe contract.
Load view preset refuses inspection v2/v3 bundles explicitly; no automatic legacy
conversion, source matching or identifier remapping is added. Save/Load analysis,
inspection PNG sidecars, deterministic video and their underlying verified
scientific APIs remain separate and unchanged. The explicit `--inspection=` CLI
continues to load source-bound state; `--view-preset=` applies the new portable
format after `--capture=`. The old recipe-state test now calls
those retained APIs directly rather than the repurposed ordinary UI callbacks.

## Complete portable field list

Every group/member is optional when loading. Known supplied values are validated
before any mutation; invalid values fail atomically. Unknown optional groups or
members are skipped with a concise diagnostic. Missing target kinds are skipped.
Numeric values must be finite and within the documented implementation schema's
bounds; vectors/transforms have fixed dimensions and camera transforms must be
nonsingular. Range, logarithm, opacity and camera constraints are validated too.

| Group | Saved members |
| --- | --- |
| `view` | `point_scale`, `exposure`, `clean_view`, `brightness_scale`, `gamma`, `orbit_enabled`, `orbit_speed`, `free_camera`, `custom_orbit`, `yaw`, `pitch`, `camera_distance`, `camera_target` (xyz), `camera_transform` (basis xyz + origin), `starfield_visible` |
| `particles` | `colormap_name`, `normalization_mode`, `manual_min`, `manual_max`, `logarithmic`, `cyclic`, `invert_map`, `clamp_map`, `show_legend` |
| `environment` | `glow_enabled`, `glow_intensity`, `glow_strength`, `glow_bloom`, `fog_enabled`, `fog_density`, `tonemap_mode`, `tonemap_exposure`, `tonemap_white`, `background_mode`, `background_color` (RGBA) |
| `camera` | `fov`, `near`, `far`, `keep_aspect` |
| `quality` | `msaa_3d`, `screen_space_aa`, `use_taa`, `use_debanding`, `scaling_3d_scale` |
| `volume` | `colormap`, `lower`, `upper`, `legend`, `opacity`, `step`, `normalization`, `opacity_mode`, `opacity_lower`, `opacity_upper` |
| `mesh` | `colormap`, `lower`, `upper`, `legend`, `wireframe` |

The schema and validation bounds live in
[view_preset.gd](../viewer/scene/view_preset.gd). Volume/mesh groups capture the
**currently selected object of that kind**, and apply to the current selection in
the destination. They do not include the object's name. No arbitrary first-object
or similar-name remapping occurs. A missing kind is skipped. Current channels
remain selected: channel names, even identically spelled ones in another source,
are not treated as portable identities. Numeric color/opacity bounds are explicit
presentation choices, not claims of equivalent scientific units across captures.

Particle interval ranges become ordinary manual numeric bounds without interval
provenance. Field derived ranges likewise become manual bounds without original
sample time/channel or derivation provenance. Incompatible logarithmic mapping on
the current signed/nonpositive sample is skipped in favor of linear, with a
message. Compatibility skips unsupported TAA/debanding preferences. Explicit
legend choices still override the fresh-view hidden default.

Excluded: capture paths/UUIDs/hashes, sample time/index, playback rate/loop intent,
object/channel names, IDs/types and type filters, selection/probe/result bindings,
source geometry overrides, prepared buffers/resource budgets and analysis state.
Shell panel visibility/width, expansion, menus, dialogs, scroll, focus and window
state are never serialized or restored. Layer editors are updated in place using
no-signal setters; their cached scalar values stay synchronized, without rebuilding
forms. Successful load refreshes presentation, including its render provenance;
scientific source indices/times, selected identifiers and transport intent remain.

## Before/after investigation ledger

| Question | Accepted-main finding | New ordinary path |
| --- | --- | --- |
| Freeze stage | `Inspection.snapshot → identity → digest` blocks before JSON serialization/write | Snapshot reads a fixed presentation allowlist only |
| Whole-capture work on UI thread | Save and load each synchronously hash the committed extent | No source hash, scan, verification, preparation or result packaging |
| Scientific job work | With selections, ordinary save routes to worker-backed v3 bundles; ordinary scene save hashes directly | No analysis job or revision changes, irrespective of selections |
| SIMSCP4 identity drift | Controlled v2/v3 suite passed all 2,697 assertions; no identity incompatibility reproduced | Source identity is absent by design |
| Same-source save/load | Production eventually succeeds; small-fixture field/UI roundtrips pass | Same-source presentation roundtrips pass without time/layout restoration |
| Reopen | Retained v2 restore succeeds after reopening the same small source | Portable preset loads after reopening |
| Different source | Retained v2 reports “Scene source identity mismatch; no state applied.” | Different object/channel naming succeeds; current identifiers retained |
| Missing optional controls | Source-bound scene validation requires matching state/object inventory | Absent volume/mesh and unknown optional members are skipped |
| Failures | Long hash blocks responsiveness without progress; identity errors are explicit | Invalid/missing/oversized files and write failures are explicit, with no partial application |

The production baseline used the existing 192³ capture, **125,950,754,101 bytes**.
Save: **350,798.567 ms**; load: **339,683.132 ms**. Each recorded exactly one
identity hash of the full extent. Thus each callback prevented UI updates for
roughly 5.7–5.8 minutes. Sampled during hashing: about 329 MiB RSS and 97–98% of one
CPU core. These are sampled observations, not peak-memory measurements.
The baseline ran headless; after measurements use native renderers. The measured
hash work identifies the cause, but these are not matched GPU-performance runs.

## Validation and measurements

[Evidence ledger](evidence/issue-138/validation.json) records exact results and
field inventories. Linux x86_64, Godot 4.7.2, NVIDIA RTX 3070 Ti. Synthetic source
hashes remain unchanged. Production size/mtime remain unchanged; a second complete
118 GiB verification was intentionally not added to the lightweight tests.

Measured repeated save/load on the production capture (12 cycles, Forward+):

- Preset size: **1,964 bytes**.
- Save callback/total save time: median **0.237 ms**, maximum **0.316 ms**. The
  core save callback includes snapshot, serialization, write/flush and rename.
  The complete file-selected callback, including completion UI, took **1.985 ms**.
- Load/apply: median **85.261 ms**, maximum **87.759 ms**. This includes existing
  presentation refresh; it is not a promise of stutter-free 60 FPS application.
- Maximum observed frame gap in the test: **91.530 ms**. No multiminute stall.
- Whole-process peak RSS: **983,072,768 bytes**; CPU: **3.14 seconds**, including
  runtime startup, capture open/rendering and all test cycles. These are not
  isolated preset memory/CPU costs or directly comparable to the headless sample.
- No identity-hash calls, jobs/revision increments or progressive node accumulation.
  Legend cards are allowed their one-time creation before the stability comparison.

Final suites: portable presets **814 Forward+ / 754 Compatibility**; production
**749**; shell **682 per renderer**; retained scientific inspection **2,697**;
continuous-camera checks **13,032 headless**. All passed. Compatibility skips the
five quality-field roundtrip comparisons per cycle because unsupported controls
are deliberately skipped. Two Python version tests, canonical notice drift,
Markdown links, three executable documentation examples and Godot import passed.

Synthetic Forward+ save max **0.276 ms**, apply max **20.007 ms**; preset **2,083
bytes**. Each documented applicable field is compared on every roundtrip; representative
camera, environment, particle and layer settings are actively changed before loading.
Tests cover playing intent, same-source/reopen/different naming, absent kinds,
unsupported settings, cancellation, immediate selected-filename callback,
invalid JSON/value, atomic refusal, unwritable destination, capture-path refusal,
source invariance and shell state exclusion. No rendering precision was changed.

Development corrections: the measurement harness initially assumed optional
`psutil`; it now reads Linux `/proc` without adding a dependency. The renamed
fixture initially violated SIMSCP4's lowercase identifier rule and was corrected.
JSON parses enum numbers as floats; validation now checks integrality before enum
membership. Initial invariance assertions wrongly included deliberately changed
render-provenance color/opacity bounds and one-time legend-card creation; they now
compare scientific sampling separately and check node stability after warmup.
Malformed JSON uses the non-logging parser and an actionable error. An additional
unavailable-colormap test caught a mixed-type schema comparison; it now checks the
rule type before comparing. The stalled development test process was terminated
and the corrected suite passed.

Limits: physical clicking/typing in the platform-native dialog was not automated
(the available computer-use surface does not expose native apps). Automated tests
exercise its configuration, cancel signals and file-selected callbacks, including
on the production viewer. The exact owner desktop picker interaction remains a
manual check. No standalone packaged export, other-OS test or long-duration leak
claim. No new external runtime/assets were bundled. Historical evidence remains
unchanged; passing checks are not owner acceptance.

## Reproduction and owner review

```sh
python tools/validate_view_preset.py --godot /path/to/godot --output-dir /tmp/preset-forward
python tools/validate_view_preset.py --godot /path/to/godot --output-dir /tmp/preset-compat --renderer gl_compatibility
python tools/validate_view_preset.py --godot /path/to/godot --output-dir /tmp/preset-production --production /path/to/production.ssc
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/inspection-retained
```

1. Open the production capture, adjust viewport settings, then State → Save view
   preset. Choose an actual filename/location in the desktop picker; verify there
   is no second Save scene form or resource-limit UI and the viewer stays usable.
2. Change the view, load that file and check camera, mapping, opacity, ray step,
   legends and environment. Verify playback/time and surrounding layout remain.
3. Reopen the source and load again; then load into another compatible capture
   with different names. Current channels/objects must remain selected.
4. Cancel both pickers. Try malformed JSON and an unwritable destination; verify
   clear errors and an unchanged usable view. Test absent optional layer kinds.
5. Save/load repeatedly and check native dialog focus/overwrite behavior on your
   desktop. Save/Load analysis remains a separate source-bound workflow.

Stop for owner review; no merge, auto-merge, issue closure or board changes.


## Owner-review follow-up: channel and zoom

Field channels belong to the current capture's object/array schema. Names may
repeat across simulations, but neither their presence nor meaning is portable;
loading a preset intentionally keeps the current channel.

Scroll-wheel zoom is already saved as `settings.view.camera_distance`, together
with `camera_target`, `camera_transform`, yaw/pitch and camera FOV. The reported
zoom failure has **not been reproduced** on this branch. Added a focused regression
using wheel-input handling and actual file-selected callbacks with normal viewer
processing enabled. It checks exported distance, restored camera transform and
projection after several live frames, same-source and reopen loading, and the
first wheel movement after loading. The Save picker is opened with live processing
and checked for zoom preservation; reopening uses the same deferred file-picker
callback in the same viewer instance. No runtime change or claimed zoom fix was
made without reproducing the defect.

Results: **826 Forward+**, **766 Compatibility**, **761 production** checks passed.
The first development run used an unavailable `Projection.is_equal_approx`
method; corrected to exact projection equality and all final runs passed.
The additional 12 checks are recorded in
[zoom review evidence](evidence/issue-138/zoom-review.json); earlier timing evidence
is preserved. Physical native dialog interaction remains outside automation.
The owner confirmed open → zoom → save → reopen → load and supplied `viridis.json`.
Loading that exact file against the owner's 192³ capture succeeds: saved distance
154.38348541259765 matches both the default opening distance and the restored
distance, including after two seconds of live auto-orbit (actual float32 transform
distance 154.383483886719). Thus that file contains default zoom. Why the intended
adjusted zoom was absent remains unresolved; a newly saved file after conspicuous
zoom and observation of the Save dialog interaction have been requested.

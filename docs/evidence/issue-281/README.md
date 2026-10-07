# Volume legend opacity — issue #281

Candidate **v0.1.0.72**, pending owner review. #281 was the first and only Ready
item at selection. Its exact GitHub-linked branch
`281-ux-legend-show-volume-opacity-state-in-the-legend-overlay`
was checked out, clean and based on accepted main `3f966be` (owner-merged
PR #292). GitHub linked-branch metadata, fetch/prune and branch/main ancestry
matched. The completed #288 branch was already absent. Main was rechecked before
publication and remained unchanged. No branch was created/switched and no Project
transition was performed.

## Change

Visible volume legends gain a compact third row reporting the already applied
material uniforms: opacity strength, linear/magnitude ramp and threshold bounds.
Example: `Opacity: strength 0.18 • magnitude [0.1 → 2.0]`. Strength alone would
not describe the existing independent ramp. The strength is maximum display
extinction per world unit, rather than uniform pixel alpha.

Slice-only legends say `Opacity: opaque slice`; combined volume/slice legends
append that qualifier. Existing object/channel, colormap bar, color range,
particle/mesh content, legend defaults, visibility and export gate retain their
contracts. No renderer, shader, scientific payload, opacity control or persistence
code changed. The version increments once from accepted main 71 to 72.

Current docs: [volume legend guide](../../VOLUME_LEGEND_OPACITY.md),
WAVEZ_HANDBOOK.md, CURRENT_STATUS.md, README.md, VIDEO_EXPORT.md and
EVIDENCE_INDEX.md. Earlier
legend evidence, including original two-row volume descriptions and pending
review wording, remains unchanged as historical records.

## Focused validation

[Summary](summary.json), [Forward+](forward.json),
[Compatibility](compatibility.json), native logs
([Forward+](forward-native.txt), [Compatibility](compatibility-native.txt))
and [video probes](video-probe.json).

| Gate | Result |
|---|---|
| Forward+ native legend checks | 106 PASS, zero failures |
| Compatibility native legend checks | 106 PASS, zero failures |
| Actual offline video exports | Four completed, overlay on/off per renderer |
| Decoded/probed MP4s | H.264, 1440×900, one frame each; opacity visible with overlays on, all legends absent with overlays off |
| Source capture SHA-256 per run | Unchanged before/after tests and exports |
| Application version tests | 2 PASS |
| Python compile / final unrestricted Godot import / whitespace | PASS |

The existing legend harness now exercises actual opacity-strength controls at
0, 0.18 and 2.5, both ramp modes and thresholds, immediate renderer/legend
matching, independent channel/colormap/color bounds, hide/show and slice-only /
combined views. A deliberately changed material uniform (0.37 while state is
0.18) proves reporting reads the applied renderer value; resample restores both.
Actual particle-only and mesh-only fixtures retain their existing legends with
no opacity row. Existing default visibility, eligibility, recipe preferences,
long-label wrapping, bounded scrolling, panel visibility and immersive checks
remain in the focused suite.

Volume cards measure 476×98 px; the particle card remains 476×96 px. Opacity text
is readable at 1440×900 and 1024×640. The bounded stack still clips cards beyond
its viewport and scrolls to reach them; the new row does not remove that existing
limit. Offline export runs use the real worker and external FFmpeg. Only reports,
logs and review images are retained; generated WVZ captures and MP4s are external.

Reproduce with a fresh output directory and isolated XDG data/config directories:

```sh
python tools/validate_layer_legends.py --godot /absolute/path/to/godot --output-dir /tmp/legend-forward --renderer forward_plus --export
python tools/validate_layer_legends.py --godot /absolute/path/to/godot --output-dir /tmp/legend-compatibility --renderer gl_compatibility --export
python -m unittest tests.test_application_version -v
python -m py_compile tools/validate_layer_legends.py
```

Native checks used external Godot 4.7.2 on Linux with NVIDIA RTX 3070 Ti, and
external FFmpeg. This reporting-only change calls for the affected legend suite
and the directly connected screenshot/video overlay boundary. Unrelated full
scientific, cache, playback and camera suites were not run.

## Failures and limitations

The [initial Forward+ report](initial-forward.json) records 97 checks with three
failed text assertions: the test expected threshold `2`, but Godot formats it
as `2.0`. The assertions were corrected, applied-uniform checks were added and
both final renderer runs passed. This was not a renderer failure.

[Initial import](import-initial.txt) recreated five known untracked cache UIDs.
A [sandboxed warm retry](import-sandboxed.txt) could not create local editor
sockets. The [unchanged unrestricted import](import-final.txt) completed without
errors or warnings. Incidental UID files were removed after import completed.

Linux release packaging, physical-display/mixed-DPI/4K checks and long captures
were not run. Export evidence is a one-frame worker integration check; long-video
behavior and dense-stack framing still need owner judgement.

## Screenshots and owner verification

- [Desktop](desktop.png), [compact](compact.png), [compact scrolled](compact-scrolled.png) and [single volume](single-volume.png).
- Decoded overlay-on MP4: [Forward+](forward-video-overlay.png), [Compatibility](compatibility-video-overlay.png).
- [Decoded Forward+ overlay-off MP4](forward-video-no-overlays.png).

1. Open a scalar-volume WVZ and enable **Show legend** under Color Mapping.
2. Change **Opacity strength** to 0, 0.18 and a larger value; confirm immediate matching text. Change the ramp between linear/magnitude and edit both thresholds.
3. Change colormap and color range; confirm those values update while the opacity row remains correct. Hide/show the legend and repeat.
4. Check desktop and compact sizes, scroll multiple legends, and compare slice-only and combined volume/slice wording.
5. Save a screenshot, then export a short video with **Overlays** on and off. Confirm enabled opacity text is included on and all legend cards are excluded off.
6. Open particle-only and mesh-only scenes and confirm their legends retain their prior content.

Stop for owner review. These results are implementation evidence, not owner
acceptance; no merge, auto-merge or manual issue closure is arranged.

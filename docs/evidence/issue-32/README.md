# Issue #32 — Source-probe marker visibility

Candidate `v0.1.0.74`, pending owner review. Issue #32 was the first and only
Ready item. The owner-created linked branch was already checked out, clean and
based on accepted main `929925c0d30d7415fe37eea9f5170e56fbea083b` (PR #294).
The UI-004 independent visibility predecessor (PR #31 / issue #4) is present in
main. No branch replacement or Project transition was performed.

## Final presentation

The last explicit source probe owns a three-axis cross with an orchid `#ef8fff`
core and navy `#182033` outline. The original center and ±0.35-world-unit arms
remain. Nominal strokes are 3/7 canvas pixels, with antialiasing. A small
world-anchored Node3D projects those endpoints into a canvas beneath application
UI, after 3D post-processing. This keeps bloom and dense scientific content from
burying or bleaching the marker. It adds no input/focus handling, Node process
loop, scientific material changes, depth writes, shadows or source resampling.

Projection updates on an existing render only when the cached camera/projection,
viewport or owner transform changes. Canvas commands are updated before that
render without queueing another frame. Near-plane crossings are clipped before
projection; behind-camera points have no phantom annotation. Source/session,
visibility, recipe/PNG and deterministic-video contracts remain unchanged.
See [current marker guide](../../PROBE_MARKER_VISIBILITY.md).

## Treatment choice and native images

Former white lines and orchid/cyan/gold outlined treatments were compared over
eleven native scenes: black/empty space, 80 sparse particles, 20,000 dense white
particles, dark/bright viridis, plasma, blue/white/red coolwarm, structured turbo
with dense particles, and the default Cinematic preset with bloom/fog.
The legacy image reconstructs the former white line geometry in the focused
test; it is not a separate full accepted-main run.

Orchid retains separation from black and the tested bright/dark fields. The
outline supplies contrasting edges over bright content. Gold approaches the UI
warning color and warm data; cyan competes more with blue/cyan scientific
structures. Color is fixed annotation ink, independent of LUTs or status tokens;
it carries no magnitude/sign/category meaning. Pixel comparisons are visibility
evidence, not calibrated color or universal colormap proof.

- [Empty](empty-orchid.png) and [sparse particles](sparse-orchid.png).
- Dense white particles: [former treatment](dense-white-legacy.png), [final treatment](dense-white-orchid.png).
- [Dark viridis](viridis-dark-orchid.png), [bright viridis](viridis-bright-orchid.png), [plasma](plasma-mid-orchid.png), [white coolwarm](coolwarm-white-orchid.png).
- [Structured turbo with dense particles](turbo-structure-orchid.png).
- [Cinematic Forward+](cinematic-dense-orchid.png) and [Cinematic Compatibility](compatibility-cinematic-dense-orchid.png).
- [Compact 640 × 480 / far zoom](compact-orchid.png) and [Compatibility blue coolwarm](compatibility-coolwarm-blue-orchid.png).

Images were visually inspected at their native sizes. No tooltips/dialogs obscure
the target. These images show the scientific viewport; shell layout is unchanged.

## Final validation

Linux desktop, external Godot 4.7.2 (`ed1daf0bf`), NVIDIA RTX 3070 Ti; Forward+
Vulkan and Compatibility OpenGL. No physical input-device helper was used.

| Check | Forward+ | Compatibility | Retained results |
| --- | --- | --- | --- |
| Native visibility/projection/state matrix | 110 checks, 0 failures | 110 checks, 0 failures | [Forward+](forward/visibility-report.json), [Compatibility](compatibility/visibility-report.json) |
| Treatment pixel comparison | 11 scene cases passed | 11 scene cases passed | Same reports; all three outlined colors evaluated |
| Far/compact stroke | 8 raster pixels including AA | 8 raster pixels including AA | Same reports; nominal total width remains 7 |
| Existing probe contracts | 33 checks, 0 failures | 33 checks, 0 failures | [Forward+](contracts-forward/probe-report.json), [Compatibility](contracts-compatibility/probe-report.json) |
| Deterministic video | Two four-frame MP4s passed | Two four-frame MP4s passed | Same reports, worker logs and shown/hidden timing manifests |
| Application identity | 2 tests passed | Shared source | [Version log](version.txt) |
| Godot import | Final import clean, exit 0 | Shared source | [Final import](import-final.txt) |

All four final GUI test runs exit 0 with clean native logs. The final cross changes
889–909 pixels of a 960 × 640 viewport in the tested main cases (less than 0.15%
of the viewport). Pixels outside its local bounding region are unchanged;
hiding exactly restores the marker-free image in every scene. On dense white
particles the reconstructed old cross changes zero distinguishable pixels.
The final marker changes 909, including 885/886 strong-contrast pixels in
Compatibility/Forward+. RGB delta thresholds are stated in the Python runner.

Native checks preserve source-array values, independent source probe oracle,
probe coordinates/stamp, committed sample and serialized render settings across
presentation changes. The production View-menu action shows/hides the marker
and reflects its checked state. Camera motion changes only its projection;
world coordinates and the source probe stay fixed. Stationary projection,
near-plane and behind-camera handling are covered.

The existing contract suite covers no marker before a probe, repeated toggles,
recipe rebuilds, seek/playback, hidden re-probing, invalid-probe recovery and
capture reopening. Actual PNGs/sidecars honor visibility; shown/hidden serialized
render states are equal. Four actual 640 × 480 MP4 exports (4 fps, four frames,
one second each) exclude the session marker. Within each renderer, corresponding
retained frames are byte-identical, timing manifests match, first-frame central
pixels match the pre-probe baseline, and ffprobe confirms encoded properties.
Generated capture SHA256 values remain unchanged throughout both suites.

`py_compile` for the new runner and `git diff --check` passed. This is focused
validation for the new marker presentation/projection and its immediate
source/visibility/PNG/video boundaries. Unrelated full-suite regressions were
not run.

## Failed and limited development evidence

The first spatial-material approach passed 94 native checks and ten Scientific
scene comparisons per renderer ([initial Forward+](initial-forward-report.json),
[initial Compatibility](initial-compatibility-report.json)). Its extra zoom
images were accidentally taken while hidden; they were not valid zoom evidence.
That setup was corrected and pixel assertions added.

Adding Cinematic exposed a real presentation failure: the spatial outline was
bleached by bloom. Native checks passed, but the pixel runner failed
`cinematic-dense marker has insufficient contrast`: orchid had only 85 pixels
above the strong-contrast threshold (required more than 100). See the
[failure measurements](spatial-cinematic-failure.json),
[native-only report](spatial-cinematic-visibility-report.json), and
[failed image](spatial-cinematic-dense-orchid.png).
This attempt is **not final passing evidence**. The spatial shader/material was
removed; the final post-processing-independent canvas treatment passes the
same Cinematic case with 884/882 strong-contrast pixels in Forward+/Compatibility.

The first import recreated five unrelated missing UID sidecars from the existing
cache ([initial log](import.txt)). Warm and final imports are clean. Those
unrelated generated files are excluded; new marker/test script UIDs are included.
The historical UI-004 report and all prior issue evidence remain unchanged.

## Reproduction and owner verification

Use fresh output directories and externally installed Godot/FFmpeg/ffprobe:

```sh
env -u WAYLAND_DISPLAY python tools/validate_probe_visibility.py --godot /path/to/godot --output-dir /tmp/probe-visibility-forward --renderer forward_plus
env -u WAYLAND_DISPLAY python tools/validate_probe_visibility.py --godot /path/to/godot --output-dir /tmp/probe-visibility-compatibility --renderer gl_compatibility
env -u WAYLAND_DISPLAY python tools/validate_probe_marker.py --godot /path/to/godot --output-dir /tmp/probe-contracts-forward --renderer forward_plus
env -u WAYLAND_DISPLAY python tools/validate_probe_marker.py --godot /path/to/godot --output-dir /tmp/probe-contracts-compatibility --renderer gl_compatibility
python -m unittest tests.test_application_version -v
```

Captures, runtime binaries, profiles, caches and MP4s remain outside Git. Release
packages, physical keyboard/mouse interaction, mixed-DPI/4K, prolonged sessions,
million-particle/external research captures and selection/comparison-specific
video paths were not tested. World arm length keeps its existing scale behavior;
extreme zoom or very large scene scales can shorten the arms. No cross-renderer
pixel equivalence or universal background/color-vision guarantee is claimed.

1. Open a representative capture with a volume and dense particles. Use
   **Tools → Source probe** at an in-domain point. Check the orchid/navy cross
   on empty space and bright/dark viridis, plasma/coolwarm and structured fields,
   under Scientific and Cinematic presets.
2. Orbit/zoom and resize to normal/compact windows. Confirm the world anchor
   follows the same sampled location, the stroke stays legible and the marker
   does not cover an excessive local area or draw over application controls.
3. Toggle **View → Probe marker** repeatedly. Coordinates/result must persist.
   Hide, seek/play, load a recipe and probe again; the preference must persist.
   Out-of-domain probing must show Unavailable with no stale cross; a valid
   probe recovers. Reopening starts a fresh session.
4. Save screenshots shown/hidden; verify inclusion follows the switch. Export
   a short video with the marker shown; it must remain absent from the video.

Stop for owner review; no merge, auto-merge, manual issue closure or Project
completion has been performed.

# Particle size

Simulation → Particles → Rendering → **Particle size** controls the presentation
multiplier for particle markers. Its range is **0.01–8**; the startup default
remains **1.8**. Source positions, IDs, channels, radii/units and timestamps are
unchanged. Size-channel mapping still supplies the underlying marker size.
Brightness, exposure, color, additive blending and the particle shader are unchanged.

The current value appears beside the slider, using the shortest decimal that
round-trips to the selected float64 value. Dragging updates it continuously.
The bounds remain visible below the track. Travel is logarithmic: the midpoint
is approximately 0.283, rather than 4.005. Equal distances multiply the value
by equal factors, giving substantially more travel to small values. This uses
Godot's [exponential Range](https://docs.godotengine.org/en/4.7/classes/class_range.html#class-range-property-exp-edit)
with no discrete value step.

Double-click the **thumb** to open a compact numeric editor. Double-clicking the
track retains ordinary slider behavior. A first click on the thumb preserves the
exact selected value; dragging moves relative to that starting position.

- Enter applies a finite value within 0.01–8 and closes the editor. Decimal and
  scientific notation are accepted, for example `0.025` or `2.5e-2`.
- Invalid, non-finite or out-of-range drafts remain visible with an error;
  the selected value does not change. Values are rejected rather than clamped.
- Esc or an outside click dismisses the draft. Focus returns to the slider.
- With the slider focused, Enter opens the editor. Left/Right move by 1% of
  logarithmic travel; Shift+Left/Right use 0.1%. Home/End choose the bounds.
  The mouse wheel moves by 1% of travel per event.

Manual entry is not rounded to the old approximately 0.079-unit step. Float64
entry precision describes the presentation setting; GPU uniforms and rendered
pixels retain the engine's existing precision. A changed view/preset dismisses
a stale draft and synchronizes the slider and readout. Portable view presets and
native visual snapshots retain small values, including exact decimals below 0.1.
Scientific/Cinematic presets retain the chosen size. This does not implement the
separate default-view/persistence proposal in #366.

## Visibility limits

The minimum is a permitted presentation value, not a guarantee that every marker
remains visible. Projected size depends on size mapping, camera distance,
projection, resolution, antialiasing and subpixel alignment. Smaller markers can
disappear or flicker. Reducing marker size also reduces overlap in additive
rendering, but does not change or correct the additive brightness mechanism.

Issue #367 compared a deterministic 100,000-particle synthetic capture at sizes
0.01, 0.025, 0.05, 0.1 and the unchanged default 1.8. Camera and appearance were
fixed: camera `(0,0,6)`, vertical FOV 55°, Scientific point rendering, fixed white
color, brightness/exposure/gamma 1, black background, linear tonemapping, no
Bloom/fog, no MSAA/screen-space AA/TAA/debanding. The same production particle
material and 0.36-unit quad were used, with fixed base size 0.35. True Vulkan
render targets were **1920×1080** and **3840×2160**; no image upscaling was used.

| Size | Lit pixels, 1080p | Saturated pixels, 1080p | Lit pixels, 4K | Saturated pixels, 4K |
| --- | ---: | ---: | ---: | ---: |
| 0.01 | 2,364 | 0 | 9,178 | 7 |
| 0.025 | 14,066 | 20 | 56,435 | 86 |
| 0.05 | 48,442 | 293 | 193,989 | 1,136 |
| 0.1 | 116,715 | 4,116 | 466,726 | 16,217 |
| 1.8 | 197,485 | 173,876 | 789,986 | 695,533 |

Here “lit” means any nonzero RGB byte; “saturated” means any RGB byte equals 255.
These are image statistics, not particle counts or physical intensity estimates.
Smaller values substantially reduce overlap/saturation, while many small markers
miss the sample grid entirely. These images cannot be interpreted as an unbiased
scientific density measurement.

A separate stationary, centered marker was measured while shifting the camera
diagonally by 0, 0.25, 0.5, 0.75 and 1 pixel, without changing its source position:

| Size | Projected quad width, 1080p / 4K | Lit pixels across offsets, 1080p / 4K |
| --- | --- | --- |
| 0.01 | 0.218 / 0.436 px | 0–1 / 0–1 |
| 0.025 | 0.545 / 1.089 px | 0–1 / 0–1 |
| 0.05 | 1.089 / 2.178 px | 0–1 / 1–4 |
| 0.1 | 2.178 / 4.357 px | 1–4 / 8–12 |

At 0.01, the marker disappears at four offsets and becomes one saturated pixel
at the aligned offset in both resolutions. In this view, 0.1 at 1080p and 0.05 at
4K are the first tested values that remain nonblack across all five offsets;
peak brightness still varies from 9 to 255. Choose a larger value when stable
individual-marker visibility matters. There is no universal lower visibility
bound, and no shader/runtime clamp was introduced above the requested 0.01.

## Validation and review record

Candidate **v0.1.0.98**, pending owner review, based on owner-merged PR #373 at
`c3475573878e7535174b1229b24d35eb6ae82e79` / accepted v0.1.0.97. #367 was the
only Ready item; implementation uses its existing linked branch
`367-ux-particles-fine-grained-particle-size-with-numeric-readout-and-direct-entry`.
Previous merge/reference housekeeping completed before implementation.

Source/native Forward+ Vulkan: **245 focused checks passed**, **815 existing
preset checks passed**, **288 existing Simulation panel checks passed**. These
cover real Control/Window event dispatch, first-click/double-click preservation,
precise decimal/scientific entry, invalid drafts, cancellation/dismissal, Tab and
slider keyboard input, one-pixel low-end dragging, held-W camera blocking,
Dark/Light error states, resize/readout layout, portable presets/native visual
state, Scientific/Cinematic behavior and presentation/scientific-state isolation.
All generated WVZ fixture SHA-256 hashes remained unchanged.

Standalone Linux: the normal v0.1.0.98 package built successfully. A temporary
release-template validation entry completed **245 behavioral checks**, unchanged
fixture hashes and clean process exit. All ten dense images were byte-identical
to the source/native images. Its strict log gate **fails** on **62 native Popup
signal cleanup diagnostics** (32 nonexistent disconnects and 30 duplicate
connects; no other errors or warnings). This is the previously documented
[#335 Godot release-template defect](ROOT_WINDOW_SIGNALS.md), retained and reported
without suppression. Passing assertions do not make this a clean package log.
The isolated PopupPanel/PopupMenu release probe reproduces the same diagnostic
classes with **18 behavioral checks passed and 32 errors**, without Wavez's new
control. The normal package also opened the tiny mixed capture and the small
preset, then exited after 30 frames with a clean Vulkan startup log.

Native UI pixels were 970×640, 1920×1080 and 2560×1394 on this desktop. The window
manager clamps the requested 960×640 and 3840×2160 window sizes; only the separate
render targets certify true 4K rendering. Actual physical mouse/keyboard feel,
mixed-DPI displays, physical 4K UI, other GPUs, Windows/macOS and long sessions
remain owner checks. No unrelated full application or scientific solver suites
were run. Compatibility is retired and was not tested or restored.

Environment: Linux, Godot 4.7.2 `ed1daf0bf`, NVIDIA RTX 3070 Ti / driver
615.71.09, Forward+ Vulkan 1.4.351. Large fixtures, original screenshots, logs and
packages stay outside Git under
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-367-particle-size/`.
`native-final-03/` contains the final source report, exact-size dense images,
subpixel measurements and unobstructed UI/error screenshots. `preset-native/`
and `panel-native/` contain the immediate-boundary reports. Earlier attempts are
retained; the compact readout wrapping defect and a diagnostic-script type error
were corrected before the final run. An initial normal-release `--script` attempt
is inconclusive because release templates lack that editor entry point.
`package-final/` contains the normal standalone package and build manifest;
`packaged-review/` contains the validation-entry executable, report, images and
complete unsuppressed diagnostics. `popup-release-control/` contains an isolated
engine Popup probe used to classify those diagnostics.

Reproduce with externally installed Godot and Python/NumPy:

```sh
python tools/validate_particle_size.py --godot /path/to/godot --output-dir /tmp/particle-size-source --dense
python tools/validate_view_preset.py --godot /path/to/godot --output-dir /tmp/particle-size-preset
python tools/validate_simulation_panel.py --godot /path/to/godot --output-dir /tmp/particle-size-panel
python tools/validate_particle_size.py --godot /path/to/godot --export --output-dir /tmp/particle-size-release --dense
```

The export check stages the same production resources and replaces only the
temporary launch entry with the validation harness. It adds no product test hook.
The normal standalone package is produced independently by
`tools/package_linux.py`.

## Owner verification

1. Open a particle capture in Forward+ Vulkan. Expand Particles → Rendering.
   Confirm 0.01/8 bounds, current numeric value and unchanged fresh-session 1.8
   default. Compare Dark and Light at compact and larger window sizes.
2. Drag near 0.01, use arrows/Shift-arrows and Home/End, then double-click the
   thumb. Enter `0.0251234567890123`; confirm the exact readout. Double-click the
   track and confirm that it does not open entry or move the camera.
3. Try `NaN`, `inf`, `abc`, `0.009` and `8.01`. Confirm visible errors and unchanged
   applied value. Type a valid draft then press Esc or click outside; confirm
   cancellation and usable slider focus. Check typing/held navigation keys does
   not move the camera.
4. Save/reload a view preset below 0.1 and compare native visual-state restoration.
   Switch Scientific/Cinematic and reopen/replace the capture; confirm that size
   stays synchronized without changing source values, IDs, timing or channels.
5. Compare 0.01, 0.025, 0.05, 0.1 and 1.8 on a dense capture with fixed camera,
   brightness, exposure, color and Bloom settings. Inspect slow camera motion for
   disappearing/flickering subpixel markers. Choose a useful size for that view;
   do not treat the smallest allowed size as guaranteed scientific visibility.
6. Review the single linked PR, reconcile BUILD against current accepted main if
   another PR merged first, then accept/merge only through the owner workflow.

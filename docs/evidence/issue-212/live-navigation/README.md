# Live navigation investigation — owner report remains unresolved

On 2026-10-09, after commit `1c80ddc`, the owner again reported that the gizmo
appeared to move during WASD/QE navigation while its World XYZ stayed fixed.
This follow-up did **not reproduce world drift or annotation-camera lag**. It
adds diagnostic coverage, not a correction or owner acceptance. The owner's
specific camera pose and complete interaction sequence remain unknown; the
reported issue is **UNRESOLVED**. Earlier evidence remains a historical record.

## Retained measurements

| Forward+ probe | Rendered frames | Current-camera mask mismatches | Largest previous-frame mask mismatch | Main/annotation projection error |
| --- | ---: | ---: | ---: | ---: |
| Stationary asymmetric synthetic volume | 28 | 0 | 341 samples | 0 px |
| Frozen owner sample 62, source time 30.5, radius 50 | 27 | 0 | 1,056 samples | 0 px |

[Summary](summary.json) derives these values from the complete compact
[synthetic trace](synthetic-forward.json) and
[frozen-owner trace](owner-frozen-forward.json). JSON formatting was compacted;
all original measured values are preserved. The summary records SHA-256 values
of the original reports before formatting. No capture arrays, owner screenshots
or video are included here.

In both runs, the complete main and annotation camera transforms matched on
every captured frame. The actual sphere origin matched the draft center;
draft XYZ and radius remained unchanged. The real Place ahead pointer click
emitted its signal once. Committed field channels, `world_to_grid`, and the
volume shader's matching transform remained byte-identical. This runtime
fingerprint covers field data, not particle arrays.

The owner diagnostic input was a stationary copy of **all** recorded particle
and field arrays from sample 62 at source time 30.5; creation-time byte equality
is recorded in [copy provenance](owner-copy-provenance.json), using the retained
[local copy probe](owner-freeze-probe.txt). Its original research
capture was unchanged. This run used an identity camera basis, a 120-world-unit
view/placement distance, draft center `(-0.25, -0.25, -0.25)`, and radius 50.
Those camera settings are controlled probe settings, **not a reconstruction of
the owner's unknown view**.

## Method and limits

The exact [diagnostic driver](live_motion_probe.gd) activates the real viewer
`_process`, then holds and releases A/D/W/S/Q/E with `Input.parse_input_event`.
It samples `RenderingServer.frame_post_draw`. After the initial Place ahead,
it makes no manual movement call, camera update, editor refresh, or forced draw.
It records full camera/sphere transforms, draft state, target/distance, two
source-grid landmark positions and projections, input phases, and timestamps.

Each rendered annotation image is sampled on an 8-pixel grid. Actual alpha is
compared with independent ray/sphere intersections using the current camera and
up to three previously rendered camera poses. Samples within a 2.5% squared-radius
discriminant band around the rasterized rim are excluded. The current pose has
zero mismatches; earlier poses produce substantial mismatches during motion,
showing that this probe can distinguish stale rendering. Source landmarks use
the committed field's inverse `world_to_grid`; no new reference object is placed
at the selected gizmo location.

The earlier world-placement harness called `_move_free_camera` directly,
refreshed the guide before measuring, and waited for screenshots. That established
settled-state geometry but left continuous-motion timing untested. This probe
fills that gap without establishing the cause of the owner's remaining report.

GPU image readback and per-frame PNG capture slow this diagnostic. The saved
microsecond timestamps describe the instrumented run, not ordinary interactive
frame rate. Paused render pacing may produce no additional idle frames; the probe
does not force them. A release-labelled frame may have integrated motion earlier
in that same process frame; phase-change events preserve the corresponding camera
pose and timing. This is a Forward+ development run, with synthetic input, a
controlled camera pose and no physical-input, Compatibility, or package claim.
The mask comparison measures the annotation render target; this driver records
main-view images locally but does not independently segment the scientific volume
or the composed main-view sphere from those images.

## Independent scientific-pixel probe

The separate [exact driver](volume_pixels_probe.gd) measures actual scientific
pixels in the main viewport, closing the projection-label limitation above.
Its [Forward+ report](volume-pixels-forward.json) contains 49 records: an initial
still and eight rendered frames each while holding A/D/Q/E/W/S through the real
viewer process loop. During movement it uses `frame_post_draw` without manual
camera updates, editor refreshes or forced draws. Only initial setup forces a
still draw, because paused render pacing need not produce another idle frame.

A stationary 65³ Gaussian volume spans `[-48,48]³`, with spacing 1.5 and its
source-defined center at `(12,-9,6)`. The actual main-image brightness centroid
stays within **0.071 pixels** of that source center's camera projection. The
actual annotation alpha centroid stays within **0.156 pixels** of its projection;
main/annotation camera position error is zero throughout. The driver samples
every second image pixel, excludes weights below 0.03, and uses pixel centers.

This isolates rendering: it sets the draft directly, hides UI canvas layers,
uses a white volume transfer over black, disables fog/glow, and uses radius 3,
view distance 130 and Free Camera speed scale 0.08. It does not test Place ahead
input, the composed main-view sphere, the owner's signed `real` field, or an
irregular volume's apparent features. GPU readback affects timing. No fixture
arrays or screenshots from this probe are retained in the repository.

The small [fixture generator](make_volume_pixels_fixture.py) recreates both
stationary samples. From the repository root, with imports prepared and
`GODOT` pointing to the external executable:

```bash
if [ ! -f /tmp/issue212-volume-live/gaussian.wvz ]; then
  python docs/evidence/issue-212/live-navigation/make_volume_pixels_fixture.py \
    /tmp/issue212-volume-live/gaussian.wvz
fi
mkdir -p /tmp/issue212-volume-live-repeat
XDG_CONFIG_HOME=/tmp/issue212-volume-live-repeat/config \
XDG_DATA_HOME=/tmp/issue212-volume-live-repeat/userdata \
"$GODOT" --path viewer \
  --script "$PWD/docs/evidence/issue-212/live-navigation/volume_pixels_probe.gd" \
  --rendering-method forward_plus --display-driver wayland \
  --resolution 1440x900 --audio-driver Dummy -- \
  --out=/tmp/issue212-volume-live-repeat
```

The exact driver retains the fixed local fixture path shown above. Its original
output was `/tmp/issue212-volume-live/forward`; the report here is byte-identical.
This is a Forward+ development measurement, not physical-input acceptance.

## Reproduce from the repository root

Use an externally installed Godot executable with the viewer's imports already
prepared. The driver extends the existing viewer test helpers through `res://`.
Commands below generate local captures and images under `/tmp`; do not add these
outputs to the repository.

```bash
python - <<'PY'
from pathlib import Path
from tools.validate_orbit_center_world import fixtures
out = Path('/tmp/wavez-212-live-synthetic-input')
out.mkdir(exist_ok=False)
fixtures(out)
PY
mkdir -p /tmp/wavez-212-live-synthetic-repeat
XDG_CONFIG_HOME=/tmp/wavez-212-live-synthetic-repeat/config \
XDG_DATA_HOME=/tmp/wavez-212-live-synthetic-repeat/userdata \
"$GODOT" --path viewer \
  --script "$PWD/docs/evidence/issue-212/live-navigation/live_motion_probe.gd" \
  --rendering-method forward_plus --resolution 1440x900 --audio-driver Dummy -- \
  --capture=/tmp/wavez-212-live-synthetic-input/world-field.wvz \
  --live-output=/tmp/wavez-212-live-synthetic-repeat
```

The retained driver is the exact diagnostic used, including its historical
fallback input path. Pass `--capture` explicitly as above. Its owner-input branch
selects central grid landmarks when the input filename contains `frozen-t30.5`.
To repeat the owner case, the external, byte-verified frozen copy must be available;
the retained copy probe requires access to the original owner capture and uses
its historical local paths. The reports contain hashes, not scientific arrays.
Preserve the diagnostic copy basename and use
`--live-radius=50`:

```bash
mkdir -p /tmp/wavez-212-live-owner-repeat
XDG_CONFIG_HOME=/tmp/wavez-212-live-owner-repeat/config \
XDG_DATA_HOME=/tmp/wavez-212-live-owner-repeat/userdata \
"$GODOT" --path viewer \
  --script "$PWD/docs/evidence/issue-212/live-navigation/live_motion_probe.gd" \
  --rendering-method forward_plus --resolution 1440x900 --audio-driver Dummy -- \
  --capture=/tmp/wavez-212-live-owner/frozen-t30.5.wvz --live-radius=50 \
  --live-output=/tmp/wavez-212-live-owner-repeat
```

Original local outputs were `/tmp/wavez-212-live-motion-forward` and
`/tmp/wavez-212-live-owner-motion-forward`. They contained per-frame main-view PNGs,
selected annotation PNGs, full reports and timestamp-based video manifests. These
`/tmp` inputs/outputs are disposable local dependencies, not retained artifacts.

## Capturing the missing owner pose

The follow-up production change adds one `ORBIT` JSON event to the existing
session log when opening the editor and after a successful Place ahead. It does
not change placement, navigation, rendering, source data or the UI. The event
preserves full-precision camera position/basis/projection, target/navigation
state, draft center/radius/depth, previous center, capture/sample, committed
time, selected field presentation/sample and renderer. A second Place ahead
after navigating captures the previous anchor along with the new camera ray.
No per-frame telemetry or scientific arrays are logged. Existing verbose/minimal/
disabled policies, size caps and flushing remain authoritative.

[Validation](placement-log-validation.json) records 2,125 passing headless checks
and 2,213 passing native Forward+ checks for the final addition including field
state and committed time. The native run
emitted 18 open and 26 placement events; every event parsed as JSON. All 26 placed
centers reconstruct exactly from the logged float32 camera ray and depth. The
longest JSON event was below the existing 8,192-character line cap; see the
[representative field event](placement-log-example.json). The first sandboxed
import was blocked from opening Godot's local socket; an authorized run completed
cleanly. Incidental cached UID warmup files were removed, not committed.

The prior revision's Compatibility and packaged checks remain historical; those
configurations were not repeated for this logging-only change. The new native
checks are regression evidence for diagnostics, **not proof that the remaining
owner report is fixed**. Retain the next failing session's log to reconstruct its
actual placement before another behavioral correction.

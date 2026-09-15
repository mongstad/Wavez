> Historical checkpoint report; original scope, paths and measurements below
> describe that run. See [current status](docs/CURRENT_STATUS.md) and
> [retained evidence](docs/EVIDENCE_INDEX.md) for the accepted G0–G4 implementation.

# G3 maintenance: live Physical-time slider

Fixed the native SIMSCP3 slider becoming visually pegged at 100% after a layered
capture grows. G4 was not started. All work is in `SimScope`; solver code,
original captures, sampling policies and the original `SimScope` project are unchanged.

## Reproduction and cause

The rendered regression opens a committed prefix containing union timestamps 0
and 0.5, appends an incomplete record, then appends the remaining committed bytes.
This reproduces a viewer opened while Free Collapse is recording. The source
capture is read-only; only disposable copies are grown/truncated.

| Reproduction | Requested time | Union timestamps | Current union index | Slider before | Slider after |
|---|---:|---:|---:|---|---|
| Small independent-cadence fixture | 2.25 | 11 | 5 | value 1 / max 1: 100% | value 5 / max 10: 50% |
| Actual Free Collapse prefix through t=40 | 20.25 | 81 | 40 | value 1 / max 1: 100% | value 40 / max 80: 50% |

Both pre-fix runs failed five slider assertions while physical time, particle
interpolation and source-layer times remained correct. Before/after JSON reports,
logs and rendered screenshots are under `results/g3-timeline/`.

`SceneLayers.refresh()` published the refreshed union-clock frame count but did
not publish the slider extent. The G3 `sample()`/`tick()` path bypasses the legacy
`_refresh_frame_count_profiled()` wrapper that normally updates that extent.
Writing a later union index into `HSlider.value` therefore clamped it to the old
maximum. This explains why playback/time worked while the thumb stayed at the end.

The production fix calls the existing `_set_timeline_extent()` after a valid
source-generation refresh. Its existing guard prevents range clamping from
triggering a seek. Rejected source changes and pinned offline-source behavior
retain their existing checks.

## Sampling contract retained

The slider still uses the committed union timestamp index, including in Physical
time mode. It is not remapped to a continuous percentage of elapsed physical time.
ID-matched particle positions interpolate; particle scalars and volumes retain
their independent held source times. Fractional time seeks, frame mode, stepping,
endpoints and offline timing retain their existing semantics.

The small fixture records particles every 0.5 units and volumes at 0, 1.25, 3.25
and 4. At requested t=2.25, the particle scalar source is t=2, its ID-matched
position interpolates to x=2.25, and the volume source remains t=1.25. Volume-only
timestamps contribute to the slider's union clock. Tests also cover an incomplete
append, committed growth, playback/pause, native slider signals, fractional seeks,
frame stepping, the endpoint, truncation and guard restoration.

## Validation

- New rendered fixture: **28/28 checks** on Compatibility and Forward+.
- Actual Free Collapse data: **25/25 checks**, up from five failures before the fix.
- Existing Python unit suite and **23 G3 Python tests** pass.
- **251 G3 native storage checks** pass.
- **36 G3 rendering checks per backend**, plus a fresh layered four-frame video
  and its source-time/inspection-state audit, pass.
- G1–G3 regression runner passes typed storage/IDs, storage/index behavior,
  **34 recorded-pixel playback checks** against retained G1 behavior, inspection
  and pinned-source video, generic/legacy rendering, HUD layout, and the new
  timeline gate.

Machine-readable suite results: `results/g3-timeline/suite.json`.
Prior small regression evidence is preserved in
`results/g3-timeline/prior-regression-evidence.tar.gz`.

## Files and rerun commands

Production change: `viewer/layers/scene_layers.gd` (one helper call plus comment).
Regression: `viewer/layers/test_scene_timeline.gd`,
`tools/validate_scene_timeline.py`, and its gate in `tools/regression_g3.py`.

From `SimScope`:

```bash
python tools/validate_scene_timeline.py --godot /path/to/godot
python tools/regression_g3.py --godot /path/to/godot
```

The focused runner also accepts `--renderer forward_plus` and `--source PATH`
to replay committed prefixes of the Free Collapse capture without modifying it.
The complete maintenance suite is recorded in `results/g3-timeline/run_suite.py`.

Restart the viewer to load the updated script, then open the native layered
capture and use Physical time, playback or the timeline slider. No recapture or
conversion is needed. G4 remains deferred until explicitly requested.

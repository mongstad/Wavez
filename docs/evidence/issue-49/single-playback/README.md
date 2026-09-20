# PR #51 owner refinement: one playback clock

**Pending owner review.** This updates issue #49 on its existing branch. The owner
requested removal of the selectable index/recorded-time playback model. Earlier
[issue evidence](../README.md) remains unchanged as a historical checkpoint.

Recorded-time advancement is now unconditional. The selector is not constructed;
`time_mode`, `playback_fps`, mode switching, index-rate advancement, recipe fields
and mode-specific fallbacks are removed. Affected profiling/test harnesses and
matched-render job construction no longer refer to them. The interpolation phase,
union indices, stepping, buffering direction, caches and Hold remain useful and
are retained. Playback speed is the exact signed recorded-time rate; recipes now
validate negative and zero values too. Obsolete mode-bearing recipes are rejected
without migration. The export dialog initializes its independent forward-only
rate from positive playback speed, or 1× for zero/reverse; deterministic output
sampling is unchanged.

## Validation

Native host: Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti. Small synthetic
fixtures only; no scientific simulation reruns.

| Check | Result |
|---|---|
| Transport Forward+ | [132 checks passed](forward.json), source hashes unchanged |
| Transport Compatibility | [132 checks passed](compatibility.json), source hashes unchanged |
| Recipe/state headless | [2,998 checks passed](state.json), source unchanged |
| Readiness/performance maintenance | 66 checks passed |
| Playback lifecycle | 51 checks passed |
| Union timeline Forward+ | 28 checks passed |
| Video continuation Forward+ | 86 passing assertions, including 46 native UI checks; source unchanged |
| Python matched-render/recipe unit tests | 15 tests passed with unittest |
| Godot editor import, Python compilation, diff whitespace/local doc links | Passed |

The transport test count falls from 174 to 132 because the retired index-clock
matrix is removed; recorded-time progression, signed speeds, exact Seek/state,
cold/latest seeks, sparse Hold, layout, fullscreen access and drag hint remain.
State tests verify absent controls/fields, rejection of obsolete keys and exact
signed speed packing/restoration. Existing recipe ownership/session tests remain.
Summary of auxiliary runs: [validation.json](validation.json).

- [1440×900](loaded-1440.png)
- [1024×640](loaded-1024.png)
- [Retained sample-index dragging hint](index-drag.png)

Commands (repository root, externally installed `$GODOT`):

```sh
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-49-single-forward
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer gl_compatibility --output-dir results/issue-49-single-compatibility
python tools/validate_recipe_state.py --godot "$GODOT" --renderer headless --output-dir results/issue-49-single-state-final
python tools/validate_performance_maintenance.py --godot "$GODOT" --renderer headless --output-dir results/issue-49-single-maintenance
python tools/validate_scene_timeline.py --godot "$GODOT" --renderer forward_plus --label issue-49-single
python tools/validate_video.py --godot "$GODOT" --renderer forward_plus --continuation --output-dir results/issue-49-single-video-final
python -m unittest tests.test_analysis_matched_render tests.test_analysis_recipes
```

## Failures, limitations and owner checks

The first state test incorrectly included unrelated analysis-axis selectors in
its absence assertion. It was narrowed to playback controls; all 2,998 checks
then passed. An initial export-rate assertion used strict float equality on the
existing SpinBox; it now uses numeric tolerance and all final video checks pass.
Pytest is unavailable in the dev environment; these unittest modules were run
successfully using their native runner. No unresolved failures remain.

No large-capture benchmark, physical HiDPI matrix, full scientific suite or full
4K video suite was run. Native hover/drag is checked through control signals and
rendered evidence; physical pointer feel remains an owner check. No independent
KWin geometry probe was repeated. Status/Jobs was validated at the earlier PR
checkpoint and was not rerun for this refinement.

Follow [current manual checks](../../../UX3_MEDIA_TRANSPORT.md#owner-verification).
Confirm no playback-mode selector exists, then exercise 0.5×/1×/2×, zero/reverse,
Loop, exact Seek, cold replacement seeks, sample stepping and the retained hint.
Save/reload a new recipe at negative speed. Check that obsolete mode-bearing
recipes fail visibly rather than silently restoring a legacy clock. Verify the
export default and independently editable positive export rate. Stop for owner
acceptance; no later issue is included.

# PR #416 — owner visual review follow-up

Same issue #415 branch, based on `65c31ccb60b362692bea2d55db03d1dda15db627`.
Build remains **v0.1.0.116**. Owner review is pending; no merge, release, new issue
or board change is authorized or performed. The initial report and its validation
artifacts remain unchanged.

The owner confirmed the 9/25 plane, camera navigation, native-time-20 pinning,
ordinary-image exclusion, numerical values and unresolved-support warnings.
The annotated screenshot raised menu obstruction, disabled Cancel after completion
and retained inputs. This revision addresses those observations only.

## Fixed: movable dialog with accessible menus

The borderless spectral form was already nonmodal, but its header handled only
native window-manager dragging. In the embedded window configuration, header
dragging did nothing. Its initial Y=20 also placed it across the 48-pixel menu bar.

The form now uses the same embedded/native split as the existing About dialog:
embedded header gestures move the window; supported native dragging remains
window-manager owned. It opens below the menu bar, clamps embedded movement to
the viewport and refits on resize. Release, focus loss and closing clear drag
state. Its moved position is retained for the session. There is no new panel host,
detachable workspace system or scientific state owner.

Real pointer events moved the form from `(804,56)` to `(164,80)` without moving
the viewport camera or changing its numerical result. The actual **View → Viewing
preset** menu selected Cinematic and then Scientific while the form stayed open.
Normal/compact bounds, Dark/Light and retained footer access were checked.

## Intentional: Cancel and retained settings

**Cancel is disabled after completion because no operation remains active.**
Compute enables it for the owned pending request; completion or cancellation
disables it. The screenshot's “Verified map ready” state is therefore correct.
The enable/disable and cancellation implementation was left unchanged.

The focused test also clicks the actual Cancel button during a real batch. A
generated float32 field of shape ZYX `(128,160,160)`, support 128³, Z-normal grid
8×8 and hop 4 gives 64 valid windows. The worker had reported 2/64 centers before
the button was clicked. Source/package callbacks returned in **1.263/0.720 ms**,
with acknowledgement in **67.7/60.1 ms**. The result was explicitly `cancelled`,
with no partial map. A following one-center request completed successfully.
These timings are observations, not guarantees or a count of every center that
may have completed between progress publication and cancellation.

**Closing/reopening retains inputs intentionally.** Like Spatial spectrum and
the existing Tools host, closing hides the retained form. On the same source,
reopening keeps its native-time pin, grid/band, display choices and completed
result; it does not queue work. A cancelled form retains its draft without
restarting. Source close still clears derived data. These behaviors were verified
and preserved. **Show map** is the control for hiding a completed plane.

## Validation and remaining runtime limitation

Godot 4.7.2, Forward+ Vulkan, Linux X11, RTX 3070 Ti. Only generated synthetic
captures were used; their hashes remained unchanged. No Model A/solver rerun was
needed for this presentation-only correction. No tests were skipped.

| Check | Functional result | Native diagnostics | Strict result |
|---|---:|---:|---|
| Focused source viewer | 28 passed | 0 | PASS |
| Focused local release package | 28 passed | 18 errors | **FAIL — external Popup diagnostics remain** |
| Standalone Popup source probe | 18 passed | 0 | PASS |
| Standalone Popup release probe | 18 passed | 32 errors | **FAIL — reproduces known runtime defect** |
| Application version contracts | 2 passed | — | PASS |
| Source import; package import/export | completed | 0 build/import errors | PASS |

The release package's actual menu actions work, but its native error log is not
clean. Fresh runs of the existing #335 minimal probe reproduce the documented
[Godot release-template Popup cleanup defect](../../ROOT_WINDOW_SIGNALS.md)
without loading Wavez. Source clears Popup-owned `focus_entered`/`tree_exited`
callbacks on hide; release retains them and reports nonexistent-disconnect and
duplicate-connect errors. Both standalone processes exit 0; strict validation
correctly exits 1 for the release errors.

The focused package records eight root disconnect errors, six duplicate-connect
errors and four disconnect errors on a parent PopupMenu, all for that signal pair.
The four parent-PopupMenu errors are retained separately from the existing probe's
root-only classifier. No message was filtered, no engine/template changed, and no
Wavez focus workaround was introduced. **This external limitation remains
unresolved.** The package's 28 functional passes are not a clean package-validation
pass. The validator now prints its strict result separately from Godot's process
exit, so native exit 0 is not mistaken for clean validation.

The first new source test attempt passed dragging and active cancellation but
failed its two menu assertions because the test sent keys directly to a popup
viewport. Correcting the harness to the established window-ID/native input route
made both real menu selections pass. That failed attempt is not counted as a PASS.
Independent code review found no remaining defect in the scoped dialog change.
Native compositor dragging, other operating systems and physical desktop gestures
remain owner checks; automated acceptance here exercises embedded interaction.

Retained evidence:

- [Source checks](follow-up/source.json) and [native log](follow-up/source-native.txt).
- [Package checks](follow-up/package.json) and [unfiltered native errors](follow-up/package-native.txt).
- [Standalone source](follow-up/popup-minimal-source.json),
  [standalone release](follow-up/popup-minimal-release.json) and
  [release log](follow-up/popup-release-native.txt).
- [Source import](follow-up/source-import.txt) and
  [scope, unchanged-code hashes and artifact checksums](follow-up/validation.json).
- [Cinematic with form open](follow-up/cinematic-open.png),
  [compact refit](follow-up/compact-refit.png),
  [enabled Cancel during measured progress](follow-up/active-cancel.png).

Production edits are confined to `spectral_band_map_controller.gd`. The numerical
backend, source verification, shared worker, plane/shader, main viewer and build
setting remain byte-identical to the reviewed baseline. The new native regression
script and the existing validator's `--dialog-review` mode exercise this slice.
Prior scientific/rendering evidence and the owner's confirmed checks are retained;
unrelated regression suites were not rerun.

## Owner checks

1. Open the spectral form on the same signed Model A capture and inputs used in
   the initial review. Confirm it starts below the menu bar. Drag its header;
   confirm the camera stays still and the form stays reachable after resizing.
2. Keep the form open and use **View → Viewing preset → Cinematic**, then
   **Scientific**. Confirm both apply while the numerical map remains pinned.
3. After completion, expect Cancel disabled. Close/reopen: expect inputs/result
   and moved position retained, with no automatic calculation.
4. To observe active cancellation on the N192 source, retain native index 20,
   amplitude and 128³ support. Use first start XYZ `0,0,32`, normal Z, centers
   `8,8`, hop `4,4`, band `[0.05,0.15)`. Compute, then press the enabled Cancel
   during center progress. Expect no partial map and eventual worker acknowledgement.
   The low-frequency support remains unresolved; this is a workload test only.

Reproduce the focused synthetic checks with new output directories:

```bash
python tools/validate_spatial_band_map_ui.py --godot "$GODOT" --dialog-review --output-dir /tmp/dialog-source
python tools/validate_spatial_band_map_ui.py --godot "$GODOT" --dialog-review --package --output-dir /tmp/dialog-package
python tools/investigate_window_signals.py --godot "$GODOT" --mode minimal --runtime source --output-dir /tmp/popup-source
python tools/investigate_window_signals.py --godot "$GODOT" --mode minimal --runtime release --output-dir /tmp/popup-release
```

`GODOT` is the external 4.7.2 executable. Release commands currently return a
nonzero strict status for the reproduced external errors. Captures, binaries,
templates and full temporary build outputs remain outside Git. The existing
stashes and unrelated resize UID sidecars remain preserved.

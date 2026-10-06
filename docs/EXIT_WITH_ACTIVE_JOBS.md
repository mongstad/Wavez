# Exiting with active jobs

Issue #124 adds an application-exit warning in candidate build `v0.1.0.66`,
pending owner review. [Validation and owner checks](evidence/issue-124/README.md)
record the tested development/package paths and remaining desktop review.

File → Exit, the main close button and the native Window close signal use the
same gate. If any shared Jobs row is active, a compact modal says:

> Active jobs are still running
>
> Exiting WAVEZ will cancel all active jobs.

It offers exactly **Exit WAVEZ** and **Cancel**. Cancel receives initial focus;
Enter on that focused button cancels the exit request. Escape or window dismissal
also cancels. Tab/Shift+Tab stay inside the two choices. Cancelling leaves the
viewer and jobs running and restores the initiating focus through the shared
[focus policy](FOCUS_NAVIGATION.md). Repeated close requests reuse the same
dialog rather than stacking prompts.

The gate refreshes the existing Jobs rows and reads their `active` flags. It uses
the same owners as the overview: Video export, Selections, Analysis, Matched views
and Isosurface. Preparation and cancellation waiting for acknowledgement count
as active where those rows already represent them. Idle background workers and
scientific cache preparation do not count as Jobs operations. Completed, failed
and cancelled operations do not warn. A future operation represented by an
active shared row participates without a separate exit tracker.

Closing Jobs, Details or the export form only dismisses that surface and does
not invoke application exit. Backgrounding or reopening a running job does not
remove it from the gate. The existing Cancel video export confirmation is a
separate path and is unchanged.

With no active Jobs row, exit continues immediately. Confirming Exit WAVEZ calls
the existing SceneTree quit path: export/matched owners issue their current
cooperative cancellation requests, analysis and source owners run their existing
cleanup, and workers retain their existing acknowledgement/termination behavior.
No new wait, cancellation protocol, job history or cleanup subsystem is added.
Scientific state and playback are unchanged while the prompt is open or cancelled.
Offline render workers retain their separate close handling and omit the
interactive close gate.

The implementation lives in `viewer/ui/shell/window_chrome.gd`, the read-only
`viewer_status.gd.has_active_jobs()` query, and `exit_confirmation.gd`. The native
SceneTree automatic quit behavior is disabled for the interactive viewer so
native close requests cannot bypass the gate. The dialog uses the existing
surface, PanelTitle, DestructiveButton and SecondaryButton theme resources.

Run focused checks with an externally installed Godot, native display access and
fresh temporary output directories:

```sh
env -u WAYLAND_DISPLAY python tools/validate_exit_confirmation.py --godot /path/to/godot --output-dir /tmp/exit-forward --renderer forward_plus
env -u WAYLAND_DISPLAY python tools/validate_exit_confirmation.py --godot /path/to/godot --output-dir /tmp/exit-compatibility --renderer gl_compatibility
env -u WAYLAND_DISPLAY python tools/validate_exit_confirmation.py --godot /path/to/godot --output-dir /tmp/exit-package --renderer forward_plus --export
```

The runner uses synthetic captures and isolated runtime preferences. Its dialog
matrix injects representative owner state; the separate lifecycle cases launch
real exports, check Cancel/reopen behavior, confirm shutdown, and verify cancelled
progress plus stopped renderer processes. `--export` requires externally installed
matching Linux templates and builds only a temporary debug package; no runtime,
template, capture, cache or package is committed.

The installed 4.7.2 Linux template used for review rejects the existing worker
launcher's `--path` override, also reproduced on accepted main. Packaged dialog
checks pass, but real packaged active-job shutdown cannot be validated with that
template. `--dialog-only` independently checks the UI, with either `--export` or
`--packaged` to reuse a previously built executable. The full failed lifecycle
attempt and baseline reproduction remain in the evidence.

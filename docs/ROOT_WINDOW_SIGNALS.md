# Linux release Window signal diagnostics

The installed official Godot **4.7.2 `ed1daf0bf` Linux x86_64 release template**
fails to remove embedded Popup callbacks from the root Window when a Popup is
hidden. This reproduces in a standalone project containing only a PopupPanel
and PopupMenu. The same project clears both callbacks with the source engine and
debug template. No Wavez capture, exporter, Jobs, custom focus handler or manual
viewer teardown is needed to trigger it.

This is a real native Popup cleanup defect in the tested release template, not
evidence that Close File cancels exports or retains capture payloads. It can
occur during normal Seek/menu use before application exit. Actual physical
input/display behavior remains an owner check; automated production-scene routes
do not certify physical interaction.

## Ownership and counts

Godot's [`Popup::_initialize_visible_parents()` and
`_deinitialize_visible_parents()`](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/gui/popup.cpp#L54)
connect and disconnect root `focus_entered` → `_parent_focused` and
`tree_exited` → `_deinitialize_visible_parents`. Hide, close request and tree exit
invoke cleanup. Wavez's chrome has its own distinct `restore_minimized` callback;
the custom focus navigator does not install this native Popup signal pair.

In release, signal introspection records one callback for each signal after
showing **and after hiding** a Popup. Source/debug record one when shown and zero
when hidden. The first hide emits two nonexistent-disconnect errors. Each later
show/hide emits two duplicate-connect errors and two nonexistent-disconnect
errors. The retained slot count stays one per signal, rather than growing on
every cycle. A temporary exact-harness probe also found zero orphan nodes and no
Popup-owned root callbacks after the viewer was freed.

The historical #329 baseline smoke exercised one File Popup cycle: **2 errors**.
The complete #329 harness additionally exercised the same Seek Popup eight times:
`2 + 7 × 4 = 30` Seek errors, plus 2 File errors = **32**. Matching archived
baseline/accepted-main smoke routes and matching accepted-main/candidate exact
harness runs confirm this difference in interaction coverage. It does not justify
calling an arbitrary similar error pre-existing without reproduction.

The original #329 Python validator concatenated stdout followed by stderr.
Consequently errors appeared after the completion print in its saved log;
that ordering did **not** establish that they occurred during final teardown.
The new probe merges the streams with Linux line buffering and records signal
state at each action. It retains all messages, including unclassified errors.

Release callables lack their debug text in
[`callable_mp.h`](https://github.com/godotengine/godot/blob/ed1daf0bf/core/object/callable_mp.h#L53),
explaining the empty callable names. The visible retained slot and failed lookup
in [`Object::_disconnect`](https://github.com/godotengine/godot/blob/ed1daf0bf/core/object/object.cpp#L1644)
are consistent with native callable identity/hash comparison failing in the
release binary. The precise compiler/toolchain cause has **not** been established
by a local engine build or bisect.

Upstream [Godot #89657](https://github.com/godotengine/godot/issues/89657) describes
the same Linux release-template behavior and reports later development builds
without it. That report is corroborating context, not validation of another
engine version here. No engine binary, compiler patch or third-party source is
vendored. No Wavez focus/window workaround, error filter, release-to-debug
packaging change or scientific runtime change is made.

## Reproduction

Use fresh directories, an externally installed Godot with matching Linux
templates, FFmpeg, Python/NumPy and Linux `stdbuf`:

```sh
python tools/investigate_window_signals.py --godot /absolute/path/to/godot \
  --mode minimal --runtime release --output-dir /tmp/signals-minimal-release
python tools/investigate_window_signals.py --godot /absolute/path/to/godot \
  --mode minimal --runtime debug --output-dir /tmp/signals-minimal-debug
python tools/investigate_window_signals.py --godot /absolute/path/to/godot \
  --mode minimal --runtime source --output-dir /tmp/signals-minimal-source
python tools/investigate_window_signals.py --godot /absolute/path/to/godot \
  --mode workflow --runtime release --output-dir /tmp/signals-workflow-release
```

Historical `--renderer gl_compatibility` comparisons require an archived pre-#371
source root; current Wavez refuses that backend. `--source-root` accepts
an external read-only repository archive for matched baseline runs.
`--mode baseline-smoke` uses four real exports, Jobs and one File Popup, without
Close File or Seek. Workflow mode keeps the production Main scene and exits via
the normal chrome request, exercising two Close File/Open File cycles with
background workers, Jobs reopening, Seek dismissal and capture-owner reclamation.
It does not manually free the viewer. Both modes skip the probe in export workers.

Every run retains its full log, callback snapshots, functional checks, source
hashes and package hashes. Any warning/error, changed capture or functional
failure gives the tool a nonzero exit. **Expected diagnostics are still failures
of clean validation**, even when functional checks and Godot process exit pass.
Import a fresh Git archive before running its original source harness with
`godot --headless --editor --import --path /absolute/archive/viewer`.
The unchanged `validate_close_file.py` supplies independent decoded-pixel,
timestamp, sidecar, numerical, explicit cancellation and ownership regressions.
See [the current evidence](evidence/issue-335/README.md).

## Owner checks and remediation boundary

1. Launch the Linux release with its console/log visible. Open a small capture,
   show/dismiss Seek once and again, then show/dismiss File. Check whether the
   first hide produces the signal pair and reopening adds duplicate connects.
2. Start/background a video, Close File, reopen it from Jobs and open another
   capture. Confirm normal empty/source state, completion and cancellation through
   the export's own controls. Compare output with the unchanged control recipe.
3. Repeat the popup steps without Close File, then exit through File → Exit.
   Distinguish popup-hide diagnostics from shutdown/job failures.
4. If considering another externally installed engine/template, rerun the minimal
   probe first and the focused source/release Close File/export matrix next.
   Reaching zero errors in another engine is not yet verified here.

The smallest justified remediation is a corrected external Godot release
template, validated on these routes before adoption. An engine upgrade/rebuild
is not performed by this investigation. Until then release diagnostics remain
visible, classified and unresolved; a broad Wavez window/focus refactor would not
address the isolated failure demonstrated here.

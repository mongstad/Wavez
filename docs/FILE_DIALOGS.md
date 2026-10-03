# Scene and video file dialogs

Current WAVEZ opens WAVEZ Scene Format `*.wvz` through the desktop's native
file picker when the display server supports it. The window title is **Open
File**, and its sole format filter is **WAVEZ Scene Format** (`*.wvz`). The
desktop environment owns native bookmarks, Recent locations, navigation,
accessibility, Open and Cancel behavior. Godot falls back to its built-in
FileDialog on display servers without a native picker; its saved navigation
lists continue to work there. Issue #161 extends native selection to video MP4,
image-folder, geometry-override, diagnostic-data, inspection-state and other
genuine File/Tools filesystem pickers. Wavez-owned configuration and analysis
forms remain custom themed surfaces. Godot's navigation preferences continue
to serve built-in fallback pickers; the desktop owns native picker navigation.
See the [current dialog inventory](DIALOG_COHERENCE.md) and the
[current format policy](CAPTURE_FORMAT_POLICY.md).
The [issue #181 validation record](evidence/issue-181/README.md) separates
automated checks from physical desktop review.

The #50 report below records its original `.ssc` picker and review steps;
those are historical, not current supported file types.

Issue #50 is implemented for owner review, with candidate build **v0.1.0.9**.

File → Open capture… opens **Open capture**. Video export → Browse… opens
**Export video**. Both retain Godot's built-in `FileDialog`, filesystem access,
SSC/MP4 filters, selection/cancellation behavior and video overwrite confirmation.
`mode_overrides_title = false` keeps the domain-specific titles stable.
No custom browser or Recent widget is introduced.

## Navigation ownership

Godot supplies the Favorites controls, directory navigation, Recent display and
stale-directory pruning. Its runtime lists are **shared across FileDialog
instances**, contain **directories rather than files**, and live in memory.
The supported static `get_favorite_list` / `set_favorite_list` and
`get_recent_list` / `set_recent_list` APIs allow applications to persist them.
They are not automatically saved like the editor's own preferences.
See the [Godot FileDialog API](https://docs.godotengine.org/en/stable/classes/class_filedialog.html)
and the [source matching tested Godot 4.7.2](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/gui/file_dialog.cpp).

SimScope loads these lists once when constructing the interactive viewer and
saves them when either affected picker closes, after successful capture loading,
and on normal viewer teardown. Storage is `user://file_dialog_preferences.cfg`,
section `navigation`, keys `favorites` and `recent`. This is local UI preference
state; it is excluded from captures, scientific sessions, recipes/view presets
and deterministic export. Offline viewer/render-worker instances do not create
the preference service or write it. No actual user paths are shipped.

Favorites added or removed in either picker are consequently shared with the
other picker. Godot's other built-in FileDialogs also see the same engine-global
lists; they are not separately restyled or given new selection handlers. The
existing OS-native view-preset picker remains platform-managed.

Recent capture directories are added only after the existing open operation
reports success, including command-line capture opens. A picker-open snapshots
history; selection removes Godot's premature addition before asynchronous loading
starts. Success promotes the **actual selected file's parent directory**, removes
duplicates, and keeps at most 20 entries. Cancellation, rejected busy opens and
failed/corrupt opens do not add or reorder capture history. This uses existing
interactive load validation, not a new full-payload integrity check.

Video Recent retains Godot's selection-time behavior: choosing an output path
records its directory; this does **not** mean encoding has finished or even
started. Cancelling the picker or its overwrite confirmation adds nothing.
Godot prunes missing Favorite/Recent directories when a picker opens, and those
changes are saved when it closes. Missing files remain subject to normal picker
and capture-reader errors. Unavailable/corrupt preference files produce a warning
and do not prevent scientific loading. Concurrent interactive SimScope instances
share the preference file; the last writer wins. Forced termination before a
picker closes is not a durability guarantee.

## Diagnosis of the previous behavior

Neither original dialog saved or restored the runtime lists, explaining loss of
Favorites and Recent on application restart. The owner reported working Recent
in video export but no capture Recent. On the tested installed engine, unmodified
open and save dialogs **both** populated Recent through their normal selection
path. The engine's `_action_pressed()` calls `_save_to_recent()` in both modes;
file activation uses that same path. This aspect of the owner's observation was
not reproduced, and is not attributed to a nonexistent global Godot failure.

A verified application-level difference was that capture loading can bypass the
picker (`--capture`/direct open), whereas export destination selection passes
through it. Those capture opens previously added no picker history. Another
engine limitation is that a typed absolute filename records the browser's current
directory rather than necessarily the selected file's parent. Recording accepted
capture opens at the loader boundary addresses both paths; it does not establish
which path caused the owner's earlier observation.

## Validation and platform limits

[Recorded validation](evidence/issue-50/validation.json) includes phase counts,
fixture hashes and retained diagnostics. The [accepted-main probe log](evidence/issue-50/accepted-main-dialog-probe.txt)
records expected pre-fix differences and the reproduced GL warnings.

Tests use isolated preference directories and tiny generated SIMSCP4 captures;
they do not modify the owner's bookmarks or rerun production simulations.

- Godot 4.7.2 (`ed1daf0bf`), Fedora 44 KDE/Wayland, NVIDIA RTX 3070 Ti.
- Native Forward+: **90 checks passed** across seven fresh processes.
- Native Compatibility: **90 checks passed** across seven fresh processes,
  with **12 known GL cleanup diagnostics** (two per viewer lifecycle phase).
  The same two `Texture ... leaked 349524 bytes` / `~Utilities` diagnostics were
  reproduced using the identical interaction harness against accepted main
  `b33e9a8`, without this implementation. Waiting extra frames, explicit draws
  and omitting screenshots did not remove them. The runner retains the exact
  diagnostics in its summary, allows at most two per phase, and rejects other
  errors. These runs establish behavior, not a clean renderer shutdown.
- Existing viewer shell: **661 checks passed per renderer**, including accepted
  capture failure/recovery, presets, menus and About/version behavior.
- Existing status/export lifecycle: **261 checks passed per renderer**, including
  destination locking, export completion/failure and cancellation. Each run
  retained **two existing encoder PID-cleanup diagnostics** under that suite's
  existing exact diagnostic allowance.
- Version metadata/CLI: **2 Python tests passed**. Import, Python compilation
  and `git diff --check` passed.
- The suite operates real built-in Favorite, Open, Save and Cancel controls,
  checks both titles/filters, independent Favorite add/relaunch/remove/relaunch,
  successful Recent/relaunch, corrupt/busy/missing capture paths, typed absolute
  paths, cancellation, overwrite cancellation, stale directories, and offline
  preference isolation. Fixture hashes remain unchanged.
- Review screenshots confirm both visible titles and Favorites/Recent lists at
  1440×900 on Forward+. Compatibility screenshot readback is omitted from the
  final harness. Native tests use Godot's built-in picker on the Wayland display server,
  **not** the KDE portal picker.
- The initial sandboxed editor import hit socket/editor-settings restrictions;
  the import rerun with isolated settings and required access passed. An initial
  test used an invalid `popup_hide` signal; this was corrected to the supported
  Window visibility signal before passing validation.
- One experimental harness that awaited an idle redraw timed out; that
  synchronization change was removed. No production renderer code changed.
- The first native run passed its baseline assertions but the strict harness
  rejected a libdecor GTK initialization warning with inherited
  `GDK_BACKEND=x11`. The test harness now sets `GDK_BACKEND=wayland` for explicit
  Wayland runs; the clean rerun passed. Product environment settings are unchanged.

Other operating systems, physical high-DPI/mixed-monitor interaction and
sandboxed packages forcing an OS-native portal dialog are untested. Native
portal dialogs own their own UI/history; Godot's shared runtime lists cannot
promise control over platform history or when that platform records selections.
No picker implementation was changed to obtain title or persistence behavior.

Run the focused suite with an externally installed Godot executable:

```sh
python tools/validate_file_dialogs.py --godot /path/to/godot \
  --output-dir /path/to/new-test-output --renderer forward_plus
```

Use `--renderer gl_compatibility` for the second backend; `--display-driver`
accepts `wayland` (default), `x11`, or `headless`. Each invocation needs a new
output directory and produces logs, phase reports, screenshots and a summary.

## Owner verification before acceptance

1. Launch the candidate and verify Help → About reports `v0.1.0.9` (reconcile
   against accepted main if another PR merges first).
2. Open File → Open capture…: verify **Open capture**, the SSC filter, and add a
   Favorite using the star. Cancel, quit and relaunch; verify it remains. Remove
   it, relaunch again and verify removal.
3. Open a representative SSC successfully, reopen the picker, and verify its
   directory in Recent. Relaunch and check again. Repeat using your usual launch
   method (including a capture argument if applicable), to cover the previously
   reported missing-Recent behavior.
4. Try a corrupt capture from a different directory, cancel another selection,
   and try a missing file. Verify no new successful capture Recent entry, and
   that a subsequent valid capture restores the accepted error/status behavior.
5. Open video export → Browse…: verify **Export video** and the MP4 filter.
   Repeat Favorite add/relaunch/remove/relaunch. Choose an output and confirm
   its directory in Recent after relaunch. Cancel a different destination and
   cancel an overwrite prompt; confirm the existing destination is preserved.
6. Add a temporary directory as a Favorite, close SimScope, delete that temporary
   directory, and reopen each dialog. Verify the stale entry is removed and the
   picker remains usable. Shared navigation state in both dialogs is expected.
7. Play the representative capture and make a short video export using your
   normal settings; confirm the accepted loading, playback and export workflow.

Owner acceptance and merge remain pending. Historical review reports/evidence
are preserved as written.

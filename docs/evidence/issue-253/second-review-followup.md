# PR #260: idle fullscreen capture and invocation parity

This follow-up addresses the owner's physical KDE/Wayland report. It supersedes
the earlier fullscreen acceptance claim; the initial and first-review evidence
files remain historical records. In particular, their phrase "physical Save
Image shortcut" described `root.push_input`, not a human keypress.

## Reproduction and diagnosis

Before changing `208d003`, a native Wayland / Forward+ probe kept the production
viewer `_process` enabled, opened the tiny particle fixture, entered fullscreen
and let the paused viewer become idle. It dispatched the production Save Image
command without injecting input or requesting a redraw. Observations:

```text
display=Wayland viewport=(2560, 1440)
low_processor=true viewer_processing=true draws_in_1s=0
after 3 seconds: inspection_busy=true screenshot_saving=true draws=0 files=[]
after Escape: inspection_busy=false screenshot_saving=false PNG=(2192, 1288)
```

Escape was injected only after the stalled interval as diagnostic recovery.
This reproduced the reported deferred write and wrong post-exit dimensions.
Both ordinary and durable captures awaited `RenderingServer.frame_post_draw`
after `process_frame`, but on-demand rendering had no new draw scheduled. Escape
caused a native fullscreen configuration/redraw and released the pending capture.
`inspection_busy` also blocks viewport double-click handling while pending,
whereas the fullscreen Escape handler remains available.

The earlier regression called `view.set_process(false)`. That bypassed the
production `_update_render_pacing()` policy and allowed continuous drawing, so
its successful synthetic shortcut/double-click sequence missed this failure.

## Changes

- Both capture paths retain the process-frame yield and stable scientific-state
  fingerprint, then synchronously request their own draw. Neither path passively
  waits for `frame_post_draw`. The existing bounded surface/selection readiness
  checks and paused rendering policy stay intact.
- Fullscreen always captures the entire drawable viewport. A revealed 48 px
  top bar, dock or bottom transport never contributes a crop boundary, including
  when the user opens File → Export → Image.
- Chrome and embedded windows are suppressed only during synchronous readback.
  Popups are collected before hiding parent controls. Visibility, scientific
  legend placement and focus are restored before returning, including failed
  readbacks. The shell remains present throughout.
- Fullscreen scientific legends use their unobstructed fullscreen placement in
  the PNG, so a temporarily revealed dock/transport cannot change composition.
  Camera and scientific/world transforms are unchanged. Windowed crop behavior
  remains as before.

## Focused native results

Godot 4.7.2, Fedora/KDE, native **Wayland** display driver, NVIDIA RTX 3070 Ti,
2560×1440 fullscreen. These are automated native runs, not physical owner
acceptance. All four runs exited successfully.

| Check | Forward+ | Compatibility |
|---|---:|---:|
| Live idle fullscreen regression | [56 PASS](forward-idle-fullscreen.json) | [56 PASS](compatibility-idle-fullscreen.json) |
| Existing viewport/crop regression | [64 PASS](forward-second-review.json) | [64 PASS](compatibility-second-review.json) |
| Idle shortcut capture | 213 ms; 2560×1440 | 187 ms; 2560×1440 |
| Idle File Image dialog capture | 200 ms; 2560×1440 | 187 ms; 2560×1440 |
| Idle selection-aware capture | 260 ms; 2560×1440 | 242 ms; 2560×1440 |

For every idle case the regression requires zero draws over 0.6 seconds while
the real viewer continues processing and low-processor mode is enabled. It
does not inject an input/window event or draw after starting capture. It checks:

- identical fullscreen pixels for shortcut, menu and all revealed edges;
- completion while still fullscreen, followed by immediate double-click exit;
- unchanged immersive, edge-reveal, popup, focus, chrome/legend layout, camera,
  sample and scientific world state;
- ordinary and durable readback failures publish no PNG and clear both busy
  flags; successful durable saves verify dimensions and PNG hash;
- unchanged source fixture hashes.

The new test first tried visible selection markers, whose existing per-tick
transform uploads prevent zero-draw idle. The durable idle cases therefore use
the supported hidden-preview state while retaining selection definitions and
the verified bundle. The existing viewport regression still covers visible
selection previews. An initial sidecar assertion also required explicit integer
conversion of JSON dimensions; the PNG dimensions/hash themselves matched.

The existing particle/field/mesh/mixed, eligible-legend, orbit-editor, Tools,
shortcut, hidden-dock and both sidecar checks pass. The native Wayland runs
produced a 1448×932 drawable for the requested 1440×900 window, cropping to
1080×780: the same accepted 368×152 chrome footprint. Hidden-dock output expanded
to 1448×780. The [new fullscreen PNG](idle-fullscreen-save.png) was also visually
inspected; it contains the fixture and scientific legend with no chrome.

Commands (use distinct, nonexistent output directories for each run):

```sh
python tools/validate_save_image.py --godot "$GODOT" --renderer forward_plus --display-driver wayland --idle-fullscreen --output-dir /tmp/wavez260-idle-forward-final
python tools/validate_save_image.py --godot "$GODOT" --renderer gl_compatibility --display-driver wayland --idle-fullscreen --output-dir /tmp/wavez260-idle-compatibility-final
python tools/validate_save_image.py --godot "$GODOT" --renderer forward_plus --display-driver wayland --output-dir /tmp/wavez260-window-forward-final
python tools/validate_save_image.py --godot "$GODOT" --renderer gl_compatibility --display-driver wayland --output-dir /tmp/wavez260-window-compatibility-final
```

Python compilation, version inspection (`v0.1.0.51`) and diff whitespace checks
pass. An auxiliary sandboxed editor import used to generate the new script UID
reported denied TCP/editor-settings access; this was not counted as a test pass.
Native validation logs have a nonfatal libdecor GTK-plugin warning.
No packaged-app, other-platform or unrelated full-suite run was performed.

## Physical owner verification still required

1. On the owner's desktop, open a representative capture, pause playback and
   disable Auto Orbit. Enter fullscreen and let it sit idle.
2. Press the configured Save Image shortcut, then provide no further mouse,
   keyboard or window activity. The PNG must appear without Escape, while still
   fullscreen, at 2560×1440. Double-click immediately afterward to exit.
3. Return to fullscreen with the same scene/view, reveal the top edge and use
   File → Export → Image. Save and compare composition and dimensions with the
   shortcut image. The 48 px bar must neither crop nor appear in the image.
   Check that the export dialog and edge state recover; close the dialog and
   double-click the viewport to exit.
4. Repeat with a scientific legend and revealed right/bottom edges, then confirm
   ordinary windowed Save Image still crops only the visible scientific area.

The owner retains acceptance and merge authority. Automated command dispatch,
even with the real idle render policy, does not replace these physical checks.

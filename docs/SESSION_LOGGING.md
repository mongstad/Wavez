# Session troubleshooting logs

Candidate build 42 creates a separate human-readable log for each interactive
Wavez session in Godot's platform-specific `user://logs` directory. On Linux with
the current project setting, that is normally
`~/.local/share/godot/app_userdata/WAVEZ/logs/`. The filename contains local date,
time, process ID and a monotonic suffix, so two launches in one second stay distinct.
The log records the application version and a clean session end. The offline video
render worker does not create an interactive action log.

The central logger currently defaults to **Verbose**. Its policy can also be set
to **Minimal** (lifecycle, file, jobs, key playback and errors) or **Disabled** by a
future preference; this issue adds no settings UI. Common buttons, toggles,
dropdowns, committed text/numeric values, menus, tabs, window actions, Tools
routes, shortcuts, source binding, bookmarks, playback and jobs are recorded.
Dropdown choices appear once as labeled `CONTROL` entries; `MENU` identifies
commands chosen from application menus.
Slider motion is coalesced into effective values; the playback clock and video
progress are never logged frame by frame. Text is recorded on submit or focus
loss, not per keystroke. Password fields and controls named for credentials are
redacted.

Local logs intentionally include both the source filename and full path when a
capture is opened or bound. Retained failures include the current playback time,
frame, active tool when visible, and the analysis budget for memory-related
failures. These values are diagnostic context, not a serialization of the scene.
Logs should be reviewed before sharing because full local paths can identify the
owner or run folder. A future export flow may offer path redaction.

Each file stops at 2 MiB. Startup keeps at most 30 Wavez session logs and at most
64 MiB in the directory, deleting oldest matching session logs first. Logging is
best-effort: inability to create or write a log does not prevent capture opening,
playback or shutdown. No simulation payload, environment variables or keypress
stream is written.

## Owner check

1. Start Wavez, open particle-only, volume-only and mixed WVZ1 captures in
   separate sessions, then inspect the newest files in `user://logs`.
2. In the mixed scene, open Tools → Selection, bind the source, create a bookmark,
   seek elsewhere and choose Go to bookmark. Confirm the filename and full path,
   tool route, binding, bookmark and time seek appear in order.
3. Run and cancel an analysis or export job; inspect start, cancellation and
   completion/failure records. Trigger an invalid seek and inspect its warning.
4. If a Selection failure occurs, check its time, frame and 512 MiB analysis
   budget context. A retained failure can be reported later than the event that
   originally caused it; the log's event order is the useful evidence.
5. Close normally and confirm the final session-end line. No long playback should
   produce a frame-by-frame log stream.

Focused automated validation uses `tools/validate_session_log.py` with a local
Godot executable and writes isolated synthetic WVZ1 captures and log files under
its specified output directory. Real 192³ / 50k production-scene replay remains
an owner integration check.

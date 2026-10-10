# Close File

**File → Close File** unloads the current WVZ capture and returns to the ordinary
empty viewer. It is disabled when no capture is loaded. The window, Open File,
menus, theme, preferences and Jobs remain available. Open another capture normally.
Close File has no keyboard binding or tooltip.

Closing stops playback and Auto Orbit, dismisses capture tools and the orbit/seek
editors, clears capture selections, legends, timeline and category state, and
releases the viewer reader, decoded/prepared caches, current/trail buffers,
layer nodes, textures, meshes and derived geometry. Preparation workers stop and
join before their owning nodes are disposed. Capture-generation changes invalidate
deferred range/seek work. Completed named analysis results retain their explicit
source bindings as before; they are separate session results.

These allocations become available for reuse/reclamation. The operating system
and graphics driver may retain memory; no immediate RSS or VRAM reduction is
guaranteed. Capture and exported scientific bytes are unchanged.

A launched ordinary or selection-aware video export continues through Close File,
including when backgrounded. It owns its serialized camera/scene snapshot, pinned
recipe/assets and independent capture reader. Use **Jobs → Video export → Open…**
or **Details…** to follow it after closing or opening another capture. Its own
Cancel export action remains available. Closing does not send cancellation,
replace job files or run application shutdown. An old idle video draft cannot
start against an unloaded capture.

Image capture, video selection-recipe preparation, active selection/analysis
jobs (including numerical exports and pending cancellation acknowledgements),
and matched-view preparation/rendering retain their capture session. Close File
refuses the close and explains the dependency in **Close File unavailable**.
The loaded scene and job remain intact. Wait for completion and choose Close File
again; the command does not automatically retry or cancel dependent work.
Capture-only preparation and isosurface extraction stop as part of unloading.

**File → Exit** still uses its existing active-job confirmation and shutdown
behavior. Close File never exits the application.

## Owner verification

1. Open a WVZ containing particles, fields and meshes. Use Close File while paused
   and again during playback. Confirm the empty Open File view, disabled Close File,
   cleared legends/timeline and responsive shell. Repeat with each source kind.
2. Open a different WVZ after each close. Confirm its first sample, correct
   category, fresh selections and normal playback. Theme, shortcuts and File
   Locations must retain their preferences.
3. Start a multi-frame video, background it, and choose Close File while it runs.
   Reopen it from Jobs, open a different WVZ, and wait for completion. Compare
   decoded frames, timestamps and inspection sidecars with a control export made
   from the same snapshot without closing. Repeat with recorded selections.
4. Start a numerical export or a selection/analysis job, then choose Close File
   immediately. Confirm the dependency explanation and unchanged scene/job.
   Let it finish, verify output, and retry Close File successfully. Repeat during
   selection-aware video recipe preparation and matched-view work.
5. Watch resource monitoring across repeated open/close cycles. Confirm capture
   allocations become reclaimable; do not require an exact immediate RSS drop.
6. Start a video after reopening, choose Exit, and cancel the exit confirmation.
   Confirm the viewer and job remain active; cancel the job through its own control
   when finished reviewing.

See [review evidence](evidence/issue-329/README.md) for focused automated coverage
and remaining physical/long-session checks. Owner acceptance remains pending.

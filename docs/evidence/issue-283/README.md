# Video Export MP4 filter and output path — issue #283

Candidate **v0.1.0.70**, pending owner review. #283 was the first and only Ready
item. The exact owner-linked branch
`283-bug-video-export-preserve-mp4-file-filter-and-valid-output-path-on-first-export`
was checked out, clean, and at accepted main `f09fb52` (owner-merged PR #287 for
issue #284). GitHub linked-branch metadata matched. Fetch/prune and final base
checks passed; no implementation branch was created/switched and no Project
transition was performed.

## Change

The owner reports that typing in the native filename field selects All files.
Godot's FileDialog supplies that extra catch-all filter to the desktop and can
therefore return an extensionless filename without applying `.mp4`. Its original
Browse path also omitted the suggested/current filename.

Video Browse now calls the public `DisplayServer.file_dialog_show` API with
only the existing MP4 filter, while retaining desktop navigation and save
confirmation. It seeds the current filename (or capture-derived suggestion),
prevents duplicate pending native requests, and routes selection/cancellation
through the existing FileDialog signals. The embedded fallback remains available
and resets its MP4 filter on every Browse. Accepted extensionless filenames gain
`.mp4`; directories, empty and relative picker returns cannot replace the draft.
Start Export still applies its existing absolute-MP4 validation. Range, timing,
quality, camera, rendering, FFmpeg discovery and worker/publication code were
not changed.

## Focused checks

[Summary](summary.json), [development report](source.json), and
[release report](release.json) retain every assertion. Both native parent logs
are clean: [development](source-native.txt), [release](release-native.txt).

| Check | Result |
|---|---|
| Fresh Wavez profile, development Forward+ | 32 checks, zero failures |
| Fresh Wavez profile, Linux release Forward+ | 32 checks, zero failures |
| First extensionless / second explicit-MP4 Browse → Start Export | Four complete H.264 videos, each 320×180 and two frames |
| Fixture SHA-256 before/after | Unchanged |
| Actual native desktop popup, source and release | MP4 filter and suggested filename visible |
| Application identity tests | 2 tests PASS; build 70 |
| Warm Godot import, Python compile, whitespace | PASS |

The automated round trips press the production Browse button, edit Godot's
**embedded** filename control, confirm Save, verify the resulting absolute path,
and press Start Export without assigning the output directly. They test first
and subsequent suggested filenames, the MP4 selection during typing, Cancel,
injected native explicit/extensionless/directory/relative/empty returns, and
strict invalid manually entered output rejection. Capture remains a native
picker with its existing configuration. FFprobe verifies codec, dimensions and
actual decoded frame count; real worker rendering and encoding run unchanged.

The release test uses a baked parent review entry. Worker invocations dispatch
through unchanged Main.tscn, use the release executable/PCK and run after staging
is deleted, from unrelated `/tmp`, without a Godot editor on PATH. Godot and
FFmpeg remain external; no binaries or captures are committed.

Reproduce with:

```sh
python tools/validate_video_output_picker.py --godot /path/to/godot \
  --output-dir /absolute/new/review-directory
python -m unittest tests.test_application_version -v
```

## Screenshots and limits

The compositor capture was restricted to the active **Export video** window
created by each test and identified as the KDE portal picker. Actual native
popups: [development](source-native-picker.png),
[Linux release](release-native-picker.png).

The actual form after the first selection shows Output MP4 and Start Export:
[development](source-chosen-0.png), [release](release-chosen-0.png).
First completion: [development](source-complete-0.png),
[release](release-complete-0.png). Subsequent selection:
[development](source-chosen-1.png), [release](release-chosen-1.png).

Native OS filename typing, Save/Cancel and overwrite-confirmation round trips
were **not automated**. The native popup was inspected, and native callback edge
cases were injected. KDE's existing desktop preferences/bookmarks were retained;
Wavez preferences were isolated. No Compatibility renderer or unrelated
playback/scientific suites were run for this picker-only change. These results
are implementation evidence, not owner acceptance. Earlier evidence and pending
review wording remain unchanged.

## Owner verification

In both development and the ordinary Linux release, with fresh Wavez preferences:

1. Open a capture, File → Export → Video, then first Browse. Confirm the suggested
   MP4 filename and H.264 MP4 filter. Type a new filename without an extension;
   confirm the filter stays MP4, Save, and verify the chosen directory/name plus
   `.mp4` in Output MP4. Start and complete a short export.
2. Browse again, choose a different directory and explicit `.mp4` name, then
   complete a second export. Reopen Browse and Cancel; retain the previous path.
3. Check native overwrite confirmation without overwriting a wanted file, and
   verify an invalid/relative manually entered output retains the existing error.
   Spot-check Open capture and an unrelated save/directory picker.

Stop for owner review. No merge, auto-merge or manual issue closure is arranged.

# Video Export ETA — issue #285

Candidate build `v0.1.0.68`, pending owner review. #285 was the first and only
Ready issue when implementation began. Its existing linked branch was checked
out, clean and at accepted `main` `a39d9ca` (owner-merged PR #282).

The export dialog owns one session presentation estimator shared with Jobs →
Video export → Details. It consumes the published in-memory progress snapshot.
Initial seconds per frame use observed elapsed/frame count; later positive
frame/time deltas update that cost using a time-weighted exponential average
with a five-second time constant. Repeated consumers of the same snapshot do
not add smoothing samples. Sustained throughput changes receive about 63% of
the smoothing weight after five seconds. This remains an approximate rendering
ETA, particularly for heterogeneous frame costs and startup overhead.

The whole-second ETA is cached for 500 ms, so numeric replacements happen at
most twice per second. Unchanged rendered-frame snapshots do not create an
increasing ETA while the separate live elapsed clock continues advancing.
Formatting still supplies exact observed frame counts/percentages and existing
paths/diagnostics. The dialog avoids assigning identical complete status text;
Details retains its existing text-equality guard and scroll preservation.

New job identities, stage changes, regressing progress and changed frame totals
reset estimator state. Insufficient, invalid or stale progress suppresses the
estimate immediately. The existing stale threshold is max(10 seconds, three
cumulative average frame durations). Encoding and cancelling immediately replace
the rendering ETA with their existing unavailable message; successful video or
complete PNG sequences show zero; failed/cancelled terminal states have no ETA.
Terminal elapsed values continue to use the worker's frozen value.

There is no new Node, process callback, timer, file read or worker poll. The
existing 200 ms dialog and Jobs refresh paths call the estimator even while
Details is hidden; reopening shares the same job and estimate. Worker source,
job schema, progress.json, deterministic sampling, FFmpeg, output cleanup and
scientific data paths are unchanged. Historical reports remain as written.

## Focused validation

The reproducible runner covers deterministic presentation cases and actual
production dialog/Jobs Details routes in development and a Linux release test
package. The release harness changes the parent entry scene and subclasses the
dialog only to supply the existing delay test field. Its children load the
unchanged Main.tscn and production render worker, from the same executable/PCK.
Godot, Python/NumPy and FFmpeg remain external dependencies.

```sh
python tools/validate_video_eta.py --godot /path/to/Godot --output-dir /tmp/eta-source --renderer forward_plus
python tools/validate_video_eta.py --godot /path/to/Godot --output-dir /tmp/eta-release --renderer forward_plus --export
python tools/validate_video_eta.py --godot /path/to/Godot --output-dir /tmp/eta-compat --renderer gl_compatibility --short-only
```

Each run includes successful MP4, rendering cancellation, encoding cancellation
and encoder failure. The long run externally paces the child with SIGSTOP/CONT
between frame publications; the worker's existing test delay uses fixed-FPS
simulated time and alone cannot establish wall-clock duration. The parent and
live Details continue normally during pacing. This is controlled synthetic load,
not a sustained expensive scientific rendering benchmark. Deterministic tests
cover 6,000 jittering fast publications, repeated consumers, a five-second
speedup/slowdown, stale recovery, stage transitions, invalid progress, new jobs,
and large hour values. Actual Details tests exercise 1,000 duplicate refreshes,
background/reopen and stable terminal presentation. FFprobe and timing.jsonl
verify output frame count, dimensions, FPS and deterministic sample times.

[Recorded results, screenshots, failures and limits](evidence/issue-285/README.md)
provide exact outcomes. Broader camera/playback/analysis/scientific suites are
outside this presentation-only change's blast radius and were not rerun.

## Owner verification

1. Open a normal capture. File → Export → Video: choose a new MP4 path and a
   range large enough for several minutes of rendering, then Start Export.
2. Run in background; open Jobs → Video export → Details. Observe numeric ETA
   changes for at least a minute: it should be readable, with no faster than
   two replacements per second. Counts and elapsed should keep advancing.
3. Close/reopen Details and reopen the export through Jobs. Confirm the same
   worker/progress and consistent estimate; scroll long Details and confirm
   updates retain the scroll position.
4. Under your typical changing GPU/system load, confirm meaningful speed changes
   adjust the estimate over several seconds. ETA is approximate, not a deadline.
5. Watch rendering → encoding → complete: encoding must show its unavailable
   ETA, completion zero and frozen elapsed; play the resulting MP4.
6. Start a new export, cancel via Jobs and confirm acknowledgement, partial counts,
   no numeric ETA, no published MP4 and retained temporary files. The prior
   terminal Details must not be overwritten by the new job.
7. Repeat in your normal Linux release installation and desktop scale. The owner
   controls acceptance, merge, branch deletion and Project completion.

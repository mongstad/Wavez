# Issue #329 — Close File review evidence

Candidate **v0.1.0.89**, based on owner-accepted `main`
`e41ae56d210ef57666282194e4312a0536fbdee6` / PR #333. Issue #329 was the only
Ready item. Its existing linked branch was already checked out and clean,
matching local/remote main before implementation. Fetch/prune found no stale
references or completed local issue branches requiring deletion. No branch was
created or switched, and no historical review records were edited.
**Owner acceptance remains pending.**

## Implementation and ownership

File → Close File consumes the existing inspection/layer reset transition.
The viewer stops transport/navigation, joins capture preparation, disposes the
scene controller and GPU nodes, closes the reader, and clears particle buffers,
identity/history/category arrays, geometry, legends, selection previews, timeline
and stale idle export draft state. Reader and worker weak-reference observations
are in each `validation.json`. Completed named analysis results remain separate
session results, following the existing source-reset contract.

Video export's launched process opens its own reader from a serialized job.
Selection-aware export first publishes its pinned recipe/assets inside its job
directory. Close File keeps the export Window/controller, PID, job directory,
polling, progress and cancellation controls alive. Active image capture, selection
recipe preparation, selection/analysis jobs and matched-view work still share
session controllers: the command refuses closing before touching capture state
and explains the dependency. No cancellation, exit or force-GC path is invoked.

## Focused validation

Godot 4.7.2, Linux, NVIDIA RTX 3070 Ti; native logical resolution 1440×900.
Tiny generated WVZ1 fixtures cover particle-only, field-only, mesh-only and mixed
independent source clocks. No production scientific simulation was rerun.

| Run | Runtime checks | Process / validator result |
| --- | ---: | --- |
| Source, headless | 164 / 0 failures | Exit 0; clean pass; real GPU/video skipped |
| Source, Forward+ | 229 / 0 failures | Exit 0; clean pass |
| Source, Compatibility | 229 / 0 failures | Exit 0; clean pass |
| Linux release, Forward+ | 229 / 0 failures | Godot exit 0; validator exit 1 from signal diagnostics |
| Linux release, Compatibility | 229 / 0 failures | Godot exit 0; validator exit 1 from signal diagnostics |
| Existing selection regression, headless | 31 / 0 failures | Exit 0; clean pass |
| Application version unit tests | 2 / 0 failures | Pass: accepted main BUILD + 1 |

Python compilation, warmed Godot import and `git diff --check` passed. New scripts
retain their UID sidecars. Incidental import-created resize-script UIDs were
excluded. Initial sandbox/editor-settings and new harness type errors were
corrected before the clean reruns. The initial sidecar comparison used the wrong
filename glob; the final validator uses the worker's `inspection-*.json` files.

The matrix exercises two open/close cycles for all four source kinds, paused and
playing, Dark/Light theme preservation, an open orbit editor, repeated empty
close, stale seek dismissal, reopening another capture, dependency refusals,
real selection/temporal/numerical export completion, ordinary and selection-aware
live background video, Jobs reopening, and explicitly confirmed cancellation
after Close File. It checks that Exit remains the final enabled File command
after its separator; its implementation is unchanged.

Every source SHA-256 remains unchanged. For each native and release renderer:

- Ordinary and selection-aware control/closed MP4 pairs have identical decoded
  frames and timestamps, independently compared with FFmpeg `framemd5`.
- Both pairs have byte-identical `timing.jsonl` traces and six matching inspection
  sidecars. Selection-aware comparisons normalize only independently regenerated
  cohort key strings; selectors, source values, clocks, mappings, camera and
  render evidence remain compared.
- Real numerical exports made with/without a refused Close File attempt have
  byte-identical `values.csv`. The blocked job retains its original request ID,
  completes normally, and receives no cancellation request.
- Backgrounded video retains its PID and unchanged job JSON; a different capture
  can open while the worker continues with its original inputs. Its own Jobs
  cancellation confirmation receives normal worker acknowledgement after close.

The smallest meaningful scope here is capture disposal plus immediately connected
export/selection ownership. Reader/writer, playback algorithms, camera navigation
algorithms and export architecture were not changed, so unrelated full playback,
rendering, scientific-analysis and navigation suites were not run.

## Resource evidence

Each source run records charged reader metadata/cache and prepared worker status,
root particle-buffer sizes, engine static/video-memory monitors before/after,
and post-close ownership observations. The reader's held test reference has no
file, index/metadata or cache; capture layer and all three preparation-worker
weak references expire. Current/trail MultiMeshes have zero instances, CPU
particle/category arrays are empty, and capture geometry/selection GPU nodes are
disposed. This supports eligibility for reclamation/reuse. Engine monitors and
tiny fixtures do not certify whole-process RSS/VRAM behavior on large captures;
no exact immediate drop is promised.

## Package limitation and baseline reproduction

Both release runs complete all functional checks, all four videos, numerical
exports and output comparisons. The strict validator still exits 1 because each
run emits **32 root-Window signal diagnostics** involving `focus_entered` and
`tree_exited`: duplicate connections and disconnects of nonexistent connections.
Logs and `runtime_log_clean: false` are retained; these are not clean package passes.

An independently archived accepted-main release reproduction completes four real
videos and native dialog routes, then emits **two nonexistent-disconnect
diagnostics** of the same class. See `baseline-release-teardown.log` and the
retained first-party `baseline-release-smoke.gd`. It does not reproduce the
candidate's full count or duplicate-connect messages. Their complete cause and
the extent of any candidate/harness interaction remain **inconclusive**.
No runtime filtering or unrelated focus/engine changes were made to hide them.

Native screenshots show the unobstructed empty view immediately after unloading
during ordinary video export, before reopening transient native Jobs/video windows.
An additional diagnostic
checked actual visible control rectangles; native Window-texture readback after
those transient windows can omit unchanged controls. The selected-video empty
snapshot still exhibits this readback limitation and is not retained as visual
proof; its live control/ownership and output checks pass.

Unverified: physical input/display comfort, long sessions and very large captures,
exact OS memory return, Windows/macOS packaging, real matched-view completion and
long image capture races. Matched/image ownership guards have deterministic
state coverage; their physical workflows remain owner checks. No owner acceptance
is inferred from successful tests.

## Reproduction and owner review

```bash
python tools/validate_close_file.py --godot /path/to/godot --renderer headless --output-dir /tmp/close-headless
python tools/validate_close_file.py --godot /path/to/godot --renderer forward_plus --output-dir /tmp/close-forward
python tools/validate_close_file.py --godot /path/to/godot --renderer gl_compatibility --output-dir /tmp/close-compatibility
python tools/validate_close_file.py --godot /path/to/godot --renderer forward_plus --package --output-dir /tmp/close-release-forward
python tools/validate_close_file.py --godot /path/to/godot --renderer gl_compatibility --package --output-dir /tmp/close-release-compatibility
python -m unittest tests.test_application_version -v
```

Use fresh output directories. Release builds use external Godot templates,
Python/NumPy and FFmpeg; no third-party executable or generated capture is retained
in this evidence. Package hashes identify the tested temporary binaries/PCKs;
they are not distribution approval. `summary.json` also identifies the tested
production file bytes. The final screenshot changes wait briefly for native
handoff and capture before Jobs reopening; production bytes match all final runs.

Follow the exact [owner checks](../../CLOSE_FILE.md#owner-verification) before
acceptance, including package diagnostic review. Historical reports remain
unchanged. One PR targets main; no merge, auto-merge, manual issue closure or
Project transition is performed.

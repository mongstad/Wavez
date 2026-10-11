# Issue #340 — independent visual video and scientific workflows

Candidate **v0.1.0.93**; owner review is pending. No merge, tag, release,
publication, issue closure or Project transition is performed.

Issue #340, **VIDEO-ARCH — Decouple scientific selections and inspection
processing from MP4 export**, was the first and only Ready item in Wavez
Development. Its GitHub-linked branch was already checked out and clean:
`340-video-arch-decouple-scientific-selections-and-inspection-processing-from-mp4-exports`.
HEAD, local/remote main and the issue branch initially matched accepted main
`0843a778af37b30091b75d7a17840b024c9fc6e8`, owner-merged PR #339. GitHub showed
that predecessor history was merged; origin was fetched/pruned, main was
synchronized (`0 0`) and no completed previous local issue branch remained.
These conditions were checked again before publication.

## Implementation and shared-code audit

File → Export → Video now always uses an ordinary version-1 visual job. Selection
count never changes source binding, runtime dependencies, output quota, preparation
or inspection-record policy. The automatic recipe gate, scientific preparation
and its cancellation/status state, G4 quota control and hidden mandatory-record
UI were removed. Video uses the same local mutation/extent binding for every job.
The unchanged optional checkbox remains unchecked and available in Advanced.
Optional records describe visual/sample state and PNG hashes, with no scientific
selection results. Camera, timing, appearance, legends, render backend, external
FFmpeg, background Jobs, retention and graceful cancellation keep their contracts.

The owner's clarification requires markers to follow source elements without
scientific queries. The job carries only the existing resolved visual preview
subset, at most 512 markers, with colors and native addresses. Particle/mesh IDs
remain exact decimal int64 strings; positions use native display interpolation
and holding. Anonymous rows, face/point rows and grid addresses expire outside
their original sample. Probes retain world locations; derived markers require
the same displayed artifact. Layer visibility, clipping and Show hidden selection
retain their display meaning, including admitted native reads for hidden layers.
No ROI membership is recomputed, no new members enter the carried preview and
no membership claims are inferred from pixels. Disabled or unresolved previews
are absent. Scientific arrays, definitions, ROIs, groups and results are unchanged.

Shared scientific facilities are retained deliberately:

- `inspection_v3.gd` and `scene_snapshot()` are used by independent durable
  scientific saving, including `durable_controller.gd`.
- Tools → Matched Views explicitly prepares version-2 recipe jobs. Its exact
  schema, recipe/source permissions, selection barriers, output quota and scientific
  provenance remain in `render_job.gd` / `render_worker.gd`.
- The analysis job protocol, member/result persistence and packaged first-party
  Python archive serve independent Selection/Analysis and Matched Views. None were
  deleted or replaced. Packaging metadata now states their dependencies separately.
- Jobs and Close File no longer refer to retired video recipe preparation. Independent
  Analysis remains visible while video runs. Test fixtures use owned child PIDs
  for active-worker presentation rather than the removed preparation flag.

## Focused validation

Godot **4.7.2.stable.official.ed1daf0bf**, Linux, NVIDIA RTX 3070 Ti / driver
615.71.09. All sources are tiny generated WVZ1 fixtures; no production simulation
or scientific capture was rerun. Reports are copied without rewriting their contents.

| Check | Result and retained record |
| --- | --- |
| Final source Forward+ video matrix | **491 checks, 0 failures**, [report](source-forward.json) |
| Final source Compatibility video matrix | **491 checks, 0 failures**, [report](source-compatibility.json) |
| Final release Forward+ matrix and source comparisons | **552 checks, 0 failures**, [report](release-forward.json) |
| Final release Compatibility matrix and source comparisons | **552 checks, 0 failures**, [report](release-compatibility.json) |
| Native marker addressing, headless / Forward+ | **38 checks each PASS**, [headless](markers-headless.json), [Forward+](markers-forward.json) |
| Native marker addressing, Compatibility | **38 assertions pass**, strict result **FAIL** on the two baseline texture diagnostics below; [report](markers-compatibility.json), [log](markers-compatibility.log) |
| Independent Selection integration | **31 checks, 0 failures**, [report](selection.json) |
| Explicit scientific Matched Views | **50 checks PASS**, including exact frame membership, image hashes and matched pixels; [report](matched.json) |
| Close File and live exports / numerical output | **225 checks, 0 failures**; ordinary and selected control/closed decoded frames, timing traces and optional records match; numerical CSV matches; [report](close-file.json) |
| Video dialog layout and immediate interactions | **52 checks, 0 failures**, [log](dialog.log) |
| Version, scientific recipes and matched-render Python regressions | **17 tests OK**, [log](python.log) |
| Final import / Python compilation / diff whitespace | Godot import has no script/engine errors, [log](import.log); four modified/new Python tools compile; `git diff --check` passes |
| Connected Jobs/status | Candidate **322 checks, 2 focus failures**; accepted main **324 checks, the same 2 focus failures**; [candidate](status-candidate.json), [baseline](status-accepted-main.json) |

The MP4 matrices cover particles and mixed particle/mesh/field sources; no
selections, each source kind, multiple selections and disabled highlights;
explicit optional records off/on; legends off/on and orbit; background/Jobs
reopening; render/encode cancellation; missing and failing external FFmpeg;
parent shutdown; and missing-PCK child startup failure. FFprobe checks H.264,
320×180, FPS and frame count. Visible markers change decoded pixels; invisible
selection definitions reproduce ordinary pixels exactly. Marker traces independently
check particle motion across source brackets, mesh motion and native grid expiry.
Every completed release clip has identical decoded pixels and timing/sample/camera
trace to its source counterpart. Successful PNG cleanup and failed/cancelled
retention are checked; no partial final MP4 is published.

Release tests remove their staging checkout before execution, use an unrelated
working directory containing another project, exclude the Godot editor from PATH
and clear PYTHONPATH. Independent selections are created first through the actual
scientific worker; that worker is then shut down and a failing `python3` wrapper
is placed on PATH before starting video. Any attempted Python invocation writes
a failure sentinel. No video case invokes it or creates recipe assets. Children
use the packaged release executable/PCK and production Main scene. The parent
entry alone is instrumented. The package's scientific archive remains available
for the separate scientific setup; that archive is not a video dependency.

## Failed attempts and limitations

The retained [initial matrix](initial-source-failed.json) has nine failed checks:
the first marker implementation used an incorrect object transform field for
mesh/grid positions. The [initial mesh log](initial-mesh-failed.log) preserves the
actual error. The field lookup was corrected to `data_to_world`; all subsequent
source/release matrices above pass. Fixture corrections supplied the existing
manual-navigation hook, respected current inverted-range clamping, replaced
retired preparation flags, and waited for visible highlights before comparing
Close File snapshots. An initial Close File Python comparison expected retired
v3 scientific sidecars; it now compares ordinary visual records directly. These
were not new production lifecycle changes.

Two strict checks remain unsuccessful and are not masked:

1. The native marker-only Compatibility harness emits two **349,524-byte GL
   texture teardown errors**, after all assertions pass. Final render flushes and
   waits did not clear them. An unchanged accepted-main harness without the new
   marker code reproduces both errors: [log](markers-accepted-main.log),
   [exact harness](markers-accepted-main-harness.txt). Forward+ and the actual
   Compatibility source/release MP4 matrices finish cleanly under their existing
   encoder-diagnostic policy. This investigation establishes baseline reproduction,
   not a complete diagnosis of the texture lifetime.
2. Jobs focus checks fail twice at `Opening Jobs focuses the first available action`
   on unchanged main and the candidate: [candidate log](status-candidate.log),
   [baseline log](status-accepted-main.log). All other final status assertions pass;
   this run is not reported as a clean full-suite pass. An earlier accidental
   test-only field-state substitution was corrected before this final comparison.

The inherited video harness explicitly records the known killed-encoder PID
cleanup diagnostic. Each release report contains four log occurrences (parent /
worker copies); only that expected pattern and the intentionally missing-PCK
startup error are permitted. They remain visible. The earlier root-Window Popup
signal investigation remains [historical evidence](../issue-335/README.md).

Other operating systems/hardware, physical input/KDE behavior, mixed DPI/4K,
long research exports, large hidden-layer preview costs, and machine-wide removal
of Python/Godot remain unverified. PATH blockers and staging removal prove the
stated process boundaries, not physical uninstallation. Source mutation/integrity,
playback/cache core and unrelated camera/analysis suites were not rerun because
those implementations were unchanged. Numerical persistence and scientific
membership were covered at the connected boundaries above.

## Reproduction and owner verification

From the repository root, use a fresh directory for every command:

```sh
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/review-source --renderer forward_plus
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/review-release --renderer forward_plus --export \
  --compare-source /tmp/review-source
python tools/validate_video_markers.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/review-markers --renderer forward_plus
```

Repeat with Compatibility and fresh paths. Independent scientific checks and
packaging instructions are in [the package guide](../../PACKAGED_VIDEO_EXPORT.md).
A production-entry review package (not the instrumented test parent) is retained
outside Git at `/home/Nozba/Codex/Wavez/video-340-review/`; [build identity / hashes](review-package-build.json).
Keep its executable and PCK together.

1. Launch that executable from an unrelated directory; check Help → About shows
   v0.1.0.93. Select a usable external FFmpeg in File Locations if needed.
2. Open a `.wvz`; export a short clip with zero selections and the checkbox off.
   Verify MP4 playback, timing, camera, appearance and enabled legends.
3. With Python/NumPy available, create particle, mesh and field selections in
   Tools → Selection. Let their highlights appear. Export to a fresh filename:
   the same options/Advanced control remain available, no G4 quota appears,
   no recipe directory is generated and inspection JSON remains absent unless
   explicitly checked. Persistent-ID markers must follow displayed source motion.
   Sample-scoped marker expiry and the fixed preview subset are intentional.
4. Check Advanced's inspection checkbox explicitly and repeat; inspect retained
   visual records, without scientific selection results. Disable highlights and
   confirm the original pixels return. [Actual all-selection Advanced state](advanced-with-selections.png)
   and [compact dialog](dialog-compact.png) are retained for review.
5. Verify independent Selection, Temporal/Space-time Analysis, inspection
   save/restore, numerical result export and explicit Matched Views with their
   scientific dependencies available.
6. Start a longer small-fixture export, background it, reopen it via Jobs and
   Close File while it runs. Cancel through the confirmation and verify no final
   partial MP4. Repeat an encoder failure and parent Exit cancellation path.
7. Review the explicit baseline diagnostics above and physically check focus,
   actual research clips and desktop comfort before acceptance.

Current video/package/scientific-schema/Close File/dependency guides and status
were synchronized. All pre-existing review evidence, including historical pending
review wording, was preserved. Checks passing do not constitute owner acceptance.

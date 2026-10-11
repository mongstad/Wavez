# Issue #340 — exclude scientific overlays from ordinary Video Export

Candidate **v0.1.0.93**, pending owner review. The owner revised this issue to
exclude Selection and Analysis completely from File → Export → Video, including
visual overlays. This supersedes the earlier marker-following direction.
Nothing has been pushed, published, merged or marked accepted; no PR was created,
issue closed, Project transition made, or later issue started. The latest owner
instruction to keep this work local overrides the original push/PR step.

The Ready issue is **#340 — VIDEO-ARCH — Decouple scientific selections and
inspection processing from MP4 export**, on the exact existing issue-linked branch:
`340-video-arch-decouple-scientific-selections-and-inspection-processing-from-mp4-exports`.
The initial branch/main/origin baseline was `0843a778`, the owner's merged PR #339.
Previous-work housekeeping found main synchronized and no completed previous
local issue branch to delete. A final read-only PR/ref check found no PR for this
branch and `main...origin/main` at `0 0`. Main remains unchanged.

## Result and shared-code boundary

Ordinary Video Export always writes a visual version-1 job. Selection count,
highlight visibility and Analysis results never choose its schema, source
binding, dependencies, preparation, quota or inspection-record policy. The
selection-aware gate, recipe creation/wait, scientific membership queries,
mandatory v3 sidecars, G4 quota field and corresponding preparation/cancellation
state were removed from this route. The existing Advanced checkbox is always
available, unchecked by default, and writes ordinary visual/sample records only
when explicitly requested. Video still uses external FFmpeg.

The earlier marker implementation and its dedicated validator/tests were removed
entirely. Video jobs carry no resolved marker subset, selection definitions,
ROIs, groups, results or analysis plots. The ordinary render instance disables
its empty Selection controller's processing and clears/hides its overlay. This
occurs only in the secondary ordinary-video process. The interactive application
keeps its Selection highlights, definitions, Analysis plots/results and scientific
persistence; no interactive feature was removed or disabled.

Normal particle/mesh/field visualization, camera/orbit, timeline sampling,
ordinary legends and established presentation settings retain their contracts.
Application panels and scientific overlays cannot enter the ordinary export.
The owner's rationale is that Selection/Analysis have not completed end-to-end
scientific validation; ordinary MP4 output must not imply their overlays are
verified scientific information. Passing these checks establishes this software
boundary, not scientific acceptance of those independent features.

The shared-code audit retained `inspection_v3.gd`, durable inspection/results,
the scientific job protocol and packaged first-party Python archive. They serve
independent scientific tools. Explicit Tools → Matched Views remains a separate
scientific workflow using version-2 recipe jobs and its existing scientific
rendering/provenance; it is not invoked by File → Export → Video. Shared worker
and version-2 validation were not deleted, and its regression was rerun. Close
File and Jobs now use launched-worker ownership instead of the removed video
recipe-preparation state; independent Analysis remains visible while video runs.

## Focused validation of the revised candidate

Godot **4.7.2.stable.official.ed1daf0bf**, Linux, the same workstation as the
historical checkpoint. All captures are tiny generated WVZ1 fixtures. Reports
are copied without editing their contents. No research simulation was rerun.

| Check | Exact result and evidence |
| --- | --- |
| Source Forward+ video matrix | **601 checks, 0 failures**, [report](source-forward.json) |
| Source Compatibility video matrix | **601 checks, 0 failures**, [report](source-compatibility.json) |
| Release Forward+ matrix / source comparison | **668 checks, 0 failures**, [report](release-forward.json) |
| Release Compatibility matrix / source comparison | **668 checks, 0 failures**, [report](release-compatibility.json) |
| Initial focused revised Compatibility matrix | **265 checks, 0 failures**, [report](focused-compatibility.json) |
| Independent Selection | **31 checks, 0 failures**, [report](selection.json) |
| Explicit independent Matched Views | **50 checks PASS**, [report](matched.json) |
| Close File / live exports / numerical output | **225 checks PASS**, [report](close-file.json) |
| Production export dialog / grouped controls | **52 checks, 0 failures**, [log](dialog.log) |
| Version / scientific recipes / matched-render Python tests | **17 tests OK**, [log](python.log) |
| Final native import / three modified Python tools / whitespace | No script or engine errors in [import](import.log); Python compilation and source/documentation whitespace checks pass (retained raw logs excluded) |

The video matrices exercise the production menu, dialog, Jobs and render child.
Independent scientific workers first create visible particle/mesh/field/combined
selections. The tests assert that interactive highlights are actually drawn.
Another case creates a real Analysis result and populated plot, then opens its
Temporal panel. Only after that setup, scientific workers are shut down, controller
ticking is frozen in the test parent, and a failing `python3` wrapper is placed
on PATH. Any attempted Python invocation writes a failure sentinel. No video
case invokes it or creates recipe assets. Parent scientific state and overlay
visibility remain unchanged after export.

Decoded H.264 frames from visible/hidden particle selections, mesh selections,
field selections, combined selections and the populated Analysis case are
**byte-identical to their equivalent zero-selection ordinary export**. Their
camera/sample/timing traces are identical, with no carried marker field. Checked
optional records also match the ordinary case exactly. Ordinary legends remain
functional: legends off/on change pixels, and camera orbit remains exercised.
All completed release clips match their source counterpart in decoded pixels
and camera/sample/timing. FFprobe confirms H.264, 320×180, 4 FPS and two frames.

The matrices also cover rendering/encoding cancellation, Run in background,
Jobs reopening, missing/failing FFmpeg, parent Exit cancellation, success PNG
cleanup, failed/cancelled retention and missing-PCK startup refusal. No partial
final MP4 is published. Close File control/closed videos, timing and optional
records match; its independently checked numerical CSV remains byte-identical.
Source hashes remain unchanged throughout. The independent Matched Views test
checks membership, provenance/image hashes and aligned physical pixels.

Release tests remove their staging project before execution, run from an
unrelated directory containing another project, exclude the external Godot editor
from PATH and clear PYTHONPATH. Only the test parent entry is instrumented;
children dispatch through production Main in the release executable/PCK. The
first-party scientific archive is retained for independent tools/setup and is
not an ordinary-video dependency.

A separate package with the normal production entry is available locally at
`/home/Nozba/Codex/Wavez/video-340-review-revised/`. Keep its executable/PCK together.
Its [build identity and hashes](review-package-build.json) identify v0.1.0.93.
The earlier `/home/Nozba/Codex/Wavez/video-340-review/` package is superseded.
[Actual Advanced with active selections](advanced-with-selections.png) and
[compact dialog](dialog-compact.png) were visually inspected; records remain
unchecked and no selection quota/control is present.

## Failures, limitations and historical preservation

A first sandboxed editor import reported socket/editor-settings permission errors:
[original log](initial-import-sandbox.log). Repeating the same import with normal
native access completed cleanly; no source repair was required.

The inherited video harness preserves the killed-encoder PID cleanup diagnostic.
Each full matrix contains four occurrences across parent/worker log copies. Only
that exact expected pattern and the deliberately withheld-PCK startup error are
allowed; other errors/warnings fail the checks. These reports do not claim that
intentional failure-path logs are empty.

Earlier connected Jobs/status testing remains evidence for the unchanged status
implementation: [candidate](superseded-marker-direction/status-candidate.json)
has 322 checks with two focus failures, and [accepted main](superseded-marker-direction/status-accepted-main.json)
has 324 with the same two failures, `Opening Jobs focuses the first available
action`. This standalone focus suite was not repeated after the marker removal;
the revised video matrices exercise actual Jobs reopening/cancellation. Owner
physical focus verification is still recommended. The prior marker-only
Compatibility teardown failure belongs to the removed harness, not a passing
current-candidate check; its original reports remain retained.

Other operating systems/hardware, physical desktop input, mixed DPI/4K, long
research clips and machine-wide removal of Python/Godot remain untested. PATH
blocking and staging removal prove the stated process boundaries, not physical
uninstallation. No new claim is made for optional isosurface extraction or its
external dependencies. Unrelated playback/cache/camera/core suites were not
rerun because their implementations did not change. The actual changed video
and shared worker boundaries, independent science and numerical persistence
were validated above. Full scientific end-to-end validation remains outside
this issue and incomplete.

The complete earlier local checkpoint `8192a00`, including all 26 original
artifact hashes, is retained under [superseded marker direction](superseded-marker-direction/CONTEXT.md).
Its original README/reports were preserved byte-for-byte, including two trailing
spaces in raw status logs that a whole-branch whitespace check reports. Source
and documentation diffs pass with raw logs excluded. The earlier artifacts describe the
previous requirements and are not evidence for the revised candidate. All
pre-existing historical issue evidence and review-time acceptance wording were
preserved. Current video/package/onboarding/scientific-schema/Close File guides
and status now describe the exclusion boundary.

## Reproduction and exact owner verification

Use fresh directories for every command, from the repository root:

```sh
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/review-source --renderer forward_plus
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/review-release --renderer forward_plus --export \
  --compare-source /tmp/review-source
```

Repeat with `gl_compatibility` and fresh paths. Independent scientific checks
are documented in [the package guide](../../PACKAGED_VIDEO_EXPORT.md).

1. Launch `/home/Nozba/Codex/Wavez/video-340-review-revised/WAVEZ.x86_64` from an
   unrelated directory. Check Help → About is v0.1.0.93; configure external
   FFmpeg in File Locations if needed.
2. Open a capture, choose File → Export → Video and a short fixed range, locked
   camera, Current state, fixed size/FPS/rate and fresh MP4 path. Leave Advanced
   records unchecked. Check particle/mesh/field rendering, camera, timing and
   legends in the resulting clip.
3. With Python/NumPy available, create visible particle, mesh and field selections
   in Tools → Selection, including a combined selection set. Run Temporal
   Analysis → Population counts over the recorded interval and display its plot.
   Export again to a new filename with exactly the same ordinary presentation
   settings. The clip must match the baseline, contain no highlights/Analysis
   overlays, start no video-related scientific work and generate no recipe or
   mandatory JSON. Interactive highlights/results must remain available.
4. Toggle Include enabled viewport legends: ordinary legends must follow this
   option, while Selection/Analysis overlays remain excluded in both states.
   Explicitly check Advanced → Save per-frame inspection JSON and repeat: only
   then should ordinary visual records appear, with no scientific results.
5. Confirm independent Selection, Analysis, numerical CSV export and scientific
   inspection save/restore still work with their dependencies available. Explicit
   Matched Views remains its separate scientific tool.
6. Background a longer small-fixture export, reopen through Jobs, Close File
   while it runs, and cancel via the confirmation. Check no partial final MP4.
   Repeat during encoding, with failing FFmpeg, and through confirmed parent Exit.
7. Physically verify Jobs focus and realistic clips on the owner's desktop before
   acceptance. No push, PR creation, merge or publication follows without the
   owner's next instruction.

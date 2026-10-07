# Issue #93 — packaged video export

Candidate **v0.1.0.67**, pending owner review. Accepted baseline:
`56b3caa5ba2926d451259dcb866152ceb144a8e3`. Work used the existing linked branch
`93-release-export-001-make-video-export-work-from-packaged-wavez-builds`.
#93 was first in Ready; predecessor #116 was owner-merged in PR #122 and present
in this baseline. The preceding PR #280 was merged; local `main` and origin/main
were synchronized, stale references pruned, and no completed local issue branch
remained to remove. Historical evidence was preserved.

## Reproduced failures

[Launch reproduction](baseline-launch.json) and [engine refusal](baseline-path-refusal.txt)
show the unmodified release executable rejecting `--path`, exiting 1 before
creating progress or renderer diagnostics. The development engine completed the
same two-frame particle job. The fix selects project-path arguments only for
editor-feature engines, preserving the existing second-process architecture.

After removing that argument only in the baseline probe, a version-2 job still
failed: [selection reproduction](baseline-selection.json) and
[stderr](baseline-selection.txt) show Python trying to open
`../tools/analyze_selection.py` next to the package. The release build now packs
canonical first-party Python and colormaps into its PCK and materializes the
worker code into private user data. No third-party runtime or encoder was added
to the repository. Parent and child selection workers used the package archive.

## Final validation

Godot **4.7.2 stable**, Linux native GPU, NVIDIA RTX 3070 Ti. Tests ran outside the
repository from an unrelated working directory containing a decoy project.
Build staging was removed before runtime tests. Runtime PATH contained only
`/usr/bin:/bin`, without Godot; PYTHONPATH was empty. Tests use synthetic WVZ1
captures, external Python/NumPy, installed FFmpeg and ffprobe.

| Environment | Cases | Checks | Failures |
| --- | ---: | ---: | ---: |
| [Development Forward+](final-source-forward.json) | 10 | 224 | 0 |
| [Development Compatibility](final-source-compatibility-corrected.json) | 10 | 224 | 0 |
| [Release Forward+](final-release-forward.json) | 11 | 264 | 0 |
| [Release Compatibility](final-release-compatibility.json) | 11 | 264 | 0 |
| [Ordinary, uninstrumented release](ordinary-release.json) | 2 startups + 4 workers | 28 | 0 |

The matrices cover the real File → Export → Video dialog, secondary executable,
compiled PCK resources, renderer propagation, particle and mixed particle/field/
mesh exports, legends off/on, orbit, selection-aware version-2 jobs, background,
Jobs reopening, render cancellation, encoding-stage cancellation, failed/missing
encoder, parent shutdown, and early child-startup failure. FFprobe confirms
H.264, 320×180, 4 FPS and two frames for every short successful clip.

All five successful clips per renderer match development decoded RGB pixels and
exact timing/source-sample/camera traces. Input hashes are unchanged. Version-2
inspection records retain the exact persistent ID `10` in all eight audited
frames; the [summary](summary.json) records that audit. Runtime-extracted Python
sources are removed on shutdown. The same package source is used by both parent
and child; neither depends on development imports or files beside the repository.

The release test entry changes only the parent automation route; child invocations
load the production Main scene. An additional [ordinary build](ordinary-build.json)
uses the unmodified Main scene: direct startup passed on both renderers, and
particle, mixed, selection-aware and missing-FFmpeg worker cases passed on
Compatibility. Successful ordinary-package pixels/timing also match development.
The missing-FFmpeg direct worker retained both PNGs and encoding instructions in
`frames_ready`, while the production dialog's missing-FFmpeg case refused launch
with the existing File Locations guidance.

Commands for the four matrices, from the repository root:

```sh
python tools/validate_packaged_video.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-93/final-source-forward --renderer forward_plus
python tools/validate_packaged_video.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-93/final-source-compatibility-corrected --renderer gl_compatibility
python tools/validate_packaged_video.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-93/final-release-forward --renderer forward_plus --export --compare-source /tmp/wavez-issue-93/final-source-forward
python tools/validate_packaged_video.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-93/final-release-compatibility --renderer gl_compatibility --export --compare-source /tmp/wavez-issue-93/final-source-compatibility-corrected
python tools/package_linux.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-93/review-package
python -m unittest tests.test_application_version
```

The application-version suite passed **2 tests**. `git diff --check` passed.
Final isolated imports and release exports completed without engine errors.
The first source import recreated five unrelated missing UID files from the
existing cache; these generated sidecars were removed from the change. New
script UIDs are retained with their source. An initial sandbox baseline build
produced socket/editor-settings permission errors and was not counted as a clean
build; final packages were built with native access and isolated editor settings.

This is a subsystem and package-resource change. Validation covers export,
selection/recipe worker boundaries, renderer resources, process lifecycle and
application identity. Unrelated camera input, playback/cache, field throughput
and full scientific suites were not run; no reader/writer or scientific state
implementation changed.

## Diagnostic classification and corrected harness attempts

Accepted-main release cancellation reproduced the existing duplicate encoder-PID
cleanup diagnostic, retained in [baseline stderr](baseline-encoder-cleanup.txt).
Each final cancellation logs two occurrences, also duplicated in the captured
parent stream and renderer log. The validator matches only the terminal encoder
PID and the known engine message/backtrace. These are documented pre-existing
diagnostics, not a claim of clean engine logs. Every other unexpected error or
warning fails validation.

Earlier focused attempts under `/tmp/wavez-issue-93/` exposed harness issues:
`release-forward` initially rejected the release form of that diagnostic, which
omits the source-build backtrace. `source-compatibility` and
`final-source-compatibility` missed a short encoding stage or reached cancellation
after publication. The final fixture uses a controlled three-second encoder
startup stall, retaining real FFmpeg for version checks and eventual encoding;
normal successful jobs use the real encoder directly. The corrected focused
encoding checks and the final complete matrices above passed.

The initial missing-PCK startup probe triggered Godot's native alert and kept the
child alive. Withholding the parent's PCK too long also broke its later resource
loads in `release-failure-recheck`. Final startup tests restore the parent's pack
immediately after the child emits the expected refusal, dismiss only that test
child's native alert, and verify the parent's unexpected-exit status plus retained
`job.json` and `launch.json`. The test-owned processes from unsuccessful attempts
were cleaned up. Earlier logs remain outside the repository; they are not counted
as passing candidate runs.

## Limits and owner checks

No Windows/macOS package, public distribution/licensing audit, machine with the
Godot editor physically uninstalled, long production capture, 1080p/4K workload,
or physical desktop-input session was tested. The editor was installed on this
host but absent from runtime PATH and never invoked by the release parent/child.
No new release/tag or dependency vendoring is included. Python/NumPy and FFmpeg
remain intentional external dependencies; ordinary video does not use Python.

Exact manual acceptance steps are in
[the current packaged-video guide](../../PACKAGED_VIDEO_EXPORT.md#validation-and-owner-checks).
Build outside the checkout, launch directly, export particle and mixed content
with legends off/on, export an exact-ID selection, exercise background/Jobs and
both cancellation stages, confirm parent exit cancellation, and review retained
launch/worker/encoder diagnostics. The owner controls acceptance and merge.

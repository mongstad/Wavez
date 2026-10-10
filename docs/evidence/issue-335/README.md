# Issue #335 — Linux release Popup signal investigation

Candidate **v0.1.0.90**, based on accepted main
`8a411646cf30441233a681af9ecb4ca325724d91` / owner-merged PR #334. #335 was the
only Ready item; its exact owner-linked branch was already checked out, clean
and equal to local/remote main. The predecessor merge was verified, references
pruned, and the completed #329 branch was already absent. No branch was created
or switched. Owner review of this investigation remains pending.

## Finding and boundary

The installed official Godot 4.7.2 `ed1daf0bf` Linux x86_64 **release template**
retains the native Popup-owned root `focus_entered` / `tree_exited` callbacks after
hide. Source and debug runtimes remove them. This independently reproduces with
only a PopupPanel and PopupMenu, and with the production Main scene exiting
through ordinary chrome request (without manually freeing the viewer).

This is an external runtime cleanup defect, reproducible before shutdown and
without Wavez/Close File. No Wavez runtime fix or broad focus refactor is justified
by these results. The issue delivers a reproducible diagnostic tool/probe,
classification and remediation boundary. Release packaging remains release;
errors remain visible and strict validators still fail. The exact compiler/hash
comparison mechanism and any corrected engine build are unverified.

See [ownership, upstream sources, reproduction and owner checks](../../ROOT_WINDOW_SIGNALS.md).
Only the application build changes in production configuration; main, shell,
selection and exporter runtime source remain unchanged. `provenance.json` records
the branch, baselines and unchanged source hashes. Current guides are updated
within #335; every historical #329 report/log remains unchanged.

## Matched results

Godot 4.7.2, Linux, NVIDIA RTX 3070 Ti; logical resolution 1440×900. Fresh isolated
profiles, tiny generated WVZ1 sources, externally installed Godot/templates,
Python/NumPy and FFmpeg. All functional checks have zero failures and all Godot
processes exit 0. The strict result additionally requires zero errors/warnings.

| Runner / baseline | Renderer | Functional checks | Native errors | Strict exit |
| --- | --- | ---: | ---: | ---: |
| Standalone Popup source | Forward+ | 18 | 0 | 0 |
| Standalone Popup debug template | Forward+ | 18 | 0 | 0 |
| Standalone Popup release | Forward+ / Compatibility | 18 each | 32 each | 1 each |
| Production Main workflow source | Forward+ / Compatibility | 21 each | 0 each | 0 each |
| Production Main workflow release | Forward+ / Compatibility | 21 each | 8 each | 1 each |
| Pre-Close-File main `e41ae56d`, four-export smoke release | Forward+ | 11 | 2 | 1 |
| Accepted main `8a41164`, same smoke release | Forward+ | 11 | 2 | 1 |
| Accepted main `8a41164`, same smoke source | Forward+ | 11 | 0 | 0 |
| Accepted main `8a41164`, exact #329 release harness | Forward+ | 229 | 32 | 1 |
| Accepted main `8a41164`, exact #329 source harness | Forward+ | 229 | 0 | 0 |
| Candidate, unchanged exact #329 source harness | Forward+ / Compatibility | 229 each | 0 each | 0 each |
| Candidate, unchanged exact #329 release harness | Forward+ / Compatibility | 229 each | 32 each | 1 each |

No release row is a clean validation pass. Every native error in these final
runs is classified; there are no unclassified native errors, warnings or script
errors. Exact per-signal counts, raw messages, snapshots, outputs and package
hashes are retained in `summary.json` and each `*-validation.json` / `*-native.log`.
The pre-Close-File archive's recorded production bytes were compared to the
`e41ae56d` Git objects before using it. Accepted main was independently archived
from `8a41164`; identical runner/settings/interaction sequences were used for
matching comparisons. The diagnostic probe is copied into each temporary stage;
no baseline checkout is edited.

## Why two versus 32

- Each first Popup hide emits one nonexistent-disconnect error per signal.
- Each subsequent show emits one duplicate-connect error per signal; hiding emits
  another nonexistent-disconnect pair. Hidden release snapshots retain **one**
  slot per signal, whereas source/debug hidden snapshots retain **zero**.
- Four-export baseline smoke shows/hides File once: 2 errors. It does not open
  Seek. Videos and Jobs use Window/AcceptDialog, not this visible Popup sequence.
- The #329 harness shows/hides TimeSeekPopover eight times across source cycles:
  16 disconnect + 14 duplicate-connect errors = 30. File once adds 2 disconnect
  errors. Total: **18 disconnect + 14 duplicate-connect = 32**.
- The standalone probe repeats exactly eight PopupPanel cycles and one PopupMenu
  cycle, reproducing the same counts without any Wavez resources.
- The production workflow uses Seek twice and File once: 6 disconnect +
  2 duplicate-connect = 8 errors, before ordinary Exit. Close File dismisses Seek
  through its existing hide path; independently hiding a standalone Popup also
  triggers the defect.

`instrumented-exact.log` identifies the remaining hidden TimeSeekPopover and File
PopupMenu targets after the original checks, then records zero Popup callbacks
and zero orphan nodes after manual viewer free. The temporary instrumentation is
specified in `instrumentation.json`; the unmodified harness comparisons are
separate. No native signal slots were manually disconnected or repaired.

The old exact validator saves stdout followed by stderr, making messages appear
after its completion print. That is not causal evidence of shutdown timing.
The new probe merges both streams under Linux `stdbuf` line buffering and prints
state beside each action; its raw log shows errors during hide/reopen.

## Functional regression and scope

The unchanged exact harness checks capture opens/closes across particles, fields,
meshes and mixed independent clocks; paused/playing, editor dismissal, dependency
refusals, preference retention, memory-owner disposal, and empty/reopen behavior.
All input SHA-256 hashes remain unchanged. On each candidate native renderer and
release template it independently verifies:

- ordinary and selection-aware control/closed MP4 decoded frames and timestamps
  identical with FFmpeg `framemd5`;
- byte-identical timing traces and six matching inspection sidecars per pair,
  normalizing only independently regenerated selection identity strings;
- byte-identical numerical values after a refused Close File request, with no
  unwanted cancellation;
- live background PID/job retention, Jobs reopening, a different capture opening
  while the original export continues, and explicit cancellation acknowledged
  through the job's own confirmation after Close File;
- reader handle/cache/index cleared, particle buffers empty, capture layer and
  preparation-worker weak references expired.

The production-scene probe independently verifies normal Main/Exit, the live
background/Jobs/source-change route and the same reclamation eligibility without
manual viewer teardown. It reports zero orphan nodes before Exit. Accepted-main
and candidate Forward+ exact video comparison records also match across runs.

Application version unit tests: **2 passed**. Python compilation and
`git diff --check` pass. Warmed Godot import is clean and the new script UID is
retained. The first sandboxed import logged local socket restrictions plus four
pre-existing missing resize-script UID warnings; the authorized warmed import
resolved them. Incidental generated resize UIDs were removed. Two temporary
instrumentation indentation errors were corrected before its successful run;
they were probe development mistakes, not production findings. An initial exact
source run from a fresh Git archive lacked Godot's script-class import cache and
failed during startup; it was stopped, imported and rerun in a fresh output
directory. Its startup log is retained separately from the final comparison.

Validation focuses on native Popup ownership plus the directly connected
Close File/Jobs/export boundaries. No source reader/writer, playback algorithm,
camera navigation, rendering architecture or scientific format changes occur;
unrelated full suites and production scientific simulations were not run.

Unverified: actual physical input/display, Windows/macOS, large/long captures,
exact OS RSS/VRAM return, long image/matched-work races, alternative engine builds,
compiler bisect and long-session focus effects. Eligibility for reclamation is
verified; an exact immediate whole-process memory drop is not promised. The
upstream report corroborates the runtime class but does not prove another engine
passes here. No passing functional check implies owner acceptance.

## Reproduce and review

Run the [documented probe commands](../../ROOT_WINDOW_SIGNALS.md#reproduction)
using fresh output directories. For the full unchanged matrix:

```sh
python tools/validate_close_file.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /tmp/close-source
python tools/validate_close_file.py --godot /absolute/path/to/godot \
  --renderer forward_plus --package --output-dir /tmp/close-release
```

Repeat with Compatibility. Archive either accepted baseline into an external
folder and pass it as `--source-root` to the probe for matching smoke routes.
Import a fresh source archive first with `godot --headless --editor --import
--path /absolute/archive/viewer`. For the accepted #329 exact harness, execute the archived
`tools/validate_close_file.py` itself so its ROOT resolves to that archive.
Generated captures, videos, stages, binaries/PCKs and third-party engine sources
remain external; retained files are only compact first-party evidence. Package
hashes identify temporary test binaries, not distribution approval.

Follow the exact [owner checks](../../ROOT_WINDOW_SIGNALS.md#owner-checks-and-remediation-boundary).
A corrected external release template, validated with the minimal and focused
workflow/export matrix, is the narrow remediation proposal. It is not installed,
vendored or claimed fixed by this PR. One PR targets main; no merge/auto-merge,
manual issue closure or Project transition is performed.

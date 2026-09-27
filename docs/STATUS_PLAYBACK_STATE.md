# Unified playback/preparation status — #114

2026-09-27 implementation; **pending owner review**.

Issue #114, UX-STATUS-002, was the only Ready item in SimScope Development.
The exact owner-created linked branch is
`114-ux-status-002-simplify-status-bar-preparation-and-playback-state`.
It began clean at accepted main `2c3678ab6725b1bb3dec0a9466e5dfcd51e9810f`
(PR #127). Current adaptive preparation (#111 / PR #113) and other accepted
predecessors were already present. Remote references were pruned; the completed
local #115 branch was already absent. No implementation branch was created or
switched.

## Behavior and boundaries

The bottom bar previously combined a generic Ready/Preparing badge with a
separate Preparing ahead n/x or interval field counter. It now composes one
playback/preparation message, retaining existing failure notices and Jobs.

| User-visible condition | Message |
|---|---|
| No source | No capture |
| Opening source | Preparing… |
| Paused, required sample or Automatic startup coverage missing | Preparing… |
| Paused with sufficient coverage | Ready |
| Playback advancing, including successful background preparation | Playing |
| Playback blocked waiting for data | Buffering / Preparing… |
| Non-looping recording boundary, no pending sample | Ready |
| Current source/layer failure | Unavailable, with existing diagnostics |

Readiness uses existing buffering flags, playback direction/loop/range and the
same read-only Automatic coverage calculation and concurrency gate used by Play.
It does not call the mutating startup gate, request work, stage textures or change
playback intent. In particular, reaching the endpoint changes only the status
presentation even where the existing transport retains playing intent. Background
worker activity alone never replaces Playing or adds an adjacent progress count.
Paused readiness distinguishes a committed sample from sufficient startup coverage.

Automatic mode has **no percentage**: its RAM-admitted window and measured useful
lead are adaptive. An explicit selected/from-current preparation interval shows
`Preparing — N%` or `Buffering / Preparing — N%` only while that session is waiting
and its preparation total is known. N is floor(100 × prepared field samples /
field samples in that requested interval), bounded to 0–100. It is not elapsed
time, bytes, the whole capture, or a guarantee that all particle/GPU work has
finished. Planning and unknown totals remain indeterminate. Details explains this
scope and retains detailed memory/cache diagnostics. Retained failure notices still
require explicit acknowledgement.

Runtime changes are confined to `viewer_status.gd`. Preparation algorithms, RAM
admission, worker scaling, playback timing, scientific data and SIMSCP4 are unchanged.
The status refresh remains bounded to five per second and stores no new readiness
history that could leak across seeks or source replacement.

## Validation

Godot 4.7.2 on NVIDIA GeForce RTX 3070 Ti, Forward+ and Compatibility, with small
generated current SIMSCP4 captures. The focused status harness exercises native
viewer state plus real export/selection worker lifecycles.

- **196 checks PASS per renderer** in the final suite.
- Final headless editor import and whitespace checks pass; no new scripts or UID sidecars are required.
- Real preparation barrier checks cold seek, paused Preparing, active Buffering
  and recovery. Warm seeks, Play/Pause, reverse, loop and exact recording-end
  states are exercised, along with density / psi_real / psi_imag replacement.
- Controlled presentation snapshots check background preparation while Playing,
  exact 25% explicit-interval text and indeterminate planning. The no-source
  reset is also a presentation injection, not a new close-file feature.
- Actual missing-file load failure followed by valid-source recovery preserves
  retained failure details and clears stale preparation state.
- Existing jobs, cancellation, exports, parent teardown and layout checks pass;
  parent-close workers acknowledge cancellation on both renderers.
- 1,000 status refreshes trigger no scientific profile activity and preserve
  visual state and committed clock. The 1,000-refresh loop takes 47.932 ms on
  Forward+ and 51.688 ms on Compatibility for these fixtures. Source SHA-256
  hashes are unchanged.

Commands (use a fresh output directory each time):

```sh
python tools/validate_viewer_status.py --godot GODOT --output-dir OUTPUT --renderer forward_plus
python tools/validate_viewer_status.py --godot GODOT --output-dir OUTPUT --renderer gl_compatibility
```

Compact reports are in [evidence/issue-114](evidence/issue-114/). Full local logs,
fixtures and exports remain outside Git in
`/home/Nozba/Codex/SIMSCOPE/status-114/`.

Initial development checks exposed the former test assumption that sample-ready
meant startup-ready, and a memory diagnostic that needed explicit inclusion in
Details. Those were corrected. The first expanded test used decimal 1.9 instead
of the fixture's exact final timestamp and sampled the loop status before its
pending upload settled; corrected boundary checks pass. No final failures remain.

Production-capture performance, every memory-pressure condition, other operating
systems and the full scientific suite were not rerun for this presentation-only
change. Automatic progress intentionally remains indeterminate. Fixture timing is
not production performance evidence. Historical status and prior issue review-time
reports are unchanged; the handbook/current-status page describes current behavior.

## Owner verification

1. Open the production capture paused. Confirm a single Preparing message becomes
   Ready when startup coverage is sufficient, without an adjacent ahead counter.
2. Play and pause; confirm Playing persists while preparation keeps up. Seek beyond
   coverage and confirm Preparing while paused or Buffering / Preparing while active,
   then recovery. Check reverse and loop, and the recording endpoint without loop.
3. Switch density, psi_real and psi_imag; confirm no old status remains after each
   replacement becomes ready. Repeat with a different capture and a failed open.
4. In Performance, request an advanced preparation interval. Inspect the percentage
   and Details explanation; Automatic should never show a whole-capture percentage.
5. Hide/show the panel and inspect Jobs/failure details; existing actions must remain
   available. Stop at owner review; no merge or auto-merge is authorized.

## Owner-review correction: observe transport progression

This correction supersedes the initial active-playback status semantics above.
`layers.is_buffering()` combines particle, field and mesh controller flags; it can
be true during transient staging or preparation even while committed playback
continues. Using that aggregate directly caused intermittent visible Buffering.

The scene transport now records when an existing pump returns without advancing
because content is pending, or sampling returns pending and holds the clock.
It observes the committed clock before/after each tick. Any clock change (including
reverse and loop wrap), successful unblocked tick or paused tick clears the hold.
Seeking resets the observation, and a new scene starts with fresh observation.
No pump order, sample request, cache, worker, playback gate or timing changes.

The status uses this observation for active playback, not `is_buffering()`. A
continuous content wait without committed-clock progress must last **400 ms**
before the caption becomes **Buffering**. With the existing 200 ms refresh cadence,
this is normally visible after 400–600 ms. Short staging/upload waits deliberately
stay Playing. Recovery clears the hold immediately and the next refresh returns
directly to Playing. Active captions never use combined Buffering / Preparing
wording or append a percentage; preparation details remain in Details/tooltip.
Paused readiness retains its existing required-sample/startup-coverage semantics.
Endpoints now require both requested and committed clocks to reach the boundary,
so merely requesting an endpoint does not prematurely show Ready. A paused
endpoint with a missing replacement sample still shows Preparing.

The expanded regression deliberately fluctuates preparation/staging flags across
24 real transport ticks over more than 400 ms, requires repeated committed-clock
advances, and checks Playing after every tick. Real worker barriers also verify
particle, field and mesh stalls, a cold seek, exhausted field runway without a
seek, unchanged committed clocks during holds, and direct recovery to Playing.
These are deterministic fixtures and controlled pressure, not a claim to reproduce
every scheduling pattern of the production capture.

The final status/lifecycle suite passes **231 checks per renderer**, Forward+ and
Compatibility, with unchanged source hashes and parent-close cancellation
acknowledgement. Existing presentation/Jobs/export tests remain included. Compact
reports are retained separately under
[evidence/issue-114/transport-review](evidence/issue-114/transport-review/), preserving
the initial review-time evidence. No final failures; production-scale timing and
other operating systems were not rerun.

Owner check: run the production capture through normal playback and confirm
Playing stays stable during background preparation. Force a cold seek or exhaust
prepared coverage: only a sustained hold should show Buffering, with immediate
return to Playing at the next refresh after recovery. Recheck Pause/Ready,
reverse/loop and the non-looping endpoint. This remains #114 / PR #129, pending
owner review; do not merge automatically.

# Media-style playback timing — issue #49

Implemented, **pending owner review**. #49 was the sole Ready item. The exact
owner-created linked branch `49-ux3-transport-002-media-style-playback-timing`
started clean at accepted `main` `1976adc` (owner-merged PR #48). The previous
local issue branch was already absent; its stale remote ref was pruned.
No acceptance-only PR or historical evidence rewrite was made.

## Presentation contract

The union-index slider now has elapsed playback time on its left and a directly
clickable total/remaining duration on its right. Duration values show one decimal;
remaining uses a leading minus, with `0.0` at the end (never `-0.0`). The toggle
is a session-only preference, not scientific recipe state. The transport retains
64/104 logical-pixel normal/compact heights and its existing Seek, Loop,
previous/next, and Jobs controls.

These are **nominal playback seconds at 1×**, not measured wall time or a claim
about scientific units. Speed changes and buffering do not change the total.
Source growth can change the interval/duration. Elapsed follows
only committed visible source time, never a pending seek or an unsubmitted draft.
Exact displayed source time and its declared unit remain in the elapsed tooltip;
Seek Target, layer/source diagnostics, persisted state and calculations stay exact.
The differing Requested target still appears with five decimal places and an
exact tooltip. During a pending request it occupies the secondary explanation
area. The sample index is available on slider hover and in a floating hint while dragging, without a persistent index caption.

The slider still selects the sorted union of recorded samples. Its equally spaced
indices do not represent equal source-time intervals. Sparse volume Hold,
particle/mesh interpolation and source timestamps are untouched.

## Relative speed and duration mapping

Recorded-time playback is the single canonical behavior. There is no playback-mode
selector, hidden selector, index-rate controller branch or mode-switch state.
**Playback speed ×** maps directly to the existing recorded-time rate: 1× advances
one recorded unit per playback second, 0.5× halves progression and 2× doubles it.
Negative speed reverses; zero holds. Exact numeric draft/commit behavior remains.

Total is `last - first`; elapsed is `committed - first`, clamped to the interval;
remaining is `max(0, total - elapsed)`. Empty captures display dashes; a single
sample has zero duration. No source reads, hashes or decoding occur on refresh.

Sample indices remain for union ordering, slider positioning, Previous/Next,
index/count hover and drag hints, exact lookup and existing buffering/caches.
They do not select a second playback clock. Interpolation and Hold policies are
unchanged. `phase` still describes interpolation within a recorded interval.

Recipes contain the exact signed `physical_rate`, including zero, but no
`time_mode`, `playback_fps` or old index-rate slider. Obsolete mode-bearing recipes
are rejected by visual-state validation; no migration or compatibility aliases
are provided. Unrelated recipe contracts remain unchanged. Video export retains
its deterministic forward-only timing; its initial rate uses positive playback
speed or 1× for zero/reverse speed, with an independent export-rate editor.

This is independent of render FPS, export FPS, solver timestep and field cadence.
A declared source unit such as milliseconds remains a scientific unit; it does
not silently change the existing one-recorded-unit-per-playback-second baseline.

## Validation and scope

[Refinement evidence](evidence/issue-49/single-playback/README.md) records native runs, regression
coverage, limitations and development failures. The owner refinement removes the obsolete selectable-clock code and recipe
fields and makes existing recorded-time advancement unconditional. Renderers,
source formats, interpolation/Hold and deterministic video sampling are unchanged.
Earlier review evidence remains historical. No #44/#46/#50 or UX4 work is claimed.

## Owner verification

1. Launch standalone with a normal capture at 1440×900 and 1024×640. Check elapsed
   left / total right; click the right value for negative remaining and back. Hover
   and drag the slider: sample index/count should appear only as a tooltip/hint.
2. Seek to the beginning and end: elapsed should show `0.0`, then equal total;
   remaining should end at `0.0`. Hover elapsed and verify exact source time/unit.
3. Confirm no playback-mode selector exists. Test 0.5×, 1×, 2×, zero and a negative
   speed. Progress should scale, reverse should work, and total should stay stable.
   Save/reload a new recipe and confirm its signed speed survives without a seek.
4. Cold-seek and rapidly replace targets. Elapsed/remaining must stay at the old
   committed position during preparation and then reflect only the latest commit.
5. Step/drag through irregular samples and a sparse volume: union indices and
   field Hold must remain unchanged. Test Loop, exact Seek and a saved recipe.
6. Hide the dock and enter/exit interactive fullscreen. Transport and mouse
   recovery must remain accessible. Review readability at your desktop scale.

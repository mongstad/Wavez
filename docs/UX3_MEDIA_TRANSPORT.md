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
64/104 logical-pixel normal/compact heights and its existing mode, Seek, Loop,
previous/next, and Jobs controls.

These are **nominal playback seconds at 1×**, not measured wall time or a claim
about scientific units. Speed changes and buffering do not change the total.
Source growth or switching modes can change the interval/duration. Elapsed follows
only committed visible source time, never a pending seek or an unsubmitted draft.
Exact displayed source time and its declared unit remain in the elapsed tooltip;
Seek Target, layer/source diagnostics, persisted state and calculations stay exact.
The differing Requested target still appears with five decimal places and an
exact tooltip. During a pending request it occupies the secondary explanation
area; The sample index is available on slider hover and in a floating hint while dragging, without a persistent index caption.

The slider still selects the sorted union of recorded samples. Its equally spaced
indices do not represent equal source-time intervals. Sparse volume Hold,
particle/mesh interpolation and source timestamps are untouched.

## Relative speed and duration mapping

The UI converts multipliers against the existing controller defaults, never
redefines those controllers or coerces their stored rate values:

| Mode | 1× baseline | Nominal total | Nominal elapsed |
|---|---|---|---|
| Sample index | 12 union samples per playback second | `(N - 1) / 12` | Committed fractional union index divided by 12 |
| Recorded time | 1 recorded unit per playback second | `(last - first) / 1` | `(committed - first) / 1` |

`N` is the number of loaded union samples. In index mode the fractional index is
located by binary search on the already loaded timestamps, using the committed
clock within that interval. No source reads, hashes or decoding occur. Empty
captures display dashes; one sample has zero duration. Nonzero source origins do
not affect elapsed zero at the beginning. Remaining is `max(0, total - elapsed)`.

**Playback speed ×** accepts the existing exact numeric draft/commit interaction.
0.5×, 1× and 2× produce half, normal and double progression within either mode.
Negative values retain reverse; zero holds. Modes retain independent stored rates:
switching mode can therefore change the displayed multiplier as well as duration.
No automatic cross-mode speed matching or new direction control is introduced.
Unchanged commits never rewrite an existing controller rate through a multiply/
divide round trip. Source clocks and seek precision are not rounded.

This is independent of render FPS, export FPS, solver timestep and field cadence.
A declared source unit such as milliseconds remains a scientific unit; it does
not silently change the existing one-recorded-unit-per-playback-second baseline.

## Validation and scope

[Focused evidence](evidence/issue-49/README.md) records native runs, regression
coverage, limitations and development failures. Only the transport adapter and
its focused validator/test change production behavior. Controllers, renderers,
source formats, scientific state schemas and offline video workers are unchanged.
Earlier review evidence remains historical. No #44/#46/#50 or UX4 work is claimed.

## Owner verification

1. Launch standalone with a normal capture at 1440×900 and 1024×640. Check elapsed
   left / total right; click the right value for negative remaining and back. Hover
   and drag the slider: sample index/count should appear only as a tooltip/hint.
2. Seek to the beginning and end: elapsed should show `0.0`, then equal total;
   remaining should end at `0.0`. Hover elapsed and verify exact source time/unit.
3. In each mode test 0.5×, 1×, 2× and a negative speed. Progress should scale within
   that mode, reverse should work, and total should remain stable during playback.
   Modes intentionally retain separate rates and nominal durations.
4. Cold-seek and rapidly replace targets. Elapsed/remaining must stay at the old
   committed position during preparation and then reflect only the latest commit.
5. Step/drag through irregular samples and a sparse volume: union indices and
   field Hold must remain unchanged. Test Loop, exact Seek and a saved recipe.
6. Hide the dock and enter/exit interactive fullscreen. Transport and mouse
   recovery must remain accessible. Review readability at your desktop scale.

# Issue #147 review evidence

Pending owner review. [Current contract and exact owner checks](../../UX5_CLEANUP.md).
[Results, failures, corrections and limits](summary.json) record 5,850 passing
native assertions across Forward+ and Compatibility, plus two Python version tests.
[Scientific comparison](scientific-comparison.json) records exact accepted-main
RGB-frame, timing and scientific-evidence equality with UI overlays disabled.

| View | Forward+ | Compatibility |
| --- | --- | --- |
| Membership checks and focus | [Filters](filters-focus-forward.png) | [Filters](filters-focus-compatibility.png) |
| Dynamic layer switches | [Fields](fields-forward.png) | [Fields](fields-compatibility.png) |
| File Details / full source | [Details](details-forward.png) | [Details](details-compatibility.png) |
| Violet owner logo / identity | [About](about-forward.png) | [About](about-compatibility.png) |
| 200% logical scale | [About](about-scale2-forward.png) | [About](about-scale2-compatibility.png) |

Additional Forward+ views: [disabled membership](filters-disabled-forward.png)
and [compact About](about-compact-forward.png).

The 200% window request was clamped to actual 2560×1394 by the compositor;
these are not physical 4K screenshots. No generated captures, executables or
scientific result payloads are committed. Full native logs and fixture artifacts
remain at `/home/Nozba/Codex/SIMSCOPE/cleanup-147` outside the repository.
Historical #143/#96 evidence remains unchanged.

Known limits include unchanged Space/playback coupling on rebuilt filter rows,
existing encoder-PID cleanup diagnostics, Wayland libdecor fallback, physical
4K/mixed-monitor review and unrerun standalone packaging. The summary preserves
initial failures and successful corrections without relabeling them as clean runs.

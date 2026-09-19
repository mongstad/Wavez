# Midnight Scientific reconciliation and validation — issue #8

Pending owner review. Issue #8 was the only Ready item before work began.
This review reconciles the accepted refinements from issues #5–#7; it does not
start UX3 or migrate production controls.

## Reconciliation

| Area | Resolution |
|---|---|
| Authority | Roadmap owns milestone scope; design system owns current tokens/rules; theme library owns implemented primitive contracts. Historical reports retain their original evidence. |
| Identity | Both authoritative documents specify blue-black surfaces and sparse blue/purple/teal accents. |
| Atmospheric depth | Both permit only an opt-in static low-contrast background; flat controls/diagnostics and scientific rendering remain separate. |
| Tiers | Low/Medium/High/XHigh/Max remain categorical UI accents, distinct from operational statuses and data colors. |
| Typography and density | Current bundled numeric font, 14/13/12 px text roles, 32/28 px controls and the spacing scale are explicit. |
| Implementation status | Removed obsolete statements that the theme, assets and laboratory do not exist; future shell/workspace proposals remain marked as proposals. |
| Motion | Immediate native UX2 states are distinguished from future timing limits and deferred preferences. |
| Point rendering wording | Corrected the old proposed combined label to preserve the accepted separation of representation and viewing preset. |
| Review gates | UX1/UX2 and #5–#7 acceptance do not authorize UX3. |

## Validation

Run from the repository root:

```bash
/path/to/python tools/validate_ux2.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output-dir results/issue-8-theme-review
```

Godot 4.7.2 Forward+ / NVIDIA RTX 3070 Ti: **PASS**. Import and all validation
logs were clean. [Summary](evidence/issue-8/summary.json) records 1,402 native
checks, 218 contrast pairs, 300 independent float64 oracle cases, six scientific
viewer isolation checks and six HUD cases. Source invariance passed.

The matrix previously visited only four pages; it now discovers every tab,
including Tiers. All five pages fit horizontally in 16 size/scale combinations:
1024×640, 1440×900, 2560×1440 and 3840×2160 at 100/125/150/200 percent.
[Metrics](evidence/issue-8/scale-metrics.json) retain each page's content/viewport
sizes and the unchanged 32/28 logical-pixel button heights. Native root/dialog
scale boundaries, dialog size caps and numeric font metrics also pass.

Reviewed the five-page contact sheets at [100%](evidence/issue-8/scale-100.png),
[125%](evidence/issue-8/scale-125.png), [150%](evidence/issue-8/scale-150.png) and
[200%](evidence/issue-8/scale-200.png). These include selected/pressed/disabled
controls, invalid numeric drafts, read-only/exact values, operational messages,
progress, token specimens and tier/status examples. Higher scales reduce the
visible logical area and scroll vertically rather than shrink text. At 150/200%
the pages stack to one column. This is expected, not missing content. The native
input suite separately validates keyboard focus, hover, press, tab traversal,
number commit/cancel, slider focus, menus and dialog focus recovery.

## Scientific isolation and limits

Production viewer/UI pixels remain byte-identical before and after loading,
editing and rebuilding the opt-in library. Scientific/visual/recipe snapshots
remain equal; no preparation/hash/upload counters fire. This branch changes
only documentation/evidence and the laboratory validator; theme, component,
production, exporter, analysis and rendering source are unchanged from its main
baseline. No source captures or scientific values were edited.

A new deterministic video export and full scientific regression suite were not
run: the relevant production sources are unchanged, and the focused isolation
suite passed. This evidence does not claim a newly measured video/analysis result.
Compatibility renderer, screen-reader/color-vision studies and long-session
comfort were not tested. The archived historical baseline was not requested.

Read-only display inspection reported a 2560×1440 primary monitor and a
1920×1080 secondary monitor. No connected physical 4K mode was available;
3840×2160 results are rendered SubViewports, not physical 4K acceptance.
Mixed-monitor window movement was not tested and display settings were not changed.

## Owner acceptance

Launch `res://ui/lab/ui_laboratory.tscn`; visit all five tabs at your preferred
scale, scroll to the bottom, and inspect dialogs and keyboard focus. Confirm
quiet atmospheric depth, tier/status distinction, compact numeric readability
and comfortable long-session contrast. Confirm a normal capture retains its
usual appearance. Physical 4K review remains a follow-up when hardware permits.
Stop after this issue; production migration requires separate authorization.

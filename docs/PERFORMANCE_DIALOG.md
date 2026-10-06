# Performance dialog

Issue #222 proposes horizontal configuration rows in **Tools → Performance**,
candidate **v0.1.0.61**, pending owner review. Decoded cache, GPU budget and
available particle/field preparation selectors place each label beside its
existing editor. Labels share a 140 px column; editors fill the remaining width.
Long labels wrap within their column and long forms scroll at minimum width.
Clear decoded cache remains directly below its budget row.

The verbose decoded-cache reader sentence is absent from the normal form. Its
label/state still updates and **File → Details** retains the reader's status,
cache usage, hits and index timing. Particle/field/mesh preparation status remains
on the Performance form. Budgets, units, defaults, callbacks, clear behavior and
scientific preparation/allocation/eviction logic are unchanged.

The local presentation helper reuses the original widgets and signals. It runs
when Performance opens, so controls rebuilt for a newly loaded source receive
rows too; repeated opening does not replace or duplicate editors. Other Tools
forms keep their existing presentation.

[Focused evidence](evidence/issue-222/README.md) includes normal/minimum and 1.5×
scaling screenshots, budget-edit and cache-clear checks, diagnostic retention
and source reload. Physical mixed-DPI/4K and other OSes remain owner checks.

## Owner verification

1. Open a small `.wvz`, then **Tools → Performance**. Confirm Decoded cache and
   GPU budget each have a label and editor on one row, with aligned labels and
   usable controls. Check normal and minimum dialog width and preferred scaling.
2. Change Decoded cache from 256 to 128 MiB, then restore 256. Change GPU budget
   from 256 to 128, then restore 256. Values should retain their existing effects
   and units; no budget defaults or cache/preparation policy should change.
3. Click **Clear decoded cache** and confirm the configured budget remains.
   Inspect **File → Details** for reader diagnostics. Confirm the verbose
   “Synchronous layer reads…” sentence is absent from Performance.
4. If available, select an advanced field-preparation interval and check its
   start/end editors remain beside their labels. Tab through controls, scroll
   the compact form, close/reopen it, and reload a capture to check the rebuilt
   controls and existing focus recovery.

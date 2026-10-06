# Issue #222: Performance configuration rows

Candidate **v0.1.0.61** is pending owner review on existing branch
`222-ux-tools-use-horizontal-labelcontrol-rows-in-performance-dialog`.
Preflight found #222 as the sole Ready Project item; GitHub's linked branch,
local main and origin/main matched accepted `74b0723` (owner-merged PR #272).
The working tree was clean. Remote references were pruned; the completed #271
branch was already absent. No separate acceptance documentation was created.

## Change and focused validation

The local Performance presentation helper moves existing adjacent label/editor
pairs into horizontal rows, aligning labels and filling available editor width.
It also aligns existing preparation range rows. Original callbacks and widgets
remain intact, including after source reload. Clear decoded cache stays beneath
its budget. The continuously updated cache status label lives in hidden storage
and still supplies File Details, rather than inline Performance diagnostics.

The [temporary native review script](performance_review.gd) used a tiny synthetic
mixed WVZ1 fixture and isolated preferences with external Godot 4.7.2 on
Forward+ / X11. It completed with **59 checks, zero failures**, including:

- horizontal decoded/GPU budget rows; original limits, steps and MiB guidance;
- editing Decoded cache updates `decoded_cache_mib` and the reader's byte limit;
- editing GPU budget updates the layer owner's `gpu_budget_mib`;
- seeded decoded cache becomes empty when the original Clear button signal is
  emitted, while configured budget remains intact;
- decoded diagnostics absent from the form but retained in File Details;
- aligned labels/editor bounds at 560 px, 320 px minimum and 440 px with 1.5×
  scaling, and original budget editor identity across repeated opens;
- a reloaded source gets horizontal GPU rows without duplicating the decoded
  editor; the viewer shuts down cleanly.

[Report](report.json), [native output](native.txt), [normal](performance-normal.png),
[minimum width](performance-minimum.png), [1.5× scaling](performance-scale-1.5.png).

For reproduction, create `/tmp/wavez-222/mixed.wvz` with
`tools/validate_simulation_panel.py`'s `fixture(path, ['particles','volume','mesh'])`,
then run the saved review script via Godot `--path viewer --script <absolute
script path> --display-driver x11 --rendering-method forward_plus`. Set isolated
`XDG_DATA_HOME` and `XDG_CONFIG_HOME` directories under `/tmp/wavez-222`.
The script restores edited budget values and writes only temporary evidence.
No production scientific simulation was run.

Godot editor import completed with five warnings about missing UID files being
recreated from cache for unrelated resize/pacing scripts. No script errors were
reported; those generated, previously untracked sidecars were removed. The
[import output](import.txt) preserves the warnings. `python -m unittest tests.test_application_version`: **2 passed**.
`git diff --check` passed. The initial focused review completed cleanly without
failures or retries.

## Scope, limits and owner review

Validation targets presentation and existing callbacks directly affected by
reparenting. No unrelated playback/rendering/scientific suites were required or
run. Separate Compatibility comparison, packaged Linux, other OSes, physical
4K/mixed-DPI, accessibility and long sessions were not checked. Automated cache
and budget checks verify the existing callback/model contract, not a broad
scientific/cache architecture audit.

Follow the [current owner checks](../../PERFORMANCE_DIALOG.md). Judge label
wrapping, control width and scrolling on the preferred display; exercise
advanced preparation fields and physical Tab/hover/close/reopen behavior.
Historical #161/#271 and other review-time reports remain unchanged.

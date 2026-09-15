# UX1 evidence — 2026-09-13

Baseline `47fef34dc5bdcbbc8db7f562f778deb100a70d5c`. This directory records the existing UI and calculations for a proposed design. It contains no product Theme or component implementation. See the [milestone report](../../UX1_REPORT.md).

## Retained files

- [summary.json](summary.json): runtime, geometry, expanded section sizes, 37 audit checks and image hashes. Checks include evidence capture and observations of existing deficiencies; they are not 37 usability acceptance criteria.
- [control-inventory.json](control-inventory.json): constructed controls, labels, options, font size and focus/tooltip properties. Includes hidden controls; excludes engine-internal children and dynamically created dialogs after the inventory snapshot.
- [contrast.json](contrast.json): 46 foreground/background pairs meet the proposed 4.5:1 text or 3:1 indicator target. Disabled text is not claimed to meet the ordinary text target. No claim about the current UI's contrast compliance.
- [hud.json](hud.json), [HUD log](hud.log.txt), [audit log](audit.log.txt): native Forward+ runs. Six HUD width/time-mode cases keep the same height and control positions across digit transitions.
- Fifteen PNGs: existing empty/loaded/width/transport/export/recipe/selection/plot/mesh/volume/hidden/smaller-window/4K layouts. The [audit](../../UX1_UI_AUDIT.md#evidence-map) links each image by purpose.
- [repository-review.json](repository-review.json): starting branch/commit, preserved untracked UID files and staging scope.

The 4K image is a real GPU SubViewport at 3840×2160 with the existing export-style 1440×810 logical canvas. It uses a synchronous fixture viewer, so it omits the desktop asynchronous particle-buffer controls. The smaller-window filename describes a requested 1280×720 window; the captured canvas is 1152×720 under the current root's aspect scaling. Native fullscreen was toggled/restored on the current 2560×1440 screen. Physical 4K and cross-monitor DPI were not tested.

## Reproduction

From the repository root, choose a **new** ignored output directory. These are analytic fixtures and source-data queries, not scientific simulation runs. The audit requires a display/GPU. Replace the executable paths with local installations; Python needs the project's current dependencies, including NumPy and zstandard for this fixture. Actual run used Python 3.14.7 and Godot 4.7.2 Forward+.

```bash
mkdir -p results/ux1-review
PYTHONDONTWRITEBYTECODE=1 python3 -m examples.scene_demo --small --output results/ux1-review/scene.ssc
PYTHONDONTWRITEBYTECODE=1 python3 -m examples.identity_demo --output results/ux1-review/identity.ssc
XDG_DATA_HOME=/tmp/simscope-ux1-review godot --path viewer --rendering-method forward_plus --script ../tools/audit_ux1.gd -- --ux1-output="$PWD/results/ux1-review" > results/ux1-review/audit.log.txt 2>&1
XDG_DATA_HOME=/tmp/simscope-ux1-review godot --path viewer --rendering-method forward_plus --script res://scene/test_hud_layout.gd -- --hud-fixture="$PWD/results/ux1-review/identity.ssc" --hud-output="$PWD/results/ux1-review/hud" > results/ux1-review/hud.log.txt 2>&1
PYTHONDONTWRITEBYTECODE=1 python3 tools/summarize_ux1.py --audit-dir results/ux1-review --evidence-dir results/ux1-review/compact
PYTHONDONTWRITEBYTECODE=1 python3 tools/validate_documentation.py --output-dir results/ux1-review/documentation
```

Set `PYTHON_BIN` to the Python executable if it is not discoverable by the existing analysis worker; place its environment on `PATH` as well. The original run did this with `/tmp/perf003-analysis-runtime/bin`. Reproduction should retain new results locally, not overwrite this historical milestone evidence. The summarizer intentionally refuses if the protected source has changed since UX1's accepted baseline. It is an audit checkpoint tool, not a universal future-release validator.

Raw local output was `results/ux1/`, including 26 screenshots and a 6.5 MB per-state node tree. Captures, worker caches, full trees and unselected images are excluded from Git. The existing HUD regression used the retained synthetic identity fixture at `results/legacy-retirement/identity-demo.ssc`; the command above generates its current equivalent for a fresh checkout.

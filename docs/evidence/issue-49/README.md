# Issue #49 review evidence

**Pending owner review.** #49 was the sole Ready item at preflight. The existing
owner-linked branch started clean at accepted main `1976adc` (PR #48). Required
transport predecessor PR #47 and status PR #48 were present. The previous local
branch was already absent; its stale remote reference was pruned. No Project
writes, acceptance-only PR or historical evidence rewrites were made.

Native host: Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti. Tests use small
synthetic mixed particle/mesh/field, offset-time and single-sample captures.

| Check | Result | Evidence |
|---|---|---|
| Final native transport Forward+ | 174 checks passed; source hashes unchanged | [report](forward.json) |
| Final native transport Compatibility | 174 checks passed; source hashes unchanged | [report](compatibility.json) |
| Final status/Jobs Forward+ regression | 67 checks passed; source unchanged | [report](status.json) |
| Godot headless editor import | Exit 0; no ERROR/WARNING entries | Local `/tmp/issue-49-import.log` |
| Python validator compilation and Git whitespace check | Passed | `py_compile`; `git diff --check` |

The expanded #42 baseline covers start/end, stable nominal total, total/remaining
toggle, fractional elapsed in both modes, signed speeds (-2, -0.5, 0, 0.5, 1, 2),
real controller progression, cold preparation barrier, latest replacement seek,
committed-only elapsed/remaining, union stepping, sparse field Hold, exact Seek,
recipe restoration, independent mode rates, unchanged rate precision, offset
source origins and zero duration. Source units remain scientific metadata.

The final owner refinement removes persistent index captions: hover uses the
slider tooltip and dragging shows a transient index/count hint. Tests verify
hint visibility/text/release via slider signals; the screenshot records its
rendered appearance. A physical mouse hover/drag remains an owner verification
step, not a claim of automated native pointer coverage.

Layout checks cover 1440×900 and 1024×640, dock hiding and interactive fullscreen
transport access. Fullscreen uses the existing shell action; this run does not
repeat the earlier independent KWin geometry investigation. 100 synchronous
transport refreshes produce no instrumented scientific stages/counters or visual
state changes. This is not a comprehensive performance benchmark.

- [Desktop layout](loaded-1440.png)
- [Compact layout](loaded-1024.png)
- [Remaining duration](remaining.png)
- [Transient dragging hint](index-drag.png)

## Commands

From the repository root, using the externally installed Godot executable:

```sh
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-49-reviewed-forward
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer gl_compatibility --output-dir results/issue-49-reviewed-compatibility
python tools/validate_viewer_status.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-49-reviewed-status
"$GODOT" --headless --path viewer --editor --import --quit
python -m py_compile tools/validate_viewer_transport.py
git diff --check
```

Native logs and generated captures remain in ignored `results/` directories;
only small reports and screenshots are retained here. Initial development run
`issue-49-dev` failed two height assertions after adding the duration button.
The layout was corrected, preserving 64/104 px allocations; both final renderer
runs pass. Earlier 169/171-check runs also passed before the owner requested
moving the index caption into a tooltip. There are no outstanding test failures.

## Limitations and owner checks

No production scientific simulation, large-capture benchmark, physical HiDPI
matrix, full scientific suite or standalone video-continuation suite was rerun.
The focused status suite exercises existing export/job lifecycle integration;
no controller, sampling, video worker or renderer code changes are included.

Follow the exact [manual verification steps](../../UX3_MEDIA_TRANSPORT.md#owner-verification),
particularly real mouse tooltip/drag behavior, speed perception in each mode,
cold seeks and readability at the owner's desktop scale. Nominal durations are
at 1×; mode changes can change the duration and retained multiplier. Acceptance
remains with the owner. Historical #41–43 reports remain untouched.

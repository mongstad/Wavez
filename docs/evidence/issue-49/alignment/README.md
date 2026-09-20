# Playback panel alignment refinement

Pending owner review in PR #51. The transport rows are vertically centered as a
single group, the slider is centered against elapsed/total labels, and horizontal
spacing is reduced from 8 to 4 px with tighter duration-button padding. Normal
and compact panel heights remain 64/104 px. Playback/state semantics are unchanged.

Native Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti:

- Forward+: **136 checks passed**, source hashes unchanged ([report](forward.json)).
- Compatibility: **136 checks passed**, source hashes unchanged ([report](compatibility.json)).
- New assertions verify equal top/bottom row spacing and aligned slider/readout
  centers at 1440×900 and 1024×640. Both screenshots were visually inspected.
- `git diff --check` passed. No failures or unavailable focused checks.

[Desktop screenshot](loaded-1440.png) · [Compact screenshot](loaded-1024.png)

Commands: `tools/validate_viewer_transport.py --godot "$GODOT" --renderer
forward_plus --output-dir results/issue-49-aligned-forward` and the same command
with `--renderer gl_compatibility --output-dir results/issue-49-aligned-compatibility`.
Run with the project Python environment. Earlier evidence remains untouched.

State/video suites were not repeated for this geometry-only change; their prior
results remain in the single-playback evidence. Physical HiDPI was not tested.
Owner check: relaunch at normal desktop and compact sizes, verify equal vertical
spacing and the slider/time baseline, then toggle total/remaining and drag the
slider to confirm readability and the retained index hint at your desktop scale.

# Issue #94 — first README editorial draft

Prepared 2026-10-12 from accepted **v0.1.0.103**, owner-merged PR #384
(`0156fea1928758ce1969698ba1befad693f60e61`). Candidate **v0.1.0.104** is a
documentation draft, not publication, release approval or owner acceptance.
The existing #94 branch was checked out, clean and equal to accepted main;
#94 was the sole Ready item. PR #384 content matches main, refs were pruned,
and its completed #375 branch was already absent.

## Editorial decisions

- Replace the long technical link index with a 689-word introduction, selected
  capabilities, a short next-step path, dependencies, hardware guidance and licensing.
- Keep the early, explicit experimental/incomplete Selection/Analysis caveat,
  including scientific state workflows, known UX issues #341/#342, limits of
  automated tests and independent scientific verification.
- Reuse the existing dark and white horizontal wordmarks as one theme-aware
  `<picture>` with a 640-pixel width and unchanged aspect ratio. Both are opaque
  2172×724 artwork, visually inspected and byte-identical to accepted main.
  The square emblem is unnecessary for this layout. No asset was copied or edited.
- Use the owner's two bold text placeholders: viewer showcase first; same-simulation
  Python/Wavez comparison beneath it. No broken image path, fake caption, generated
  image, unrelated image or claim of a matched view is included. Final screenshot
  selection remains an owner editorial step on this same PR.
- Minimum/recommended/high-end numbers are provisional guidance from the issue,
  not measured thresholds. Tested development hardware is separate. No 1.0 or
  universal platform, precision, throughput or GPU-equivalence promise is made.

## Claim verification

| README claim | Current source / accepted contract checked |
|---|---|
| WVZ1 `.wvz`, particle/field/mesh and mixed scenes | `wavez_export/scene.py`, `viewer/layers/scene_layers.gd`, `docs/CAPTURE_FORMAT_POLICY.md` |
| Particles / Fields / Meshes interface; recorded-time navigation | `viewer/ui/shell/viewer_shell.gd`, `viewer/ui/shell/viewer_transport.gd`, `docs/WAVEZ_HANDBOOK.md` |
| Colormaps, legends, field range/opacity/slices | `viewer/layers/grid_view.gd`, `viewer/layers/volume.gdshader`, `viewer/layers/slice.gdshader`, handbook |
| Free camera / orbit | `viewer/main.gd`, `docs/MANUAL_CAMERA_ORBIT.md`, `docs/AUTO_ORBIT.md` |
| Viewport PNG and deterministic video | `viewer/main.gd::_capture_inspection_png`, `viewer/video/render_worker.gd`, `docs/IMAGE_EXPORT.md`, `docs/VIDEO_EXPORT.md` |
| Source-based probing with limits; experimental Analysis | Accepted #375 scientific contract/audit; native `grid_view.gd::probe`; open #341/#342 confirmed via GitHub |
| Packaged runtime, external Python/NumPy, source Godot and export templates | `tools/package_linux.py`, `viewer/analysis/packaged_runtime.gd`, `GETTING_STARTED.md`, `docs/PACKAGED_VIDEO_EXPORT.md` |
| Python 3.10+, NumPy ≥1.23; optional zstd and extraction dependencies | `pyproject.toml`, `wavez_export/codec.py`, Getting Started; scikit-image ≥0.26,<0.27 on Python ≥3.11 |
| External FFmpeg with libx264, independent ordinary video | `viewer/video/render_worker.gd:334`, accepted video contract and Getting Started |
| Linux x86_64 / Forward+ Vulkan only | `viewer/project.godot`, `viewer/renderer_policy.gd`, `docs/RENDERER_REQUIREMENTS.md` |
| Adaptive bounded preparation; RAM/CPU/GPU/storage roles | `viewer/layers/field_playback.gd`, `field_buffer.gd`, `field_concurrency.gd`, current preparation/cache guides |
| Source-available noncommercial license, third-party terms and branding | Unchanged `LICENSE`, `THIRD_PARTY_LICENSES.md`, `TRADEMARKS.md` |

Host inventory verifies Fedora 44 KDE, Ryzen 7 5800X, RTX 3070 Ti / 8192 MiB,
driver 615.71.09 and Godot 4.7.2 `ed1daf0bf`. Installed RAM is nominally 48 GiB;
kernel `MemTotal` is 49,223,192 KiB (about 46.94 GiB after reservations).
Retained accepted #374 source/release Vulkan evidence supplies the tested-use
context. This task does not rebenchmark that host. A sandboxed NVIDIA query
could not access the driver; the authorized read-only query succeeded.

The official [Godot engine requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html)
were checked as engine prerequisites, not proof of Wavez's proposed RAM/VRAM tiers.
[GitHub's picture-element guidance](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github)
supports theme-specific wordmarks. Public wording uses the repository's stricter
Vulkan-only policy and supported Linux scope.

## Focused checks and limitations

- Seven relative link/anchor references and all three image references resolve.
  Both branding assets match main; placeholders are text, not images.
- GitHub's GFM API rendered the picture element, two tables, early caveat and
  both placeholders. Final browser layout/theme review is an owner step.
- `python -m unittest tests.test_application_version -v`: **2 tests PASS**.
- Required Godot editor import: exit **0**, no script errors. It recreated four
  previously absent resize-diagnostic UID sidecars with warnings. Those unrelated
  generated files were removed; all tracked UIDs remain unchanged.
- Format/current-platform wording, staged text/sizes and whitespace were checked.
  [Compact checks](checks.json) retain counts, inventory and hashes; raw output is
  outside Git at `/home/Nozba/Codex/Wavez/readme-94/`.

No runtime feature, algorithm, shader, format, package or licensing change was
made. No new automated test, screenshot pipeline, solver run, rendering campaign,
hardware-tier benchmark, package rebuild or unrelated regression suite was needed
for this documentation change. No new screenshot is proposed as scientific
evidence; current-shell showcase and matched-data/time comparison remain pending.
Historical reports and review-time wording are unchanged. Repository privacy was
verified via GitHub; no repository/Project settings, tag or release were changed.

## Owner editorial review

1. Inspect the branch README on GitHub in light and dark themes and at a narrow
   width: wordmark, placeholder placement, early status note and table readability.
2. Review tone, feature selection, dependency/hardware qualifiers and licensing.
   The approximate word count is guidance, not a hard acceptance threshold.
3. Supply/select the final current viewer showcase and same-simulation Python/Wavez
   comparison during iteration. Match source data/time and use truthful captions;
   appearance is not evidence of greater scientific accuracy.
4. Keep subsequent changes on this same branch/PR. This first PR is an editorial
   draft and is not expected to be merged immediately; no Analysis workflow test
   campaign or public publication is required to review it.

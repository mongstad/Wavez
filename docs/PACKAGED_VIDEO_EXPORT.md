# Video export from Linux release builds

File → Export → Video uses the existing secondary GPU worker, renders recorded
samples to temporary PNGs and uses external FFmpeg to publish MP4. The workflow,
job schema and dependencies are identical with zero, one or many selections.
Camera/orbit, timing, render appearance, legends, Jobs/background, cancellation
and PNG retention keep their existing contracts. Issue #340 removes automatic
scientific recipe processing and Selection/Analysis overlays from this visual
workflow (accepted in PR #344).

## Build and run

**Forward+ Vulkan is required** for the interactive package and every GPU worker.
Use a Vulkan-capable GPU and working Vulkan drivers on a graphical Linux desktop.
There is no supported Compatibility fallback. See [requirements and startup
troubleshooting](RENDERER_REQUIREMENTS.md).

From the repository root, with externally installed Godot 4.7.x export templates:

```sh
python tools/package_linux.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/wavez-linux-review
cd /tmp/wavez-linux-review
./WAVEZ.x86_64
```

Keep `WAVEZ.x86_64` and `WAVEZ.pck` together and name them consistently. The build
also writes the application identity, engine version, artifact hashes and bundled
first-party Python inventory to `build.json`. It builds a **release** template in
an isolated staging project and removes that project before returning. Output
must be a new directory; no binary or encoder is vendored into the source tree.
This is review packaging, not a public release or completed distribution-license
audit. Existing [third-party licensing](../THIRD_PARTY_LICENSES.md) rules apply.

The running application and render child use their PCK without an editor, a
source checkout or an imported development project. FFmpeg remains an external
executable, discovered through PATH or Edit → Preferences → File Locations.
Independent Selection/Analysis and explicitly requested Matched Views use Python 3/NumPy and
the current [Python dependency requirements](../THIRD_PARTY_LICENSES.md).
The build packages the canonical Wavez Python modules and analysis entry point
inside the PCK. Each packaged analysis worker materializes only these owned
sources in its private user-data job directory; shutdown removes the materialized
code. It does not import an installed Wavez module or search a nearby repository.
Ordinary video export needs no Python worker, including with active selections.

Use this build tool to preserve the independent scientific tools in release packages. An
ad-hoc Godot export that omits the first-party archive reports that the packaged
analysis resources are missing. The build also explicitly includes the raw
colormap JSON used by both the viewer and analysis worker.

## Reproduced cause and implementation

Accepted `main` at `56b3caa` passed `--path` to every second-process invocation.
The official Godot 4.7.2 release template rejected it and exited with status 1
before creating `progress.json` or `renderer.log`. The same job completed with
the development engine. Godot documents that path overrides require an editor
build or a specially compiled template in its
[command-line guide](https://github.com/godotengine/godot-docs/blob/master/tutorials/editor/command_line_tutorial.rst).

`render_job.gd` now adds the project path only when the running executable has
the `editor` feature. Export templates start `OS.get_executable_path()` directly,
with explicitly pinned Forward+ Vulkan, fixed FPS, absolute job path and diagnostics path.
`main.gd` dispatches the user argument to the existing minimized GPU worker.
The release tests exercise compiled scripts and loaded `res://` resources.

Every UI launch retains `launch.json` with the executable, complete arguments,
package flag and requested renderer, alongside `job.json`. Worker `metrics.json`
records its actual executable, template/release flags, renderer and user
arguments. Early worker exit exposes its exit status and retained job directory
through the existing status/Jobs path, even when it has not written progress.
The explicitly requested Matched Views version-2 worker's source-analysis boundary uses the same packaged archive
as its parent; development continues to use the canonical source files.

Required internal files are exported Godot resources, the raw colormap JSON and
the build-generated first-party Python archive. Selected captures, jobs, outputs,
portable recipes/member assets and external encoder/runtime paths are absolute.
Linux's existing `/usr/bin/stat`, `/usr/bin/env` and `/bin/ln` system utilities
remain dependencies. No solver, reader policy or export protocol is changed.

## Validation and owner checks

Run the focused development matrix, then the release matrix on each renderer:

```sh
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/video-source --renderer forward_plus
python tools/validate_packaged_video.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/video-release --renderer forward_plus --export \
  --compare-source /tmp/video-source
```

Use fresh output directories for each Forward+ run. The fixture generator
uses Python/NumPy; export processes are run with a blocking `python3` executable
on PATH so any unintended video analysis dependency fails visibly. Tests also
require visible/hidden particle, mesh, field and combined selections, and a
populated Analysis plot, to produce pixels and timing identical to an equivalent
ordinary export. Optional visual records must also remain identical.

Independent scientific workflows:

```sh
python tools/validate_selections.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/independent-selections --renderer headless
python tools/validate_g4_matched.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/explicit-matched --renderer forward_plus
python -m unittest tests.test_analysis_recipes tests.test_analysis_matched_render
```

Release tests change
only the parent test entry; child jobs dispatch through the production Main scene.
They remove the build project and run from an unrelated directory with no Godot
on PATH and no Python import path pointing at the repository. The matrix covers
particles, mixed particle/field/mesh content, legends off/on, orbit, exact-ID
particle/mesh/field and multiple selections with Python deliberately blocked during
video, unchecked/checked optional visual records, background/Jobs reopening, rendering/encoding
cancellation, encoder missing/failure, parent close and early child failure.
FFprobe verifies MP4 dimensions/FPS/frame count, and release/development decoded
pixels and timing/sample/camera traces are compared. All input bytes are hashed.
The [#340 evidence](evidence/issue-340/README.md) records current results and
limitations; [#93 evidence](evidence/issue-93/README.md) remains the historical
packaged-worker startup record.

Before acceptance:

1. Build into a new directory outside the repository, keep the executable and
   PCK together, and launch the executable directly from an unrelated directory.
2. Open a valid `.wvz`, choose File → Export → Video, select a short range and
   a fresh output, and confirm the MP4 plays with the requested renderer/settings.
3. Repeat with a mixed capture and legends off/on. Use independent Selection to
   create particle, mesh and field selections with Python/NumPy installed. Export
   again with the same video settings and Python unavailable: no new scientific
   worker, recipe directory, quota field or mandatory JSON should appear. Selection
   highlights and Analysis plots must be absent from the MP4, while the interactive
   highlights/results remain available. Compare against the zero-selection clip:
   the ordinary visualization and legends must be identical. Check
   **Output → Advanced → Save per-frame inspection JSON** explicitly and confirm
   visual records are written only then, with no scientific results. See
   [the video boundary](VIDEO_EXPORT.md).
4. Verify independent Selection/Temporal Analysis, inspection save/restore and
   numerical results with Python/NumPy installed. Matched Views retains its explicit
   scientific recipe contract.
5. Use Run in background, reopen through Jobs, inspect Details, then cancel a
   longer render and an encoding-stage job. Confirm no partial final MP4 appears.
6. Start another job, close the parent, cancel the exit confirmation once, then
   confirm exit. Check the retained worker progress reports cancellation.
7. Select an unavailable FFmpeg path and check the File Locations guidance. Review
   `launch.json`, `renderer.log`, `progress.json`, `metrics.json` and `ffmpeg.log`
   for a failed job. Successful exports clean staged PNGs; failed/cancelled jobs
   retain them.

Other operating systems, public distribution, a machine with Godot physically
uninstalled, long production exports and physical desktop interaction remain
owner/platform checks. No passing automation constitutes owner acceptance.

The installed Godot 4.7.2 Linux release template can emit root-Window
`focus_entered` / `tree_exited` errors during embedded Popup show/hide. The
[Window signal investigation](ROOT_WINDOW_SIGNALS.md) isolates this outside the
exporter and explains counts, source/debug comparisons and remaining uncertainty.
These diagnostics remain visible and prevent a clean strict-validation result;
packaging continues to use the release template.

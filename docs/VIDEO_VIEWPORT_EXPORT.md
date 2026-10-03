# Viewport-only video composition — issue #198

Candidate build **v0.1.0.34** awaits owner review. The Video Export dialog
continues to define what the job renders. The dedicated offline SubViewport
defines what can enter each frame: scientific particles, fields and meshes,
plus eligible viewport legends. Application menus, right dock, transport,
timeline, status/Jobs and dialogs are outside that composition.

The worker still restores the job's visual state, samples recorded time and
camera motion, renders at the requested dimensions, writes PNG frames, and
encodes the MP4. The offline shell stays available to its existing controllers
but is hidden; its dock and resize handle are hidden, and legend placement uses
the full viewport bounds. Existing particle and layer legend widgets remain
the source of scientific labels and colormaps. The export's **Overlays** choice
gates them independently of the interactive shell; each legend's saved
visibility and channel eligibility still apply. Independent guides, markers
and selections retain their own established gates.

**Rendering = Current state**, **Cinematic preset** and **Scientific preset**
continue to produce their corresponding job states. The same dialog job owns
range, FPS, capture-time rate, dimensions, camera mode/orbit rate, trails,
quality and temporary-output choices. Its shell workspace, scroll and
remaining-time metadata is retained in the job record for existing workflows,
but cannot change frame pixels. The earlier production-shell overlay report
under [issue #55](evidence/issue-55/README.md) remains a historical record.

## Unobstructed frame evidence

These are first PNG frames retained from short encoded Forward+ MP4 jobs on
synthetic WVZ1 captures. No application chrome appears in the render target.

| Scene and export setting | Frame |
| --- | --- |
| Particles, overlays off | [No legend](evidence/issue-198/particles-no-legends.png) |
| Particles, overlays on | [Particle legend](evidence/issue-198/particles-legends.png) |
| Field, overlays on | [Field legend](evidence/issue-198/field-legend.png) |
| Mesh, overlays on | [Mesh legend](evidence/issue-198/mesh-legend.png) |
| Mixed particles, field and mesh, overlays on | [Mixed viewport legends](evidence/issue-198/mixed-legends.png) |

## Validation and limits

`tools/validate_video.py --overlay-ui` exercises the Video Export dialog,
rendered 1080p and 4K MP4s, overlay on/off, repeat determinism, and the three
Rendering selections. `tools/validate_video_current.py` with
`--viewport-composition` checks particle, field, mesh and mixed jobs; camera,
sample time and scientific source evidence; legend and shell gates; and
viewport-only pixels. With `--packaged-binary`, it compares selected standalone
Linux package frames and timing with development runs.

The focused dialog/overlay suite passed **172 checks per renderer** on Forward+
and Compatibility, including actual 1080p and 4K MP4s, deterministic repeats,
visibly distinct Current/Cinematic/Scientific frames, and the selected orbit,
timing, quality and temporary-output settings. The representative
scene matrix passed **290 checks on Forward+** and **280 on Compatibility**;
five packaged cases on each renderer matched development pixels, timing and
camera traces. Synthetic source file hashes were unchanged. The normal Linux
package imported, exported and started without errors on both renderers. The
directly affected video/status lifecycle passed **257 checks on Forward+**,
including backgrounding, cancellation, progress and completion. The two Python
application-version checks also passed. The source editor import completed with
five missing-UID warnings for unchanged resize scripts and no script errors;
its generated, unrelated sidecars were removed from this branch.

An initial UX harness still expected #161's former built-in screenshot picker;
its assertions now check the accepted native picker request and cancel
semantics. The first mesh matrix job omitted the mesh legend preference; the
corrected fixture enables it explicitly. Both final suites pass.

The 4K test checks actual PNG and MP4 dimensions through FFprobe; it does not
exercise a physical 4K monitor. Mixed DPI, other desktop compositors, assistive
technology and long-running exports remain owner review items. The synthetic
fixtures cannot establish visual quality for every production scene.

## Owner verification

1. Export a particle scene with Overlays off, then on, then off again. Check
   the MP4 for absent/present/absent legends and no File menu, dock, transport,
   status, Jobs or dialog chrome.
2. Export representative field, mesh and mixed scenes with their individual
   viewport legends enabled. Confirm the labels, channel, colormap and range
   match the interactive scientific viewport.
3. Change Rendering between Current state, Cinematic and Scientific. Confirm
   each selected preset survives export, along with FPS, range, resolution,
   camera/orbit, trails and quality settings.
4. Repeat a short export on Forward+ and Compatibility and from a packaged
   Linux build. Check backgrounding, progress and cancellation. Inspect a 4K
   output and, if available, test the UI at mixed display scales.

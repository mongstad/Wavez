# Edit the existing orbit center and radius (#120)

Historical status: revised-description candidate in PR #152.
Accepted baseline: `1a607740876736fdff34a25ca18ef395d33a4fe7` (build 11).
Candidate: build 12. This document records that candidate's usage and validation.
The earlier `CUSTOM_ORBIT.md` and its original evidence remain unchanged historical
records of the superseded implementation. The usage, architecture and validation
below describe the historical #120 candidate. For the current #234 editor mode,
Apply/Cancel behavior and owner checks, see [Auto Orbit](AUTO_ORBIT.md).

## Use

1. Choose **Navigate → Edit orbit center…** (Navigate shortcut: Alt+N).
2. Drag the X/Y/Z endpoint handles or type arbitrary world coordinates. Placement
   does not require a probe, selection, named object, or scientific surface.
3. Enter a radius, or use −/+ and wheel over the radius controls. Each normal step
   multiplies/divides by 1.25; Shift uses 1.02. Coordinates accept finite values
   with magnitude at most 1e15; radius accepts 0.000001–1e15 world units.
4. **Place ahead** places the proposed center one proposed radius along the current
   view direction. It does not move the accepted camera.
5. **Apply** changes `camera_target` and `camera_distance`, calls the existing
   `_update_camera()`, and removes the editor/guide. **Cancel** discards the draft.

Viewport drag/wheel, Auto Orbit, and Free-camera WASD/Q/E continue through their
existing paths, including while editing. Numeric text focus keeps its normal
keyboard protection. Cancel does not undo deliberate viewport navigation while
the editor was open. There is no persistent custom camera mode, alternate zoom,
Free-camera movement model, or serialization field.

Normal wheel zoom uses a 10% inward step and its exact reciprocal outward.
Fractional wheel input is proportional, and one event is capped at one notch.
Limits use the last framed scene bounding radius and camera near/far planes;
a custom radius outside those limits moves progressively toward them and never
snaps to a fixed world-unit bound. Frame Scene refreshes the bound and retains
its accepted target/orientation meaning; Reset and Frame close the proposal.
Escape retains fullscreen recovery. See [zoom validation](evidence/issue-187/README.md).

**Hide controls / Show controls** collapses the coordinate rows to make room for
the gizmo. Setup starts collapsed in windows shorter than 720 pixels. Apply and
Cancel remain visible.

The wire circles show the proposed world-space radius; colored axis handles show
the center and editable axes. Dark outlines keep them readable over bright/dark
content. A center behind the camera or an axis almost end-on cannot expose a
useful projected handle; numeric coordinates and Place ahead remain available.
Large radii may extend beyond the viewport. Projection uses Godot's existing
world-coordinate precision and clipping; this feature does not change those limits.

The proposal is UI-only. Opening another capture, Frame, Reset, or taking a PNG
closes it. Presets, inspection recipes and video jobs read only the accepted
camera state. Offline workers never create the editor. Closing setup does not
pause playback, cancel preparation, alter coverage, change pacing, or reset UI
settings.

## Architecture and scope

Production additions are two UI scripts (`orbit_center_editor.gd` and
`orbit_center_guide.gd`), a Navigate entry, and transient-editor dismissal at the
existing capture/reset/frame entry points. All camera input/update/movement,
playback, field/mesh/particle preparation, cache, scientific rendering, persistent
visual-state and offline export implementations match accepted main. The only
camera assignments in the editor occur on Apply. A stationary guide queues no
continuous redraw; camera/layout changes only update its projected UI geometry.

## Validation

Fresh results and representative screenshots are recorded under
`docs/evidence/issue-120/restart/`. Baseline runs use an independent source archive
of accepted main without checking out another branch. GPU runs are sequential.

The focused `tools/validate_orbit_center.py` runs the same camera and playback
probe against that archive and the candidate, then compares their recorded
camera/clock/preparation behavior and deterministic video pixels. It covers
particles, scalar fields, meshes, mixed scenes, and mesh scenes differing by
10,000,000 in world scale. It also exercises real handle event routing, numeric
validation, cancellation, re-entry, PNG exclusion, stationary draft pacing,
compact layout and fullscreen recovery. See the evidence summary for exact
counts and results.

```sh
python tools/validate_orbit_center.py \
  --godot /absolute/path/to/godot \
  --reference-root /absolute/path/to/fresh-accepted-main-source-archive \
  --output-dir /absolute/path/to/new-evidence-directory \
  --renderer forward_plus
```

Repeat with `gl_compatibility`. The reference directory must be a disposable source
archive; the validator copies only its two test drivers there. Existing camera
orientation, render-pacing, field-session, viewer-status, shell, fullscreen/edge
reveal, and preset suites supply broader focused regression coverage.

Final native results (each entry: checks passed, zero assertion failures):

| Suite | Forward+ | Compatibility |
|---|---:|---:|
| Camera tumble | 13,044 | 13,044 |
| Render pacing | 290 | 290 |
| Field session | 342 | 332 |
| Viewer status | 257 | 257 |
| Viewer shell | 667 | 667 |
| Edge reveal / fullscreen | 210 | 210 |
| View preset | 826 | 766 |
| Orbit-center editor | 829 | 829 |

Candidate total: **32,860 native checks**. Accepted-main camera/pacing/field/status
runs passed 27,856 checks, plus 408 per renderer for the direct reference probe.
Each renderer matched 300 camera states and 72 requested/committed-clock,
rate, buffering, preparation-range/count/coverage and pacing observations.
Locked and orbit video each matched two PNG frames and complete timing sidecars
against main; eight short exports (four reference/four candidate) succeeded.
Normal screenshots matched with/without a pending draft in all six scenes.
All 34 candidate idle/pause phases and six stationary-editor phases per renderer
recorded zero draws. Baseline Compatibility's mixed Performance-panel phase had
one draw; all other baseline idle phases had zero. This remains within the
existing <=4 acceptance bound for live diagnostics.

Strict verification passed all 12 complete candidate SSC fixtures (80 records),
including payload checksums and field statistics. Source hashes remained unchanged.
The [source comparison](evidence/issue-120/restart/source-contract.json) verifies
175 protected files and eight camera/pacing functions match main exactly.
Representative screenshots: [Forward+ dark](evidence/issue-120/restart/forward_plus-dark.png),
[Compatibility dark](evidence/issue-120/restart/gl_compatibility-dark.png),
[white contrast](evidence/issue-120/restart/gl_compatibility-bright.png), and
[compact editor](evidence/issue-120/restart/forward_plus-compact.png).
The white contrast screenshots use a test-only white backing beneath the gizmo;
the normal dark screenshots retain the rendered scientific scene.

All final runs passed. Initial harness/import corrections and their failures are
recorded in [the regression summary](evidence/issue-120/restart/regression-summary.json).
The status suite emitted its two known encoder-PID cleanup diagnostics per run,
on both main and candidate; the existing validator explicitly permits those
specific diagnostics. No new engine diagnostics appeared in the focused editor
or export runs. These existing cleanup messages were not changed by #120.

These checks use small complete synthetic files on Linux/NVIDIA; they are not
production-file throughput or RAM claims. Subjective handle/radius feel and
other platforms require owner review.

## Owner review

Try an off-center structure, such as `(1300, -100, 3439)`, using both typed values
and XYZ handles. Check coarse/fine radius control and whether the wire guide is
clear without obscuring the structure. Apply, then immediately drag, zoom, enable
Auto Orbit, and move with Free camera. Repeat at another scale. Cancel another
proposal and verify the accepted view is unchanged unless you navigated it.
Check Frame/Reset, fullscreen, playback and a screenshot. This candidate remains
unmerged; acceptance belongs to the owner.

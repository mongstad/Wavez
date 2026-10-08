# Issue #212 — Lock Position owner-review refinement

Candidate **v0.1.0.78**, pending owner review in PR #301. This revision continues
the exact branch `212-ux-nav-make-edit-orbit-center-view-relative` from submitted
commit `48b5383667fc9b8d7636281cca9f4fd87257eb0c`. Accepted main remains
`6bd497d60c75c435f38cdffe1dd87d8cdd56bc97` / build 77 (PR #300).
The issue is **In review**; the owner's explicit changes request authorizes this
revision. The [initial Ready-issue report](../README.md) remains unchanged.

## Diagnosed cause

The draft was already a separate, stationary world-space point. There was no
per-frame assignment copying camera position/target into it. The camera's
navigation pivot was the mutable `camera_target`: RMB correctly steers in place
and updates that target, and Free Camera translates it. Subsequent LMB/held
orbit and zoom therefore operated around a different point from the draft.
Faint projected radius rings supplied little depth information in a close-up field.

A probe before implementing the fix, repeated against an immutable archive of
the submitted commit, completed **4 checks / zero failures**. Draft XYZ `(0,0,0)`
and radius `12` stayed exact. RMB moved the navigation pivot to approximately
`(4.054643,3.569182,-2.981157)`; the following LMB changed camera distance to the
draft from `12` to `8.690099`. See [cause report](cause.json), [clean probe log](cause.txt)
and [probe source](cause-probe.txt). The first probe's non-isolated user log/file
dialog preference paths were unwritable; the isolated archived run has no diagnostics.

## Implemented behavior

**Lock Position** anchors placement orbit and zoom to the editable draft. Toggle
On/Off retains the actual current pose, including an off-axis view after RMB.
The small guarded hook in `_update_camera()` applies the existing orientation
delta to the camera's actual offset about the draft, scales it for zoom and adds
Free Camera translation. It synchronizes the ordinary camera target representation.
It runs only while this visible editor is locked; ordinary navigation uses the
existing path. RMB's in-place steering implementation/sensitivity stays unchanged.

Camera movement never rewrites draft XYZ/radius. Captured-view handles, absolute
numeric XYZ, radius edits and Place ahead stay functional while locked; explicit
center edits become the anchor for subsequent motion. The lock starts Off per
session, ends on Apply/Cancel and is excluded from saved presentation state.
Apply retains the full current basis and commits the exact draft radius;
Cancel restores the complete pre-edit camera/navigation state.

The radius is an opaque shaded sphere in a separate annotation world, composited
at 84% over the field with a bright rim. Dense field opacity cannot hide it or
its world-aligned rings/X/Y/Z diameters. The annotation never shares scientific
geometry or its depth buffer. It redraws on change with `UPDATE_ONCE`, and is
disabled on dismissal. A persistent upper-left world XYZ/radius readout remains
visible with controls collapsed and identifies views inside the radius. From
inside a large sphere the silhouette can be outside the viewport; Free Camera
can move outward to inspect its full boundary. Captured-view handle endpoints
stay distinct when projected directions become foreshortened or overlap.

Current usage and exact owner steps: [Auto Orbit placement](../../../ORBIT_CENTER_VIEW.md).
Current Auto Orbit, handbook and status documentation are synchronized; old
evidence and documentation-audit reports retain their historical wording.
Build 78 stays unchanged through this review commit.

## Completed checks

The refinement exercises **16 scene/scale/mode cases** (particles, fields, meshes
and mixed × small/large scales differing by 100,000 × normal/Fullscreen), plus
two dense-field view sequences. Real viewport-routed Lock Position, LMB, wheel
and handle gestures are checked alongside RMB, held orbit and all six movement
keys. Assertions require actual camera motion, exact locked draft values,
editing after navigation, lock/unlock without a snap, Apply/Cancel, serialization
exclusion, unchanged scientific transforms and committed samples. Dense 32³
fields use opacity strength 10 and cover close-up/side views, collapsed controls,
and large-radius interior/exterior. Native image sampling confirms a substantial
opaque sphere area with thousands of distinct shades.

| Run | Result | Report / log |
| --- | --- | --- |
| Refinement, headless | **1,278 PASS** | [report](headless.json), [log](headless.txt) |
| Refinement, native Forward+ | **1,290 PASS** | [report](forward.json), [log](forward.txt) |
| Refinement, native Compatibility | **1,290 PASS** | [report](compatibility.json), [log](compatibility.txt) |
| Linux release validation package, Forward+ | **1,290 PASS** | [report](package-forward.json), [log](package-forward.txt) |
| Same compiled package, Compatibility | **1,290 PASS** | [report](package-compatibility.json), [log](package-compatibility.txt) |
| Original #212 matrix, headless | **3,472 PASS** | [report](retained-view.json), [log](retained-view.txt) |
| Connected Auto Orbit, headless | **364 PASS** | [report](connected-auto-orbit.json), [log](connected-auto-orbit.txt) |
| Version / Python checks | **2 unit tests PASS**, candidate v0.1.0.78, runner compiles | `tests/test_application_version.py` |
| Strict generated-fixture verification | **9 captures / 25 records PASS** | [report](strict-verification.json) |
| Protected source/history comparison | **1,967 files byte-identical** to submission | [report](source-contract.json) |
| Normal production Linux release export | **PASS** | [manifest](production-release-build.json) |
| Documentation / branding checks | **PASS** | [documentation](documentation.json), [branding](branding.json) |

Every completed matrix checks its entire capture SHA256s remain unchanged and
reports zero runtime warnings/errors. The normal production release exports
the current resources/shader. The release validation package uses the existing
packager, production Viewer/resources and 40-file first-party Python archive,
with a temporary test entry scene because production templates ignore `--script`.
This does not claim that a normal production executable ran that script.
Executables, PCKs, captures and import caches remain outside Git under `/tmp`.

Representative screenshots, inspected at 1440×900 normal / 2560×1440 Fullscreen:

| State | Forward+ normal / Fullscreen | Compatibility normal / Fullscreen |
| --- | --- | --- |
| Close-up in dense field | [normal](forward-dense-close-normal.png) / [Fullscreen](forward-dense-close-fullscreen.png) | [normal](compatibility-dense-close-normal.png) / [Fullscreen](compatibility-dense-close-fullscreen.png) |
| Side viewpoint, same locked XYZ/radius | [normal](forward-dense-side-normal.png) / [Fullscreen](forward-dense-side-fullscreen.png) | [normal](compatibility-dense-side-normal.png) / [Fullscreen](compatibility-dense-side-fullscreen.png) |
| Collapsed controls with persistent readout | [normal](forward-dense-compact-normal.png) / [Fullscreen](forward-dense-compact-fullscreen.png) | [normal](compatibility-dense-compact-normal.png) / [Fullscreen](compatibility-dense-compact-fullscreen.png) |
| Inside large radius | [normal](forward-dense-large-radius-normal.png) / [Fullscreen](forward-dense-large-radius-fullscreen.png) | [normal](compatibility-dense-large-radius-normal.png) / [Fullscreen](compatibility-dense-large-radius-fullscreen.png) |
| Outside large radius | [normal](forward-dense-large-exterior-normal.png) / [Fullscreen](forward-dense-large-exterior-fullscreen.png) | [normal](compatibility-dense-large-exterior-normal.png) / [Fullscreen](compatibility-dense-large-exterior-fullscreen.png) |

Release package: Forward+ [close-up](package-forward-dense-close-normal.png) /
[large-radius Fullscreen](package-forward-dense-large-radius-fullscreen.png);
Compatibility [close-up](package-compatibility-dense-close-normal.png) /
[large-radius Fullscreen](package-compatibility-dense-large-radius-fullscreen.png).

## Failures and limits

Connected navigation remains **FAIL: 1,393 checks / one failure** on this candidate
and freshly rerun, byte-verified accepted main. Both fail `Real process loop
advances the held orbit shortcut` before editor usage. Candidate
[report](connected-navigation.json) / [log](connected-navigation.txt) and accepted
[report](baseline-navigation.json) / [log](baseline-navigation.txt) retain that
result. This is an identical baseline failure, not a passing suite; no unrelated
navigation fix is included. The initial report also retains its native baseline
reproduction; a new native connected-navigation run was not needed here.

[Intermediate results](intermediate-failures.json) record an incomplete test
parse attempt, three matrices with blocked normal-mode handle gestures, and two
zero-assertion-failure runs that still failed due to a reused synthetic key-event
warning. Explicit test types, a separate persistent readout/compact control
layout, unobstructed gesture locations and duplicated release events resolve
those issues in the final runs. Five unrelated UID sidecars recreated by import
cache warmup were excluded from Git; the new script/shader UIDs are retained.

Validation uses synthetic events **inside Godot**, without Python/OS input-device
control. Physical mouse feel, research-size captures, other OSes, mixed-DPI/4K,
long-session performance and video encoding were not run. The synthetic dense
field demonstrates visibility at high opacity, not universal placement feel in
every research dataset. Existing world-vector precision and camera clipping/
zoom bounds remain. Scientific data/layer/export code does not change, so
unrelated full scientific/playback/encoding suites were outside this focused scope.

## Owner verification before acceptance

1. Zoom into your dense 3D field, open the editor, place the draft and enable
   Lock Position. Confirm locking itself does not move the view.
2. RMB-steer, then LMB-tumble and use your held orbit shortcuts; zoom and move
   with W/A/S/D/Q/E. Compare persistent world XYZ/radius from multiple viewpoints:
   camera movement must leave them unchanged.
3. While locked, drag each Right/Up/Toward handle and edit numeric XYZ/radius.
   Confirm only explicit edits move the draft/change its radius, and subsequent
   orbit uses the new point. Unlock without a view snap.
4. Inspect a large radius from inside and outside, normal/Fullscreen, controls
   expanded/collapsed. Judge shaded surface, rim, world references and readout
   visibility against your field. Scientific objects must stay fixed.
5. Apply: confirm the full current orientation remains and Auto Orbit starts at
   the draft with its chosen radius. Repeat editing/navigation then Cancel:
   the exact original camera/orbit state must return.

PR #301 remains open for owner review. No merge, auto-merge, issue closure or
Project transition is performed by this revision.

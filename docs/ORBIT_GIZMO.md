# Orbit-center placement (#212)

Candidate build **v0.1.0.78**, based on accepted main `6bd497d` (PR #300).
This is the second implementation attempt, pending owner review. The discarded
PR #301 is investigative evidence only, not an implementation base.

Choose **Navigate → Edit orbit center…** (the Navigate shortcut also
opens that menu). The camera remains usable while the editor is open.

- **World X/Y/Z** are the authoritative center in viewer-world units.
- **Right / Up / Toward** handles use the camera axes captured at editor entry.
  They do not change axes as you fly around. Handles extend 1.4 radii from the
  center. An end-on axis has no usable screen projection; turn the camera to
  expose it or enter world coordinates. Thin XYZ references and the three
  great circles use the actual world radius.
- **Radius** is independent of center and placement depth. Radius 1 means
  exactly one viewer-world unit. The −/+ and wheel controls retain their
  25% coarse / 2% Shift fine steps. There is no scene-relative enlargement cap;
  the existing finite numeric range is 0.000001–1e15.
- **Place ahead depth** is a positive world-unit distance for the next placement.
  Editing depth alone does not move the existing draft. **Place ahead** sets
  `center = camera_world_position - camera_world_back_axis * depth`, preserves
  radius and camera pose, and releases keyboard focus for immediate W/A/S/D/Q/E.
- Flying, steering, tumbling, orbiting, zooming, or changing camera speed never
  edits center, radius, or placement depth. The projection naturally moves on
  screen. There is no camera-follow or screen-lock mode.
- **Apply** commits the exact center and radius, keeps the current view direction
  and up axis, and positions the camera one radius behind the center. Auto Orbit
  then travels around that center on the equator perpendicular to this up axis.
  Repeated unchanged Apply does not reparse the display text or reposition the
  camera. Intentional camera navigation retains the accepted controls; a changed
  camera pose/target/radius invalidates the Apply-time automatic orbit plane.
- **Cancel**, **×**, and **Escape** restore the complete pre-edit camera pose,
  target, radius, orientation representation, and Auto Orbit / Free Camera modes.
  Escape dismisses this editor before fullscreen recovery. Another Escape retains
  the normal fullscreen behavior.

## Initial scale and depth

On the first placement, finite current particle positions, mesh vertices after
`data_to_world`/node transforms, and the eight transformed grid-domain corners
supply viewer-world bounds. Hidden mesh/grid views are excluded. This scans
current geometry once at editor entry; it does not reload a capture or change
scientific data. Bounds describe the full current geometry/domain, not a picked
surface or automatic local-feature detector.

Let `D` be the world-bounds diagonal, and `H(depth)` the world half-height visible
at the proposed placement depth. Initial radius is
`max(0.000001, min(0.04 * D, 0.12 * H(depth)))`.
Thus diameter is at most 8% of the world diagonal, except at the existing minimum
numeric radius. A close camera further reduces the default. Disconnected lobes
share bounds; point the camera toward the desired lobe and refine center/depth.

Depth starts at the forward projection of the bounds center from the current
camera. If that center is behind/too close, it uses half the world diagonal.
Depth is never less than `max(4 * near, 0.00001)`. Empty/degenerate geometry uses
`max(4 * near, 1)` depth and 4% of that depth as radius. Reopening an applied orbit
with its unchanged target/radius preserves the exact chosen values instead of
reinitializing them.

The shaded sphere is a unit `SphereMesh` (`radius=1`, `height=2`) scaled uniformly
by the draft radius and translated to the draft world center. Its separate
annotation World3D contains no scientific geometry. The annotation camera copies
the production camera transform, perspective/orthographic/frustum projection,
FOV/size, near/far, aspect policy, offsets, and viewport dimensions before drawing.
No arbitrary pixel radius or hidden scene scale is applied. Perspective pixel
size varies with depth; orthographic pixel size follows camera size. The world
values remain unchanged. An inside-sphere view hides the opaque surface and
explicitly says so, retaining guides and the numeric readout.

The editor and annotation are excluded by the existing image-export chrome
filter. Offline workers never instantiate the editor. The Apply-time plane is
transient live navigation state; this issue adds no preset, capture, or video-job
schema. Saved camera transforms retain their established contract; an offline
orbit uses the established offline orbit behavior.

## Navigation preservation and review

The six movement keys, RMB steering, LMB tumble/invert-Y, wheel zoom, held orbit,
speed adjustment/persistence, cinematic background, and scientific transforms
keep their accepted production functions. Default `R` remains Reset Camera;
held Orbit Camera Left/Right are configurable and unbound in a fresh profile.
Owner R/T mappings are preserved. There is no separate middle-button drag zoom
handler in accepted `main`; wheel behavior is unchanged. Physical device mapping
and the owner's middle-button workflow must be verified with the actual profile.

See [the second-attempt evidence](evidence/issue-212/attempt-02/README.md) for
measurements, renderer/package results, exceptions, and exact owner checks.
Synthetic tests do not establish physical acceptance on a research-scale scene.

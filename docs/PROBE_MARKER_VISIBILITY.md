# Source-probe marker visibility

Issue #32 proposes this treatment in candidate `v0.1.0.74`, pending owner review.
[Focused evidence](evidence/issue-32/README.md) records native comparison scenes,
state/PNG/video checks and remaining owner verification. The historical
[UI-004 report](PROBE_MARKER_VALIDATION.md) remains an implementation-time record.

The source-probe marker is an orchid (`#ef8fff`) three-axis cross with a dark navy
(`#182033`) outline. A three-pixel core sits within a seven-pixel total stroke,
with antialiased edges. The core remains visible over black/empty space; the
outline separates it from bright particles and field colors. Orchid was selected
after comparing the former white lines and orchid/cyan/gold outlined treatments
over sparse and 20,000-particle scenes and viridis, plasma, coolwarm and turbo
fields, including the default Cinematic preset. Gold is close to the UI's warning
color and blends more with warm field colors; cyan competes more with blue/cyan
field structure. The outlined orchid
treatment showed useful separation in the tested scenes. It is fixed annotation
ink, independent of scientific lookup tables and operational status colors, and
does not encode magnitude, sign, category or the sampled value.

The cross keeps its last explicit world-space center and its original ±0.35-world-
unit arms. A canvas annotation projects those endpoints through the existing
camera and draws after 3D bloom/fog, below application UI. Dense foreground
content cannot bury the annotation or wash out its outline. This foreground
appearance does not indicate that the probe lies on the nearest visible surface.
Other scientific materials,
normalization, colormaps, sources and render settings are untouched. No source
resampling or input handling is added. On an existing render, a cached camera,
projection, viewport and owner-transform key updates canvas commands only when
the projection changes. There is no Node process loop or repeated idle redraw.
Near-plane crossings are clipped before projection; a point behind the camera
has no phantom marker. See Godot's [camera projection](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#class-camera3d-method-unproject-position)
and [canvas layer ordering](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html).

Use **Tools → Source probe** to sample the selected volume at explicit world
coordinates. **View → Probe marker** is the existing independent visibility
action. It hides/restores the last valid marker without clearing coordinates,
the source result or geometry. Playback and seeking retain that explicit probe;
they do not move it or recompute its result. Probing while hidden updates the
result but keeps the marker hidden. An unavailable probe cannot restore a stale
cross. Reopening a capture resets the session: visibility enabled, no marker
until the first valid explicit probe.

Screenshots reflect the current visibility. Recipes and PNG sidecars do not
serialize this session-only marker, although restoring a recipe in the current
session preserves its existing probe context. Deterministic video starts a fresh
viewer and excludes the marker regardless of interactive visibility. These
contracts are unchanged by styling.

Native validation covers both renderers, representative synthetic scenes and
short video exports. Large external research captures, release packages,
physical-input review, mixed-DPI/4K and prolonged sessions remain untested.
Pixel width refers to the rendering viewport, not a physical-size guarantee
across desktop display scaling. World arm length retains its existing scale
behavior; at extreme zoom or very large scene scales the arms can become short.

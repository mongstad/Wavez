# Issue #40 — revised visual review

**Static high-fidelity proposals, pending owner review.** These supplement and
supersede the original issue-14 schematic **visual/copy direction**. They are not
native viewer screenshots. Scene marks, source names, values and plots are
illustrative. No new scientific rendering is proposed or validated.

Start with the [visual/copy specification](../../UX_VISUAL_LANGUAGE.md), then
compare the images at 100% native size. The
[semantic architecture](../../UX_INFORMATION_ARCHITECTURE.md),
[control map](../../UX_CONTROL_MAP.md) and
[original workflow research](../../UX_IA_REVIEW.md) remain the other review inputs.

| Static mockup | What to inspect |
|---|---|
| [Loaded scene](scene.png) | Visible workspaces; structured selected-object header; visibility separate from row selection; Source probe |
| [Particle appearance](particle.png) | Representation, Color, Display filters and Recorded history; no mixed volume controls |
| [Volume appearance](volume.png) | Clean Color/Opacity headings, independent fields, badges and source metadata |
| [Volume continuation](volume-details.png) | Local scroll with fixed context; reset mapping, strength, Volume quality and derivative disclosures |
| [Faint: inherited inputs](faint-inherited.png) | Choosing Faint retains 0–100 from Dense core; current mappings remain unchanged |
| [Faint: edited inputs](faint-edited.png) | Explicit 1–99 choice, focus treatment, adjacent Apply and prospective clipping notice |
| [Signed field](signed.png) | Symmetric/Locked color; independent magnitude thresholds; manual 0.01 threshold example |
| [Selection](selection.png) | Explicit source binding, source object, exact ID above 2^53, primary Create action |
| [Analysis](analysis.png) | Analysis type selector without duplicate heading; Use full range action; units and inclusive range |
| [Results](results.png) | Temporary expanded workbench, source/request provenance, bounded table and full numerical export |
| [Compact 1024×640](compact.png) | 48-pixel command bar with 8-pixel control padding; desktop chooser, readable labels, adjacent inputs/Apply and persistent transport/Jobs |
| [Mesh appearance](mesh.png) | Neutral mesh context, scalar colors and wireframe only |
| [Controls and menus](components.png) | Real action hierarchy, recipe/setup menus, provisional 29-icon family, focus, invalid draft, disabled reason, probe metadata |
| [Different requested time](time-difference.png) | Displayed 200 versus requested 220, visible preparation state; no invented source advance |
| [Seek target](seek-target.png) | Editable target 240 in a separate Seek time form; read-only displayed time remains 200 |
| [Quick setup details](quick-setup-details.png) | Heading info opens concise details and handbook link; no extra What changes button |
| [Focused color details](color-details.png) | Concise secondary help, close control and handbook route |

![Signed color and opacity](signed.png)

![Faint structure setup](faint-edited.png)

![Compact layout](compact.png)

![Controls, icons and copy](components.png)

## Exact owner review

1. At 1440×900, identify all four workspaces, the selected object, its type,
   visibility, channel and source time without reading a paragraph. At 1024×640,
   inspect the compact chooser and transport without shrinking the image.
   Check 48-pixel command bars, 8-pixel vertical padding and centered contents.
2. Compare inherited and edited Faint views. Confirm that choosing Faint does not
   replace 0–100 with 1–99; Apply is beside both inputs, and manual fields below
   remain authoritative. Inspect the setup menu's positive/negative requirement.
   Use only the heading info action for its one-sentence hover/focus summary and
   concise clicked details with a handbook link.
3. In the signed and volume-continuation views, distinguish color range, opacity
   thresholds, strength and ray step. Verify Locked is metadata, not a disabled
   editor or a persistent preset. Check reset labels against their narrow scopes.
4. Compare ordinary transport with the requested-time example. Confirm the index
   is a union index, time/rate units are understandable, Jobs stays reachable, and
   displayed time is read-only. In Seek time, Target 240 is editable while
   displayed time stays 200; Go submits, Cancel does not. Pending requested time
   is distinct from both the displayed sample and an unsubmitted draft.
5. In Selection/Analysis/Results, distinguish object context from scientific
   membership and explicit source binding. Check the exact ID, inclusive range,
   units, support, full-result export and Return to viewport.
   Confirm the Analysis type selector has no repeated Population counts heading
   and the immediate action says Use full range.
6. Inspect the component sheet: primary versus secondary actions, menus, icons,
   focus clearance, readable disabled reason, persistent error and old probe time.
   Confirm that short details supplement rather than conceal essential warnings.
7. Review sentence case, neutral names (Particles, Scalar field, Mesh) and the
   old/revised wording table. Confirm desktop keyboard and mouse/trackpad scope;
   compact is not a mobile design. Icons remain provisional, with native quality
   review in UX3 and final artwork refinement in UX8. Decide
   whether this visual/copy direction is acceptable before authorizing production
   work. Visual approval does not implement or accept UX3.

## Reproduction and focused checks

From the repository root, using the existing Python environment with Pillow:

```sh
python docs/evidence/issue-40/render_mockups.py
python docs/evidence/issue-14/check_review.py
python docs/evidence/issue-40/check_review.py
```

The generator reads the current theme tokens and existing bundled numeric font.
`UX_MOCKUP_FONT` and `UX_MOCKUP_BOLD` can point to installed body/heading fonts;
the recorded run uses Noto Sans Regular/Semibold. No third-party asset, font,
dependency, capture or runtime is added. The SVG sprite is original documentation
art; existing UX2 icon geometry is retained for compatible commands. The final
refinement changes placement only; the icon sprite is byte-for-byte unchanged.

[Layout evidence](layout.json) records image hashes, labels and control rectangles.
[Verification](verification.json) records scope checks, images,
control bounds/overlaps, 48-pixel bar padding, font-reference/optical alignment,
sentence case, neutral copy, read-only time and navigation coverage, theme identity
and contrast arithmetic. These assertions support a manual review, not replace it.
The [original checker](../issue-14/check_review.py) still checks all 96 control
entries and their source symbols. Original native evidence and historical reports
are retained without altering their recorded measurements.

Final refinement results: 17 images, 29 unchanged provisional icons, 525 controls
checked for bounds/non-overlap/desktop target size, 504 font-reference alignment
checks and 20 token contrast pairs passed. The architecture checker passed
260 local links/anchors and all 96 inventory/source-symbol entries. Deterministic
regeneration passed with identical image hashes and layout records.
The prior revision's clean Godot 4.7.2 import remains historical validation;
this refinement changes no engine inputs and does not repeat that import.

The 17 mockups were rendered and visually inspected. Earlier development review corrected
touching range controls, footer clearance, compact transport spacing, a prospective
clipping warning shown for 0–100, and a sample selection/result inconsistency.
Final figures use independent illustrative request states explicitly identified
above. Repeated generation should preserve the recorded hashes in the same font
environment.

Not rerun for this design-only revision: native viewer interaction or scientific
tests, native backend comparisons, capture hashing, export, solver, usability
timing, screen-reader, physical 4K or mixed-DPI checks. Old 4K schematic allocations
remain historical and do not validate this new visual treatment at those scales.
No runtime accessibility or scientific performance claim is made. Native
pixel-perfect alignment remains UX3 validation. Desktop keyboard accessibility,
focus, scaling, contrast and usable pointer targets remain required. Touch-first
controls, touch gestures, tablets, mobile navigation and touchscreen-specific
sizing are excluded until a separately authorized future milestone.

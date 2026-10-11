# Volume display starting points — VOLUME-001

Issue #10, **UX4 — Panels & Information Architecture**. Implemented for owner
review, not yet owner-accepted. This report records the review-time evidence.

## Scope and control meanings

These opt-in actions build on independent opacity (#11) and frozen color policies
(#12). They change display state only. Opening a capture still uses the existing
linear color and opacity 0–1 defaults; no channel name is interpreted as a
scientific quantity and no automatic universal range/preset is selected.

In **Scene layers → Settings: <volume>**, choose a channel and a **Volume display
preset**, read its description, then click **Apply volume display preset from
sample**. Selecting an action alone changes nothing. Expand **What do these
controls change?** for the distinctions:

| Control | Meaning |
|---|---|
| Color range / normalization | Scalar-to-color coordinate; endpoint clipping and linear/log mapping are explicit. Color edits alone never change opacity. |
| Opacity mapping | Independent scalar or absolute-scalar ramp between zero/full-extinction thresholds. This is not calibrated physical opacity. |
| Opacity / world unit | Strength multiplying that ramp; “full” threshold reaches this strength, not necessarily an opaque pixel. |
| Ray step | Integration quality/cost in world units, not a brightness control. Smaller steps cost more; larger steps can miss structure. Existing 1024-step cap and early termination remain. |
| Particle visibility | Independent overlay that can dominate/obscure the field. Hide particles explicitly for field-only review. |
| Scene Viewing preset | Existing presentation/background and particle-style behavior; separate from volume display actions. Scientific removes decorative effects. |

Manual controls remain available. Presets preserve opacity strength, ray step,
particle visibility/style, camera, scene viewing preset/environment, other layers,
volume/slice/clip/isosurface settings, scientific source arrays, clocks and probes.

## Exact preset contract

Let `m`/`M` be the finite extrema of the currently loaded source channel/sample,
`B = max(abs(m), abs(M))`, and `Q(p)` its finite-value percentile using the existing
linear interpolation between sorted samples. The existing worker copies source
values before sorting; it never modifies the source array.

| Optional action | Eligibility | Frozen color | Colormap | Frozen opacity mapping |
|---|---|---|---|---|
| Dense core • full range | Nonnegative finite values, `M > m`, `M > 0` | Linear `[m, M]`, percentile policy 0–100 | viridis | Linear `[0, M]` |
| Faint structure • chosen percentiles | Nonnegative finite values, nonconstant chosen range, positive upper endpoint | Linear `[Q(low), Q(high)]`, chosen percentile policy | viridis | Linear `[0, Q(high)]` |
| Signed field • symmetric | Finite values on both sides of zero | Linear `[-B, B]`, symmetric policy | coolwarm | Magnitude `[0, B]` |

Faint structure uses the **current percentile entries below**, not a hard-coded
universal 1–99 range. The action description displays their current numbers and
updates as they change. Enter the intended percentiles explicitly before applying
it. For example, Dense core populates 0–100; subsequently choosing Faint structure
without editing them deliberately retains 0–100. The reviewed 1–99 and 5–95 choices
are examples, not recommendations for every dataset.

The action explicitly changes **both** color and opacity thresholds. In Faint
structure, a lower full-opacity threshold increases the extinction weight of
fainter values; strength is not silently raised. Values above that threshold
reach the existing strength, and colors above the chosen upper percentile clip
to the endpoint. The existing color status reports actual clipping at the current
sample; the opacity controls expose the resolved thresholds. Saturated cores and
occlusion are expected tradeoffs, not new scientific findings.

All actions select **linear** color, including when the prior view was logarithmic.
No preset silently selects log. The controls disclose the resulting normalization,
frozen policy, derivation channel/time, source extrema and clipping. Invalid,
constant/zero-only or ineligible data refuse without partially changing settings;
manual controls remain the fallback. Nonfinite values are excluded from the range
calculation using the existing finite-value policy. Float32 color and opacity
validation must both pass before any result is applied.

The action selector is not an active rendering mode. Resolved values, not its
label, define the view. There is no new saved preset ID or recipe format. Existing
v2/v3 state and video jobs save `lower`, `upper`, `color_mapping`, `opacity_mapping`
and `colormap`; playback/restore never recomputes the preset. Manual edits remain
authoritative. Legacy recipe migration is unchanged.

The existing one-worker, 8,388,608-source-value range limit and physical-memory
headroom check apply. Concurrent range actions refuse; changed sample/generation,
channel/settings or recipe restoration invalidate pending results. A bounded
worker is joined on close. No interval scan, renderer/shader change, interpolation,
new opacity law, panel restructuring or new default is included.

## Candidate evaluation

Dense core provides unclipped **scalar color bounds at the selected sample**,
not guaranteed unsaturated compositing or visibility of weak tails. Faint structure
provides an explicit visibility-versus-saturation choice. Signed field separates
signed color from magnitude extinction and avoids a nonzero extinction weight at
scalar zero. Their suitability remains capture-, camera- and strength-dependent.

A separate **Balanced** preset was not added: one simulation family does not
establish a balanced universal range or strength. **Scientific / linear** was
not added as a second ambiguous volume label: all three actions explicitly use
linear color, while the existing Scientific scene preset remains separate. Users
can retain any manual linear bounds without applying an action. No universal
percentile/symmetric opening default is justified by this evidence.

## Validation and evidence

Validation uses Godot 4.7.2 on Linux, NVIDIA GeForce RTX 3070 Ti, Forward+ and
Compatibility. The generated fixture contains two compact density lobes and
opposite-signed fields at two timestamps with different amplitudes, plus zero-only
refusal coverage. Independent Python/NumPy calculations supply extrema, percentiles,
source array hashes and world-coordinate probe oracles.

The focused suite covers UI selection versus application, disclosed percentile
inputs, resolved ranges/opacity/colormap, all other saved display fields unchanged,
manual independence, frozen seeking, stale results after a seek/manual edit,
incompatible/zero/invalid input refusal, serialized restoration and pixel equality.
A real capture additionally exercises a visible particle overlay with Cinematic
presentation while asserting preset isolation. Three actual MP4 still exports per
run reproduce the Dense core, Faint structure and Signed field reference PNGs
exactly **before lossy video encoding**; inspection sidecars retain resolved state.

The external capture is read-only, not bundled or rerun:

- File: `free_collapse_simscope.ssc`, run `S2_20260919_204505_268717`.
- 11,542,897,957 bytes; SHA-256
  `0805d497ad0f69440f3aa7ac30d6cfe9642a4efd142ae406d3a685b595d7d3f5`.
- Field `free_collapse_field`, 128³ cells; `density`, `psi_real`, `psi_imag`.
- Presets derived at time 200; frozen behavior checked at time 0 and back.
- Real serialized visual state is validated/applied without repeatedly hashing
  the large file for each view; full source-bound recipe restore uses the small
  synthetic fixture. Full capture hashes before/after each real run verify bytes.

Observed density Dense core bounds are `[0, 1.7196707725524902]`, with the same
upper opacity threshold. The 1–99 Faint structure bounds are
`[0, 0.05876532409340133]`: larger bright regions/weak outskirts become visible but
cores visibly saturate. Signed field uses color ±`1.2984671592712402` for `psi_real`
and ±`0.9747978448867798` for `psi_imag`, with matching positive magnitude opacity
thresholds. Signed views show core/halo structure without an opaque whole-domain
box. These are useful starting choices on this sample, not calibrated or universal
interpretations. The synthetic opposing lobes exercise both signs distinctly.

| Validation | Result |
|---|---|
| Synthetic preset suite, Forward+ / Compatibility | 99 / 99 checks PASS |
| Real preset review, Forward+ / Compatibility | 94 / 96 checks PASS |
| Preset export comparisons | 12 still exports complete; all reference PNGs identical; sidecars preserve state |
| Existing recipe suite, headless | 3,051 checks PASS |
| Existing normalization suite, Compatibility | 130 checks PASS; still export matches; invalid-log export correctly refused |
| Existing opacity/ray-step suite, Forward+ | 98 checks PASS; analytic step/opacity checks and still export pass |
| Final viewer import | PASS, no errors/warnings; new UID sidecars included |

Real Forward+ predates two UI-only additions: percentile-description assertion and
expanded-help screenshot. Both passed on the final synthetic runs and real
Compatibility. Source and display mapping behavior was unchanged by those additions.
Exact reports and run details are in [the evidence summary](evidence/issue-10/summary.json).
Retained PNGs show representative real views and the controls; reports contain
resolved settings and independent source oracles. Captures, MP4s, caches, all
intermediate frames and redundant screenshots remain untracked under `results/`.

Reproduction:

```sh
python tools/validate_volume_presets.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /new/output/directory
# Optional read-only integration: --real-capture /absolute/path/to/capture.ssc
```

## Limitations and skipped checks

One real simulation family and one GPU/OS were available. No claim is made about
other scientific families, other GPUs/OSes, physical 4K/mixed-monitor layouts,
long-session comfort or universal performance. No formal usability study or new
performance benchmark was run. The full G0–G4 suite and scientific solvers were
not rerun; focused existing mapping/recipe regressions cover shared behavior.
Automated export checks use stills, not a moving-camera/long-duration movie.

Opening defaults remain unchanged. Useful starting views require an explicit
preset choice on eligible source values; automatic classification is intentionally
absent. Sparse channels can produce a constant percentile range; they refuse,
rather than inventing a scientifically suggestive fallback. Larger-than-limit
fields need manual controls. Faint structures may remain obscured by strong cores,
particles or the preserved strength/camera. User judgment is still required.

The first editor import was sandbox-blocked (socket/settings access); its authorized
rerun passed. An early test incorrectly expected 1–99 after Dense core set 0–100;
it was corrected to explicitly enter its intended percentiles. An added UI-label
assertion initially omitted Godot’s `.0` decimal formatting and was corrected;
the displayed percentile values themselves were correct. Final checks and
any remaining unavailable results are listed in the evidence summary.

## Owner verification before acceptance

1. Open the real capture, select Scientific presentation and explicitly hide
   particles. Select the field's `density` channel at time 200. Read the expandable
   control explanation. Apply Dense core and inspect the exact color/opacity
   bounds above. Strength and ray step must retain their prior values.
2. Choose Faint structure. Set lower/upper percentile entries to 1/99; verify
   its description reads P1–P99 before Apply. Check the resolved upper bound
   `0.05876532409340133`, visible COLOR CLIPPING PRESENT warning, brighter outskirts
   and saturated cores. Try 5/95 and review that deliberate tradeoff.
3. Select `psi_real`, apply Signed field and verify symmetric ±`1.2984671592712402`,
   coolwarm and magnitude opacity `[0, 1.2984671592712402]`. Repeat `psi_imag` with
   ±`0.9747978448867798`. Confirm sign remains color information and zero-opacity
   space does not become an opaque box. A density preset on signed data must refuse.
4. Seek to 0 and back; bounds/provenance remain frozen while source-range/clipping
   disclosure follows the sample. Probe a recorded grid location before/after a
   preset; its numerical value and source time must agree. At world
   `[0.25, 0.25, -0.25]` at time 200, density is `1.5568903684616089`,
   psi_real is `-1.04829740524292`, and psi_imag is `-0.6767295598983765`
   (allow display-coordinate precision). Edit color manually,
   then opacity: each remains independent. Change ray step for detail/cost, not
   brightness; inspect thin structures for sampling artifacts.
5. With particles visible and Cinematic selected, apply a volume preset and
   confirm neither setting changes. Save/reload an inspection recipe after manual
   adjustments; verify the resolved view, controls, camera and probe session state.
   Export a short locked-camera clip and compare it with the viewer.
6. Inspect help, action descriptions, numeric entries and clipping at your normal
   desktop scale on the renderer you use. Confirm that the action selector is
   understood as a one-time action, not a continuously active normalization mode.

Owner controls acceptance, merge and Project-board status. Later panel information
architecture may improve placement of this guidance, but it is outside this issue.
Further families should inform any future default/preset calibration; no later
issue is implemented here.

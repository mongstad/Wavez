# Volume opacity in legend overlays

Enable **Show legend** for a scalar volume under its Color Mapping controls.
The existing object/channel, colormap bar and color range retain their content.
A compact third row reports the renderer's applied opacity state, for example:

```text
Opacity: strength 0.18 • magnitude [0.1 → 2.0]
```

The number is the existing **Opacity strength**: maximum display extinction per
world unit, not a uniform pixel alpha or calibrated physical measurement. The
row also identifies the independent opacity ramp: **linear** uses the scalar;
**magnitude** uses its absolute value. The bounds are the zero- and full-strength
thresholds. A single strength alone would not describe this transfer mapping.
See [opacity control semantics](VOLUME_OPACITY_MAPPING.md).

The legend reads the volume material's already applied strength, mode and
threshold uniforms. It does not maintain separate opacity state, alter the
renderer, or derive new scientific quantities. Existing strength/ramp edits
update the text through the existing resample/legend synchronization path.
Changing channel, colormap or color bounds still reports those values separately.

A slice-only view reports **Opacity: opaque slice**, because the existing slice
renderer does not apply volume extinction. When volume and slice are both
visible, the row includes the volume mapping and an **opaque slice** suffix.
Particle and mesh legends remain unchanged. Legend defaults, per-object
visibility, eligibility, spacing, width and bounded scrolling remain unchanged;
volume cards gain one compact row and continue to wrap long values.

Screenshots and video with enabled legends include this row. The existing video
**Overlays** gate still excludes all legend cards when switched off. The stack's
existing height/scroll limits apply; overflowing cards are not all visible in one
frame. Enable the relevant legend and review the output framing before export.

Issue #281, candidate **v0.1.0.72**, pending owner review.
[Focused renderer, layout and video evidence](evidence/issue-281/README.md)
records verified results and owner checks. Earlier legend reports describe their
original two-row volume cards and remain historical records.

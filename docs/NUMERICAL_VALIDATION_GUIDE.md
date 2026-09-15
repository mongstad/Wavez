# Numerical validation guide

This is a reusable checklist for simulations visualized with SimScope. SimScope is
not the scientific solver and cannot establish physical correctness from an image.
Keep solver validation, visualization mapping and interpretation separate.

## Validation ladder

1. **Freeze the continuum/model contract.** Record equations, coefficients, initial
   data, forcing, boundaries and intended invariants before comparing numerics.
2. **Define the discretization.** State spatial operators, closure, precision,
   layout, backend and stability limits.
3. **Preserve a baseline.** Keep the accepted operator/configuration selectable
   while testing alternatives.
4. **Use symmetry and negative controls.** A symmetric case is useful for exposing
   grid anisotropy; a visually interesting result is not a control.
5. **Check temporal convergence.** Reduce the physics timestep without changing the
   physical problem or output cadence.
6. **Check spatial refinement.** Hold the physical domain/model fixed while reducing
   grid spacing and compare at matched physical times/apertures.
7. **Separate interior from boundaries.** Increase domain size at fixed resolution
   where practical and track absorber/boundary contact explicitly.
8. **Use common physical diagnostics.** Keep cutoffs, masks, apertures and units
   fixed across compared resolutions/operators.
9. **Preserve exact scientific fields.** Rendering previews, LOD textures and
   colormaps are not substitutes for source arrays.
10. **Report what has not converged.** Stable timesteps, small conservation residuals
    or attractive morphology do not by themselves establish a converged solution.

For visual comparisons, freeze camera, physical extent, colormap, numeric range,
linear/log transforms, slice policy and opacity/transfer settings. Record held
source times rather than silently treating sparse field samples as continuous
scientific measurements.

## Diagnostics and interpretation

Useful generic diagnostics include conserved/balanced quantities, source maxima,
center/radius moments, symmetry measures, physically defined spectral fractions,
boundary occupancy and independent operator/reference comparisons. Each metric
must record its normalization, mask, units and sampling assumptions.

Before large GPU runs, preflight the actual implementation including solver arrays,
FFT/transform workspaces, diagnostics, export staging, allocator pools and reserved
headroom. Resource stability is not scientific validation, but failed resource
assumptions can invalidate a run.

Only after numerical controls should morphology or topology be interpreted
physically. Distinguish measured changes, numerical explanations and hypotheses.

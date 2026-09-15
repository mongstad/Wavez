# Experiment lessons

Reusable lessons from developing and validating SimScope integrations. Case-specific
scientific projects and raw evidence remain outside this repository.

## Whole-path playback matters

Representative source playback can expose CPU decode/preparation, source-transition
and cache costs that already-decoded rendering benchmarks miss. Benchmark cold and
warm behavior, seeks, changing samples and full user-visible playback rather than
GPU draw cost alone.

## Viewer guides are declarations, not inferred physics

Particle extent, a displayed box, sampled grid extent and an absorber can all mean
different things. Render only declared geometry and verify transforms with
asymmetric fixtures. Never infer a computational boundary from tracer occupancy.

## Early and late evolution need boundary controls

Separate an interval demonstrably isolated from boundaries from later behavior that
may include finite-domain, absorber or periodic-return effects. Use diagnostics and
larger-domain controls rather than visual intuition alone.

## Sparse fields are truthful held samples

If particles update more frequently than volumes, the field may remain held until
its next recorded source state. Keep physics, diagnostics, particle visualization,
volume visualization and archival clocks independent. Do not fabricate scientific
intermediate states merely to make playback look smoother.

## Row order is not particle identity

Persistent trajectories and interpolation require simulation-owned persistent IDs.
Anonymous rows remain sample-local even when counts and ordering look stable.

## Visualization is not measurement

Colormap, opacity, transfer functions, point size, bloom and normalization are
presentation mappings. Numerical probes, thresholds and analysis must use source
values and declared metadata.

## Preserve provenance at boundaries

External engines and solvers own their scientific state and units. Adapters should
record transforms, IDs, units and timestamps explicitly and should remain separable
from the SimScope core.

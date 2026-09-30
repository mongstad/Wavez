# Issue #120 review evidence

Accepted baseline: `1a607740876736fdff34a25ca18ef395d33a4fe7`, PR #148,
v0.1.0.11. Implementation candidate: v0.1.0.12, pending owner UX review.

`summary.json` retains renderer counts and focused report/source hashes. The
focused native logs and representative dark/bright screenshots accompany it.
All generated `.ssc`, inspection bundles, video frames and temporary outputs
remain outside the Git repository under `/home/Nozba/Codex/SIMSCOPE/orbit-120/`.

The new focused suite initially passed its Compatibility assertions but failed
its strict log check on two `Texture with GL ID ... leaked 349524 bytes` teardown
diagnostics. A fresh `git archive origin/main` snapshot (no implementation branch
switch) reproduced the same two diagnostic types/sizes/count. GL IDs differ with
allocation order. `accepted-main-probe.txt` is the exact probe source;
`accepted-main-compatibility.txt` is its retained output.

Reproduce that probe by copying its text to `viewer/scene/orbit_baseline_probe.gd`
in a source snapshot of the baseline, importing with Godot 4.7.2, then running:

```sh
/path/to/godot --path /path/to/baseline/viewer --rendering-method gl_compatibility \
  --resolution 1440x900 --audio-driver Dummy \
  --script res://scene/orbit_baseline_probe.gd -- /path/to/focused-fixtures
```

An explicit `--baseline-log docs/evidence/issue-120/accepted-main-compatibility.txt`
lets `tools/validate_orbit_setup.py` compare only those texture leak headline
signatures/counts (normalizing runtime GL IDs). It still rejects any other error,
warning, failed assertion, nonzero process exit or changed complete capture hash.
Without that option the strict Compatibility run remains nonzero on this host.
This exception records an accepted-main engine shutdown limitation; it does not
claim clean Compatibility teardown or change production cleanup behavior.

Initial harness failures were corrected before the final matrix: stable
mesh fixtures needed explicit vertex IDs, Godot does not implement `%g` formatting,
preset restore materializes a default false legend key, and capture-time busy
state intentionally disables transport pixels. The final PNG comparison covers
the entire simulation region, including the temporary panel position. The first
sandboxed import also could not initialize editor sockets/save external settings;
the final isolated native import ran outside that sandbox and succeeded. A final
projection test briefly used an unavailable `Projection.is_finite` method; it was
corrected to check every matrix component with the supported numeric function.
First-frame wrapped-label layout and tiny-radius frustum failures were corrected
in the implementation: the coordinate label stays compact, clipping scales with
custom radius, reset/frame restore normal scene clipping, and release retains the
exact live transform instead of recomposing large opposing vectors.

This evidence is a review-time record. Passing automated checks does not imply
owner acceptance, and no historical report was rewritten to claim acceptance.

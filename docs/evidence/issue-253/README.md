# Issue #253 Save Image evidence

The [full-window reference](particles-with-chrome.png) shows the Forward+ viewer
with its top bar, Simulation dock, bottom strips and embedded Tools window. The
[saved PNG](particles-saved.png) is the same live scientific frame cropped to
1072 × 748 pixels; it retains the particle legend and excludes that chrome.
The tiny fixture contains only two particles, so this is a crop/composition
example, not a scientific rendering-quality reference.

`python tools/validate_save_image.py` passed 54 focused checks on each native
renderer: [Forward+](forward-report.json) and
[Compatibility](compatibility-report.json). It covered particle, field, mesh
and mixed scenes; live-pixel comparison; particle, field and mesh legends;
particle legend on/off; Tools and orbit editor
exclusion; hidden-dock width; shortcut dispatch; ordinary and selection-aware
inspection sidecars (including cropped dimensions and the verified PNG hash);
unchanged visual/camera state and scientific transforms.
The wrapper also verified byte-identical WVZ fixture hashes after each run.

The existing `tools/validate_file_locations.py` headless run passed 50 checks,
including configured-folder direct save, unavailable-folder feedback, native
picker cancellation, session folder reuse and shortcut routing. No unrelated
full-suite or packaged-app run was performed. Final owner review should inspect
the Save Image result in a normal desktop session with representative captures.

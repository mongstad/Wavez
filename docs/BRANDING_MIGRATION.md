# WAVEZ branding migration — issue #155

Candidate **v0.1.0.14**, based on accepted `d6e4bd8` (PR #154, build 13).
Implementation is pending owner review. #155 was the only Ready issue when selected.

## Current names and approved artwork

Use **WAVEZ** for the application title, wordmark and prominent UI; **Wavez** in
ordinary prose; `wavez` for technical product identifiers. The existing violet UI
palette, control behavior, scientific algorithms and rendering settings are unchanged.
Window/shell, About/help, capture/preset filters, HUD, video worker, screenshot names,
analysis output-folder suggestion, UI laboratory and current documentation use the
new identity. The application version remains sourced only from `viewer/project.godot`.

About and the application icon use the owner's unchanged dark square artwork:
`Wavez_ThemeBranding/Dark_Mode/Wavez_Square_Logo_No_Slogan_No_Border_Dark.png`.
The README uses `Wavez_Banner_No_Slogan_No_Border_Dark.png` from the same package.
The originals remain outside the repository. Only these two consumed assets are
bundled; no light artwork, new design, third-party runtime or engine is bundled.
See [asset provenance](../viewer/ui/about/README.md) and [branding policy](../TRADEMARKS.md).
The theme resource filenames use `wavez_*`; their UID sidecars are preserved.

## Python/tooling migration

Install the local distribution as **wavez-export 3.0.0** and import **wavez_export**:

```bash
python -m pip install -e '.[analysis,zstd]'
python -c 'from wavez_export import SceneCapture, SceneReader'
python tools/verify_ssc.py /absolute/path/capture.ssc
```

External simulation/export scripts must replace `import simscope_export` and
`from simscope_export ...` with `wavez_export`. There is no legacy import shim or
second exporter implementation. The package's compatibility version remains 3.0.0;
its capture bytes, data model and numerical behavior are unchanged. Restart existing
analysis processes after updating the checkout. Current examples, tests, worker
source-signature inventory and executable documentation use the new package.
The private video bootstrap option is now `--wavez-render-job=...`; the viewer,
render-job builder and validation callers change together. Temporary Linux validation
builds are named `wavez.x86_64` / `wavez.pck`. No public release or tag is created.

## Intentional compatibility identifiers

These are protocol/storage identifiers, not current visible branding:

- **SSC**, **SIMSCP4**, `.ssc`, format magic/version, descriptors and checksums:
  unchanged. Existing scientific captures must remain readable without conversion.
- JSON kinds `simscope-inspection`, `simscope-view-preset`, `simscope-export-source`,
  `simscope-matched-render`, `simscope-export-staging`, `simscope-numerical-export`
  and `simscope-member-cache`: retained in writers/readers/tests and schema docs.
  Renaming them would invalidate existing presets, inspection bundles, analysis
  results or jobs for no scientific benefit.
- `.simscope-cache` and `.simscope-export-*`: retained cache/staging paths so existing
  cache locations, cleanup and diagnostic workflows still find their data.
- `SIMSCOPE_FIELD_WORKERS`, `SIMSCOPE_METADATA_BUDGET_MIB`, `SIMSCOPE_VIDEO_PROFILE`:
  retained external diagnostic controls, including their diagnostic messages.
- `user://`: explicitly retains the old application-data directory rather than
  silently resetting Favorites, successful-open Recent history or engine settings.
  Linux/BSD use `godot/app_userdata/SimScope` below the platform data directory;
  Windows/macOS use `Godot/app_userdata/SimScope`. This follows
  [Godot's platform data-path contract](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).
  No files are copied, deleted or migrated on launch. Non-desktop and self-contained
  engine installations are outside the tested deployment scope.

## Repository and historical references

At the owner's request, **the owner will rename the GitHub repository after this
task**. `https://github.com/mongstad/SimScope`, local checkout `SimScope/`, the
`SimScope Development` board and the exact owner-created issue branch remain as-is.
About still opens the working repository URL. No repository/Project settings,
remote URL, default branch, visibility, topics or description are modified here.
After renaming, the owner should update the remote, About URL and related current
links together. This PR does not guess the future URL.

Established document filenames (`SIMSCOPE_API.md`, `SIMSCOPE_HANDBOOK.md`,
`ABOUT_SIMSCOPE.md`, roadmap and acceptance-matrix filenames) remain stable so
historical/internal links keep resolving; current guide contents use Wavez.
Historical reports, screenshots, evidence, provenance, accepted design records and
recorded external simulation paths retain their original names and review-time
claims. Only two source-link targets in `G4_DESIGN.md` follow the moved Python module;
the accepted design prose remains unchanged. Current status and About documentation
explicitly distinguish the new identity from original review records.

The full initial search found 1,935 matching lines in 413 files, including binary
historical evidence. `python tools/audit_branding.py --output /tmp/wavez-audit.json`
classifies every surviving text occurrence and old-name tracked path, rejects
unclassified references, and checks historical evidence against the accepted base.

## Validation and owner review

Linux validation used Godot 4.7.2 and NVIDIA RTX 3070 Ti / driver 615.71.09.
The [machine-readable summary](branding/validation.json),
[complete survivor inventory](branding/legacy-reference-audit.json),
[scientific module comparison](branding/scientific-module-invariance.json), and
[baseline output comparisons](branding/output-comparison.json) are retained here.
Raw logs, captures and temporary executables remain outside Git under
`/tmp/wavez-validation-native`, `/tmp/wavez-validation-followup`, and
`/tmp/wavez-validation-final`.

| Check | Forward+ | Compatibility |
|---|---:|---:|
| Live branding scan and unchanged old/new preference directory/bytes | 4,460 PASS | 4,460 PASS |
| About, notices, compact sizes and repository URL | 98 PASS | 98 PASS |
| Violet controls, Details routing and unchanged asset hash | 1,099 PASS | 1,099 PASS |
| Shell/menu routing, tools and lifecycle | 673 PASS | 673 PASS |
| Portable view presets | 826 PASS | 766 PASS |
| FileDialog persistence, seven processes | 90 PASS (Wayland) | 90 PASS (X11; caveat below) |
| Current strict video export and scientific source assertions | 235 PASS | 225 PASS |
| Redraw pacing / paused-idle behavior | 290 PASS | 290 PASS |
| File → Exit / graceful worker cancellation | 6 process cases PASS | 6 process cases PASS |

- All **216 Python unit tests pass**, including numerical export, analysis workers,
  recipes, storage and format contracts. All **38 scientific Python modules** are
  byte-identical under their new directory. Both cross-version strict-reader checks
  verify **11 complete records**, including payload checksums and field statistics.
- **70 baseline/candidate output comparisons pass** across both renderers: exact
  timing records and clean scientific frames; for UI-inclusive exports and replay
  screenshots, pixels below the intentionally renamed top bar remain identical.
- Linux release packaging uses installed external Godot templates. The resulting
  **wavez.x86_64 / wavez.pck** passes **98 About checks**, including packaged dark
  artwork and licensing resources. The renamed wheel builds and imports from an
  isolated install outside the checkout. No runtime/template/binary is committed.
- Documentation link validation and all three executable API examples pass.
  Packaged notices are synchronized; import completes without parser errors;
  resource UIDs survive theme and logo-path changes. The survivor inventory has
  **1,567 classified locations, zero unclassified references**, and zero altered
  historical evidence files. Its classification vocabulary/report are excluded
  from self-scanning.
- Visual inspection covered the dark About resource on both renderers, the Help
  menu and field panel. The automated text scan also visits every menu, each
  simulation workspace and every focused Tools form. See
  [Forward+ preview](branding/about-forward-plus.png) and
  [Compatibility preview](branding/about-compatibility.png).

### Failures and limits retained for review

`validate_g4_render.py` passes its first **41 checks** then fails the existing
PNG-versus-clip equality assertion on **both candidate and untouched accepted main**,
on both renderers. No unrelated rendering fix is included. Candidate/baseline clean
video frames match exactly; replay screenshots match below the top command bar.
This is not a claim that the complete G4 render suite passes.

Compatibility FileDialog tests on **Wayland** time out during process shutdown after
passing phase assertions (two candidate attempts; also reproduced on accepted main).
**X11 completes all 90 checks**. The established test records **12 known GL
texture-cleanup diagnostics** across seven processes, within its existing limit;
these diagnostics were not suppressed or reclassified as new passing assertions.

Early validation attempts were blocked by sandbox display access, isolated export
template lookup, an unsynchronized intermediate notice resource, or missing Python
build tooling. Final runs use permitted native display access, isolated settings,
installed external templates, regenerated notices and an isolated build environment.

Windows/macOS execution and packages, self-contained engine installs, non-desktop
platforms and full production-scale scientific runs were not tested. Platform data
path overrides follow the engine contract; only Linux was verified live. Small
representative particle/mesh/volume captures and existing-file cross-version checks
cover this branding migration. The repository rename remains explicitly deferred.

Before acceptance, open a representative existing `.ssc` and check:

1. The title/wordmark reads WAVEZ; Help → About WAVEZ shows build 14 and the supplied
   dark square artwork; notices and the existing GitHub link work.
2. Open/State/Export/Tools, all three simulation tabs and Fullscreen retain their
   normal behavior. Capture/preset filters and new PNG filenames use WAVEZ/wavez.
3. Existing Favorites/Recent, saved presets and inspection bundles still work.
4. Play, seek and switch field channels; export a PNG, short video and scientific
   result. Compare the scientific output with the accepted baseline.
5. Update an external Python integration to `wavez_export` and verify an existing
   capture with `tools/verify_ssc.py`. Review the documented import/CLI changes.

Owner review, acceptance, merge and the later repository rename remain separate.

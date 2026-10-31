# Pre-Spectral restoration — issue #421

Owner-review candidate v0.1.0.118; no merge/release authorized.

Baseline: `681a46f8f8473ee6b5323ec4af71ada883183077` (PR #409).
Accepted main before/after validation: `942397b8763c1a84c02f9abdcc7640e972d58af4`.
Protected spectral before/after validation: `4b9a1aeaa8658cd4ff65ebbcff06ac52b3667a09`.
The latter contains PR #418 merge `54dfda29e6ba45be33a3aae044db9f22fd8d462e`
and all preceding accepted spectral commits. No operation writes that branch.

Cumulative review found spectral-only additions and integration changes in the
worker, dispatch, analysis controllers, menu/status routing and image overlay
handling. These are restored to the authoritative baseline, not blindly reverted
commit-by-commit. Spectral-only research, assets, tests, guides and review evidence
are removed from this branch's tree and remain intact on spectral and in Git
history. External Model A captures and temporary visual investigation evidence
are untouched. PR #420 changed only the README roadmap image/spacing; retained.

## Exact intentional differences from PR #409

- viewer/project.godot: version only, 113 → 118. Accepted main remains 117;
  PR #420 did not alter that setting. This rollback adds exactly one and does
  not retroactively change accepted history.
- README.md: retain PR #420 roadmap image/spacing; explain experimental branch.
- AGENTS.md: owner-directed post-acceptance experimental branch/PR targeting.
- docs/CURRENT_STATUS.md: restoration candidate and policy, above baseline history.
- docs/evidence/issue-421/: this new review evidence.

Every other tracked file is byte-identical to PR #409 or absent exactly as in
that baseline. In particular all application source, renderer/shader, playback,
source-format, exporter and scientific calculation files match. inventory.json
records the complete restore/remove list. No format or experimental versioning
policy changes. Two owner stashes remain unchanged; four newly regenerated,
unrelated resize UIDs are preserved under /tmp/wavez-421/preserved-generated-uids.

## Validation

Fedora workstation, RTX 3070 Ti, external Godot 4.7.2, Forward+ Vulkan. Small
synthetic fixtures only, isolated profiles. Commands in run_validation.py;
individual native output and JSON summaries accompany this report.

- Python application-version and analysis-worker: 17 tests PASS.
- Viewing preferences: fresh 77, restart 2, named preset 5, corrupt 2, missing 1
  checks PASS. Scientific/Cinematic independent Bloom and restart behavior covered.
- Global Bloom: 310 checks PASS, including fields, particles, meshes and mixed
  scene pixel comparisons in Scientific and Cinematic.
- Portable presets: 827 checks PASS.
- Playback: 2457 checks PASS.
- Camera navigation: 1747 checks PASS.
- Focused runtime smoke PASS: Tools menu has neither spectral entry; ordinary
  mixed-scene image export saves a 1072×748 PNG. smoke.gd/json records actual menu.
- No spatial_spectrum/spectral_band runtime references in viewer, tools,
  wavez_export or tests. Baseline parity also excludes spectral overlays/imports.
- Editor import PASS with isolated writable configuration. First sandbox import
  could not save external editor settings; rerun resolved the environment issue.
- Linux package built successfully; Forward+ packaged startup exited cleanly
  after 60 frames. First packaging attempt hid installed external templates under
  isolated XDG_DATA_HOME; retry used installed templates without bundling anything
  into the repository. Package remains local, not a published release.

### Known baseline validation failures — not suppressed

Shell suite: 686 checks, 2 failures ('Play has one controller binding' and
'Shell construction preserves scientific visual state and section keys'). The
unchanged PR #409 checkout reproduces the exact two failures. Both logs retained.
This suite is FAIL; runtime smoke provides focused removal/menu/image evidence.

Video overlay suite: successful deterministic repeated 1080p exports, 4K export,
frame counts/timing/dimensions, explicit legend exclusion/inclusion and workspace
invariance precede failure at 'current: H.264 and temporary-output selections
reach the worker job'. The unchanged PR #409 checkout reproduces that assertion.
Both logs retained. Existing export behavior is exercised, but full dialog option
validation is NOT green. No unrelated runtime repair or test weakening is included.

Source/profile and package outputs are under /tmp/wavez-421. runs.json retains
first-attempt failures; package-retry.log and package-startup.log document recovery.
The baseline comparison is an external git archive, not a changed branch.

## Owner verification

Open the built viewer or source with Forward+ Vulkan. Confirm About shows
v0.1.0.118 and Tools contains neither Spatial spectrum nor Spectral band map.
Open a mixed capture; inspect field/particle/mesh display, navigate camera,
play/seek, switch Scientific/Cinematic, set distinct Bloom preferences and restart.
Save an image and a short video; inspect their frames and dialog output options,
especially the known baseline video assertion above. Review the four intentional
baseline differences plus this evidence. Merge only through owner acceptance.

After acceptance, new Spectral work originates from and targets spectral;
main integration needs a separate owner decision. Experimental version rules
remain unchanged. No issue closure, project transition, tag or release performed.

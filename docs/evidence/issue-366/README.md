# Scientific startup and persistent Bloom — issue #366

Candidate **v0.1.0.113**, based on accepted **v0.1.0.112** / PR #408,
`bbd7eda678d9b04d784428747b61517aa2817499`. Owner review is pending.

## Authorization and implementation

#366 was the sole Ready item when selected and remained Ready before handoff.
No linked branch, remote issue branch or implementation PR existed. Created
`issue-366-scientific-bloom-preferences` from clean, synchronized accepted main
under the current AGENTS branch rule. The #306 / PR #311 global-control fix
(`ceb3ba2`) and the current Forward+ policy are ancestors of this baseline.
PR #408 is merged, its branch already absent and stale refs pruned.

Fresh profiles now apply Scientific before opening the first capture: Bloom off,
point representation and existing Scientific backdrop/fog behavior. Cinematic's
fresh Bloom is on at **0.30**, 15% of the existing **0–2 / 0.02-step** range.
All other supported presets start off, with 0.30 available if enabled.

Global effects adds **Enable Bloom** alongside the existing one scene-wide slider.
Every viewing preset can enable, disable and adjust that same Environment effect.
Bloom no longer changes the preset name or slider availability. Each preset
remembers its own on/off/intensity pair; selecting it recalls that pair. Manual
changes persist immediately to bounded, validated `user://view_preferences.json`
through a flushed sibling temporary file and atomic replacement. Failed saves
retain session choices and display a notice; invalid reloads leave committed
memory unchanged. Corrupt startup profiles use complete fresh defaults with a
notice rather than partially applying values.

Explicit portable/native view restoration owns the session's saved pixels and
preset identity, without writing application preferences. Capture opening and
Close File preserve that session state. Manual preset selection recalls the
stored pair; a manual Bloom edit saves the current pair. A restart recalls the
last manual choice. Offline workers never load or save application preferences.
Portable schema version 1 now includes `settings.view.preset`; validated partial
recipes with only `clean_view` use its Scientific/Cinematic representation.
Native snapshots' environment values take precedence over stale Bloom slider
records, without an additional slider-tick rounding of the live Environment.

Named Temperature/Density/Velocity selection consumes the existing channel mapping
action when the opened capture has that channel; this preserves the selected
preset meaning without reapplying environment defaults or changing Bloom pairs.

No shaders, per-layer Bloom, additional rendering passes, WVZ1, cache algorithms,
camera semantics, renderer policy or release packaging policy change.
Interactive initialization consumes the preferences after building controls;
offline initialization retains its prior base settings and consumes job snapshots.

## Validation

All final processes completed with zero test failures and clean native logs.
Godot **4.7.2**, Linux x86_64, **Forward+ Vulkan**, NVIDIA RTX 3070 Ti.

| Focused check | Result |
|---|---|
| Application version | 2 Python tests PASS |
| Native preference processes | 77 fresh + 2 restart + 5 named + 2 corrupt + 1 missing = **87 PASS** |
| Linux release-template preference processes | Same **87 PASS** |
| Source global Bloom / recipes / GPU | **310 PASS** |
| Linux release-template global Bloom / recipes / GPU | **310 PASS** |
| Portable view restoration | **827 PASS** |
| Production MP4 comparison | **6 jobs PASS**, accepted/candidate/package frame pixels identical |

Preference tests cover all six preset defaults/manual overrides, persistence
through four capture types and Close File, named-channel restoration on open/restart,
new-process restoration of independent
Scientific/Cinematic pairs, malformed/incomplete/nonfinite/out-of-range preferences,
bounded reads, failed writes, transactional disk/memory behavior, rejected recipes,
explicit session precedence, stale native slider records, themes, slider keyboard
input, and Space/mouse switch input through the native Window path. Reset Camera
preserves these choices. Synthetic source hashes remain unchanged.

Global Bloom tests separately verify control interaction and actual GPU effect
for particle-only, field-only, mesh-only and mixed fixtures. Manual Scientific
Bloom changed **35,624 / 51,395 / 70,206 / 163,731** pixels respectively in the
source captures (maximum channel deltas **106 / 71 / 235 / 235**), while keeping
Scientific identity and point representation. These are fixture observations,
not universal brightness/performance guarantees. Default Bloom-off Scientific
images remain invariant to slider changes. Dark/Light and compact controls,
portable/native inspection restoration, image export and global-control ownership
remain covered by the directly affected existing harness.

Portable tests exercise validated save/load round trips, failed-load atomicity,
source/time/selection/job/shell preservation, capture reopening, mappings, camera
zoom and projection. Six production jobs cover Cinematic/Scientific at 640×360,
4 FPS, three frames each across accepted source, candidate source and a normal
Linux release package. PNG pixel hashes match each corresponding baseline;
ffprobe dimensions/FPS/counts and timestamps 0 / 0.25 / 0.5 pass. Workers create
no viewing-preference file, and the strictly verified synthetic input is unchanged.

This is a presentation/preference subsystem change. Validation targets its UI,
profile I/O, view restoration and immediate image/video boundaries; unrelated
scientific, layer-cache, navigation and full-application suites were not run.

[Source preference summary](preferences-source/summary.json),
[package preference summary](preferences-linux/summary.json),
[source global report](global-source/report.json),
[package global report](global-linux/report.json),
[portable report](portable-source/report.json),
[video comparison](video-comparison/report.json).
Completed native logs are alongside each report, including
[source fresh process](preferences-source/fresh-run.txt),
[package fresh process](preferences-linux/fresh-run.txt),
[source global process](global-source/run.txt),
[package global process](global-linux/run.txt) and
[portable process](portable-source/run.txt).

## Documentation and historical records

Updated current Bloom/preference guidance, portable view behavior, handbook and
CURRENT_STATUS. The entire previous #306 report body in GLOBAL_BLOOM is retained
under a historical heading; every previous CURRENT_STATUS record is unchanged.
Existing historical evidence, assets and review-time acceptance wording remain
as written. No new acceptance ledger or release approval is implied.

## Failed attempts and limitations

- Initial sandbox editor import could not open its local editor socket; repeated
  resource import with authorized local access. New scripts have tracked UID
  sidecars; unrelated cache-generated sidecars were not added.
- [Config parser attempt](config-parser-attempt.txt): all 65 then-current assertions
  passed, but intentionally corrupt syntax made ConfigFile log an engine error.
  The final reader uses JSON parsing and returns a visible, non-partial error.
- [Direct mouse injection](mouse-injection-attempt.txt) and
  [motion-only attempt](mouse-motion-attempt.txt): native switch-click assertions
  did not activate the CheckButton.
  Native pointer placement and separate press/release frames corrected the test;
  runtime code did not change for that correction. Final source/package tests pass.
- Compatibility is currently unsupported by the authoritative renderer policy.
  Unsupported launches are refused before preference loading/saving; no fallback
  or Compatibility claim is introduced. Headless imports certify no GPU behavior.
- Tests inject native Window events; physical hardware input, other GPUs/OSes,
  multi-DPI/4K, long sessions and slow/network-mounted preference storage are not
  certified. Native Environment properties retain their engine precision.
- Application and portable Bloom intensity are bounded to the current 0–2 UI
  range. Hand-edited native inspection environments outside that range are not
  covered by this validation. Loaded views intentionally do not become new disk
  preferences until a manual preset/Bloom action.
- No release, tag or publication. Disposable test packages and the normal
  comparison package are external artifacts, not distributed release assets.

## Reproduce and owner verification

Use isolated XDG_DATA_HOME/XDG_CONFIG_HOME for tests; import a disposable accepted
baseline before comparisons. External Godot/templates/FFmpeg remain unvendored.

```sh
python -m unittest tests.test_application_version
python tools/validate_view_preferences.py --godot /absolute/path/to/godot --output /tmp/wavez-366-source
python tools/validate_view_preferences.py --godot /absolute/path/to/godot --output /tmp/wavez-366-linux --package
python tools/validate_global_bloom.py --godot /absolute/path/to/godot --renderer forward_plus --output-dir /tmp/wavez-366-global
python tools/validate_global_bloom.py --godot /absolute/path/to/godot --renderer forward_plus --output-dir /tmp/wavez-366-global-linux --package
python tools/validate_view_preset.py --godot /absolute/path/to/godot --renderer forward_plus --output-dir /tmp/wavez-366-portable
python tools/validate_global_bloom.py --godot /absolute/path/to/godot --project-root /absolute/path/to/accepted-baseline --output-dir /tmp/wavez-366-video --exports --fixtures-dir /tmp/wavez-366-global
```

1. With Wavez closed, use a fresh profile or back up/remove only
   `user://view_preferences.json`. Start and open a capture: Scientific checked,
   Enable Bloom off, slider at 15% of its range. Select Cinematic: Bloom on at
   that same initial position.
2. In every available preset, use Enable Bloom with mouse and Space; adjust
   Bloom with mouse/arrow keys. Confirm the preset checkmark, Point rendering,
   color mapping, camera, backdrop/fog and playback do not change from Bloom edits.
3. Give Scientific and Cinematic distinct on/off/intensity pairs. Switch away and
   back, Close File/Open another WVZ, and restart: each pair and the last manual
   selection must return. Repeat in both themes and normal/compact windows.
4. Load a deliberately saved view with a different preset/Bloom pair; it must
   apply to the session and survive capture opening. Restart should return the
   last manual application choice. An invalid view must change neither state.
5. With Wavez closed, corrupt the preference file, reopen and inspect the notice
   in Global effects. Remove it while closed to restore fresh defaults. Confirm
   Help → About reports candidate **v0.1.0.113**, then review before acceptance.

Raw test artifacts remain external at `/home/Nozba/Codex/Wavez/bloom-366/`.

[Fresh startup before](startup-before.png), [fresh startup after](startup-after.png),
[Dark manual Scientific Bloom](effects-dark.png),
[Light manual Scientific Bloom](effects-light.png).

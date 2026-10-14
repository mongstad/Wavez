# Video Export tooltip removal — issue #338

Candidate **v0.1.0.112**, based on accepted `main`
`8b0ffa83bcea1b7fa9b6827db4bc8c6c5065d547` (owner-merged PR #407).
The Wavez Development Project had exactly one Ready item, #338, when selected.
The assigned branch is
`338-ux-video-remove-all-tooltips-from-the-video-export-dialog`; it matched
accepted main, included #326 / PR #337, was clean, and had no existing PR.
Owner review is pending; this report does not establish acceptance.

## Change and boundaries

Removed five Wavez-authored tooltip assignments: the header close icon,
Playback rate, Overlays, Trails, and the summary hint refreshed by
`update_estimate()`. Removed the formatting preload used only for that hint.
The existing Start/End controls already had no hints. The runtime diff changes
no labels, dimensions, focus/mouse policies, callbacks, settings, calculations,
worker launch, cancellation, or backgrounding. No other Wavez dialog changes.
The source-only harness now checks nested editors, arrow regions, containers,
dropdown item hints, scrolled settings, Advanced, and idle/active action surfaces.

Current `docs/VIDEO_EXPORT.md` and `docs/CURRENT_STATUS.md` reflect this proposal.
All earlier reports, screenshots and review-time wording remain unchanged.

## Focused validation

The change only removes presentation hints. Focused dialog interaction and
before/after export checks cover its plausible blast radius; unrelated camera,
playback-cache, field, mesh and scientific-integrity suites were not run.
Forward+ Vulkan is the current supported renderer; Compatibility is not tested.
Godot 4.7.2, Linux x86_64, NVIDIA RTX 3070 Ti, external FFmpeg.

- Python application-version tests: **2 PASS**.
- Focused dialog group, headless: **53 PASS**, zero failures. Includes presets,
  dimensions/FPS, camera/output settings, exact range/bounds, active settings
  locks, populated progress/status, cancellation Yes/No and focus, recovery,
  and missing-FFmpeg validation. Headless results establish CPU/control contracts,
  not GPU presentation. See [log](dialog-group-headless.txt).
- Source GUI: accepted baseline **187 PASS**, candidate **1,979 PASS**, zero
  failures and clean completed process logs. **312 delayed hover targets** at
  0.8 seconds each cover both themes and 700×650 / 560×360 dialog sizes,
  scrolled settings, nested numeric text/arrows, clocks, labels, choices,
  output field/Browse, Advanced and action buttons. All candidate hover/ancestor
  hints and visible TooltipLabel counts are empty. Hidden controls and containers
  also receive a recursive `get_tooltip()` audit; dropdown item hints are checked.
  Active-state buttons and recursive hints are checked in all four presentations.
- **42 settings matrix pairs match** accepted main. Three 320×180 / 4 FPS exports
  have exact matching timing records, PNG pixels and decoded MP4 pixels:
  fractional (4 frames), full-fast (2 frames), final-fraction (2 frames).
  The final-fraction job ends at 92.33 and includes capture time 92.125.
  Synthetic WVZ1 input hashes remain unchanged.
- Four unhovered source captures (Dark/Light × normal/compact) have identical
  decoded pixels before/after. See [comparison](layout-comparison.json).
- Linux release-template package: baseline **187 PASS**, candidate **1,979 PASS**,
  **312 delayed hover targets**, zero failures and clean completed logs. The same
  **42 settings pairs** and three exact timing/PNG/decoded-MP4 comparisons pass.
  [Package summary](linux-release-template/summary.json),
  [UI/hover report](linux-release-template/after/report.json),
  [candidate log](linux-release-template/after/run.txt),
  [test artifact hashes](test-package-artifacts.json).

[Source summary](source/summary.json), [candidate UI/hover report](source/after/report.json),
[baseline UI report](source/before/report.json),
[candidate process log](source/after/run.txt), [baseline process log](source/before/run.txt).

## Attempts and limitations

These unsuccessful attempts are preserved and are not counted as passing runs:

- [Sandbox display attempt](sandbox-display-attempt.txt): neither X11 nor Wayland
  was accessible; reran with native display/GPU access.
- [Unimported baseline attempt](unimported-baseline-attempt.txt): archive lacked
  imported textures. Stopped the attempt, imported the disposable baseline and reran.
- [Baseline summary expectation](baseline-summary-harness-attempt.txt): the
  pre-existing summary Label ignores mouse input, so its assigned tooltip did
  not produce the expected popup. Recorded that assigned hint separately;
  retained a real before screenshot of the Playback rate popup.
- [Original deadline](hover-deadline-attempt.txt): the extended whole-dialog sweep
  exceeded the old 100-second internal limit. Raised the test deadline to 390
  seconds and outer timeout to 420 seconds; completed reruns are reported above.
- An initial dialog-group assertion expected the deliberately removed Playback
  rate hint. Updated it to require the permanent label and × unit without a hint;
  the final 53 checks pass.

The output field and Browse button are covered, but operating-system native
save-chooser internals and the embedded FileDialog fallback were not exhaustively
hover-tested or modified. Physical mouse/keyboard input, multi-DPI/4K layouts,
other operating systems and long export sessions are not verified. Active-state
hover tests use an owned sleeping child process; real encoding is checked by the
three short render jobs, not a long interactive background/cancel session.
No release ZIP/tag/publication was requested; the package is a disposable
release-template test executable/PCK, not a published distribution.

Owner ambiguity review: the removed Trails hint explained that Scientific
rendering suppresses trails even when checked. That behavior remains documented
in the current video guide. Review whether existing permanent labels suffice;
no replacement explanation or help UI was introduced.

## Reproduction

Import a disposable archive of the accepted baseline before running comparison.
Use an externally installed audited Godot 4.7.2 and matching export templates.

```sh
python -m unittest tests.test_application_version
XDG_DATA_HOME=/tmp/wavez-338-profile XDG_CONFIG_HOME=/tmp/wavez-338-profile /absolute/path/to/godot --headless --path viewer --script video/test_export_dialog_group.gd
python tools/validate_video_time.py --godot /absolute/path/to/godot --baseline /absolute/path/to/accepted-archive --output /tmp/wavez-338-source --renderer forward_plus
python tools/validate_video_time.py --godot /absolute/path/to/godot --baseline /absolute/path/to/accepted-archive --output /tmp/wavez-338-package --renderer forward_plus --package
```

Raw artifacts remain external in `/home/Nozba/Codex/Wavez/tooltip-338/`.

## Owner verification before acceptance

1. Open a capture and File → Export → Video. In Dark and Light, at normal and
   compact sizes, scroll through all groups and expand Advanced. Hover controls,
   nested numeric editors/arrows, labels, dropdowns, Browse and action buttons
   for at least one second. Confirm no dialog tooltip appears and labels remain.
2. In Custom mode use fractional endpoints; check Exact range, one-second arrow
   reversals, Enter/Tab edits, endpoint bounds and the final partial-second End.
   Change resolution/FPS presets and Custom, rate, camera, presentation and quality;
   check output selection/cancel and keyboard traversal.
3. Start a real export; inspect progress, Run in background, reopen from Jobs,
   Cancel export → No, then Yes. Confirm recovery and retained intermediates.
   Review the Scientific/Trails label ambiguity noted above.
4. Check Help → About reports candidate `v0.1.0.112`; review this PR and its
   focused evidence before accepting. Merging remains the owner's action.

## Visual evidence

[Before Playback rate popup](before-playback-rate.png),
[after exact Dark range](after-dark-range.png),
[Dark compact output/Advanced](after-dark-compact-output.png),
[Light compact output/Advanced](after-light-compact-output.png),
[Light compact active actions](after-active-light-compact.png).

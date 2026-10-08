# Issue #214 — LMB vertical inversion

Candidate **v0.1.0.76**, pending owner review. #214 was the only Ready item.
The existing owner-created branch is
`214-ux-nav-add-configurable-inverted-y-axis-for-lmb-camera-tumble`,
clean at accepted `09591361ae6fa0596f9f0a6458975f115384fd54` (owner-merged PR #297).
Main/origin and branch matched; fetch/prune completed. The prior branch was
already absent locally/remotely. No acceptance-only branch/PR was created.

The accepted predecessors are in main: #190 via PR #199 (`d5e1873`) and the
later #258 revision via PR #262 (`5244bab`). The owner explicitly clarified
that **current #258 two-axis RMB steering must stay preserved**, resolving the
original issue's older #190/ignored-vertical wording. The owner also directed
that the On/Off control appear **inside Keyboard Shortcuts beside the hotkey**.

## Implementation and scope

One authoritative Navigation action, **Toggle Invert Y Axis**, starts Unbound.
Its row includes an On/Off CheckButton, with initial state Off. The state and
binding edit stay local until Apply, which saves/activates both without closing.
Cancel/X/Escape discard drafts; Reset Defaults stages Off plus the default map.
The same action dispatcher toggles/saves the preference when its assigned hotkey
is pressed.

Only the vertical multiplier in the existing LMB drag method changes. Horizontal
yaw and sensitivity stay intact; the camera basis/update path is reused. The
preference is saved in the existing atomic ConfigFile, in its navigation section,
alongside the shortcut map. There is no extra Navigate control or HUD. The
shared dialog focus/scroll and tooltip-free behavior are retained.

The validation compares ten accepted-main functions byte-for-byte, including
RMB input/steering, held orbit, wheel, translation, camera update, Auto Orbit and
framing/reset. Their bodies are unchanged. Runtime comparisons check matching
results with inversion Off/On and fixed world/scientific state. The preference
is absent from the scientific visual snapshot; no format, payload, recipe or
video-job serialization code changed.

## Focused results

| Environment | Main checks | Fresh-process checks | Result |
| --- | ---: | ---: | --- |
| Headless source | 2,501 | 3 | 2,504 PASS |
| Forward+ source | 4,973 | 3 | 4,976 PASS |
| Compatibility source | 4,973 | 3 | 4,976 PASS |
| Linux release, Forward+ | 4,973 | 3 | 4,976 PASS |
| Same Linux release, Compatibility | 4,973 | 3 | 4,976 PASS |

All final runs exit normally, with no engine errors/warnings and unchanged four
fixture SHA256 hashes. Each process uses an isolated application profile.
The two release runs use the identical executable/PCK hashes recorded in their
validation JSON, generated with the externally installed 4.7.2 Linux template.
No Godot runtime/template, release binary/PCK or captures are committed.

Reports/logs: [headless](headless-final/validation.json),
[Forward+](forward/validation.json), [Compatibility](compatibility/validation.json),
[release Forward+](package-forward/validation.json),
[release Compatibility](package-compatibility/validation.json).
Native and restart text logs are retained beside each report.

Coverage includes preference/binding Apply/Cancel/X/Escape, default Off/Unbound,
Reset-with-state-only changes, conflict transfer, clearing only the binding,
save-failure atomicity using an actual failed rename, invalid candidate rejection,
modifier/echo filtering, actual dispatcher toggles and fresh-process persistence.
Normal 1440×900 and compact 1024×640 images show the inline toggle, binding and
fixed footer; toggle focus clearance and absence of tooltips are checked.

Particle, field, mesh and mixed fixtures exercise both states in normal windows
and actual native Fullscreen. LMB vertical/horizontal/diagonal responses use the
accepted yaw/pitch formula, plus two full vertical revolutions in each direction
through exact poles, finite/orthonormal basis and adopted-basis continuation.
Current two-axis RMB, wheel, six translation directions, Auto Orbit, held orbit,
Frame Scene, Reset Camera and orbit-center Cancel compare identically between
states. Committed samples and scientific/world transforms remain identical.

The existing shortcut-group regression passes **282 checks** (141 main + 141
fresh-process) in Forward+, with unchanged fixtures and no cleanup diagnostics:
[report](shortcut-groups/validation.json). The version suite passes **2 tests**:
[log](version-tests.txt). Python compilation, final Godot import, documentation
links, diff whitespace and staged scope/size/credential checks also pass.

This validation covers the changed navigation input plus its preferences,
shortcut/editor, restart and renderer/package boundaries. It does not run an
unrelated full application, playback/cache, scientific-format or video suite.

## UI review images

| State | Forward+ normal | Forward+ compact | Compatibility normal | Compatibility compact |
| --- | --- | --- | --- | --- |
| Applied On, Alt+I | [image](forward/normal-inversion-on.png) | [image](forward/compact-inversion-on.png) | [image](compatibility/normal-inversion-on.png) | [image](compatibility/compact-inversion-on.png) |
| Off draft, Apply enabled | [image](forward/normal-inversion-off-draft.png) | [image](forward/compact-inversion-off-draft.png) | [image](compatibility/normal-inversion-off-draft.png) | [image](compatibility/compact-inversion-off-draft.png) |

Equivalent release images are in the package-forward/package-compatibility
folders. The screenshots are unobstructed; no hover tooltip obscures the row.

## Failed/inconclusive attempts and limitations

- Initial headless harness: 2,501 assertions reported no failures, but an unsafe
  same-frame input-event reuse raised a warning. That run is **not** a clean pass:
  [retained warning](initial-headless-warning.txt). The release event now uses
  a distinct duplicated instance; the final headless/source/package matrix is clean.
- The first import re-created five unrelated missing sidecars from accepted
  cache state ([log](import-stdout.txt)). The warm
  [final import](import-final-stdout.txt) is clean; those incidental sidecars are
  removed from the implementation scope, while the two new harness UIDs are kept.
- Physical mouse/key feel, native Wayland input delivery, mixed-DPI/4K displays,
  other OSes, long sessions and large/research captures were not tested. Native
  automation ran through X11/XWayland with Godot-generated in-app events; it
  did not control OS input devices or use Python input-device helpers.
- Synthetic fixtures are small and paused with automatic preparation disabled.
  Their payload hashes and fixed committed samples do not claim a full scientific
  integrity/large-playback test or deterministic video export validation.
- Linux package checks use a validation-only autoload with the normal Main scene.
  This proves the release resource/preferences/input paths, not a separate owner
  physical-input acceptance run. All temporary packages remain outside the repo.

Current user behavior, reproduction commands and manual checks are documented in
[the LMB preference guide](../../LMB_Y_INVERSION.md). Previous navigation,
shortcut, version and other review-time reports/evidence are preserved.

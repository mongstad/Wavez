# Issue #318 About banner review

Candidate **v0.1.0.84**, based on accepted main
`ad19ed18481abc093f316fa43a24fb1c336a3de5` (owner-merged PR #319).
Issue #318 was the only Ready item. Work uses the existing linked branch
`318-ux-branding-use-theme-specific-about-banners-and-dark-banner-in-readme`.
Implementation and these screenshots remain **pending owner review**.

## Change and provenance

About now preloads the exact approved `Wavez_Banner_No_Slogan_No_Border_White.png`
for Light and `Wavez_Banner_No_Slogan_No_Border_Dark.png` for Dark. The existing
application-theme refresh handles visible dialogs and reopening; no new theme
switching path is added. [Asset hashes](assets.json) prove byte identity with the
owner's `Wavez_ThemeBranding/Light_Mode` and `Dark_Mode` sources outside the Git root.
Both are RGB 2172 × 724 PNGs; their supplied backgrounds are preserved.

The README's existing Dark image is moved unchanged to the canonical runtime
location in `viewer/ui/about`, with its exact requested filename. README points
there directly, with no viewer-theme substitution or duplicate image. The unused
Light square is retired; the Dark square application icon and its UID are retained.

The existing About image slot widens from 112 to 216 logical pixels while retaining
its 112-pixel minimum height, lossless mipmaps and centered aspect-preserving fit.
The drawn banner is 216 × 72 at ordinary scale. Text naturally wraps in the narrower
adjacent column. Dialog preferred dimensions (580 × 592), typography, all text,
links, notices, close controls and scrolling remain unchanged. The 480 × 480 stress
case scrolls as before. Current guides updated: [About resources](../../../viewer/ui/about/README.md)
and [application themes](../../APPLICATION_THEMES.md). Older reports/evidence are
preserved as written; this issue does not record previous owner acceptance in docs.

## Visual evidence

| State | Accepted baseline | Candidate |
| --- | --- | --- |
| Dark, ordinary | [Before](before-dark.png) | [Forward+](after-dark-forward.png), [Compatibility](after-dark-compat.png) |
| Light, ordinary | [Before](before-light.png) | [Forward+](after-light-forward.png), [Compatibility](after-light-compat.png) |
| Light, compact stress case | — | [480 × 480](after-light-compact.png) |
| Light, simulated 2× | — | [Scaled](after-light-scale-2.png) |
| Fresh Linux release process | — | [Dark](package-dark.png), [Light](package-light.png) |

Baseline Dark uses Forward+; baseline Light uses Compatibility. Ordinary before/after
images show the same focused synthetic loaded-capture About state. Packaged images
show the empty viewer. Screenshots are unaltered Godot viewport captures, visually
inspected for correct artwork, centered fitting and readable content.

## Focused validation

Godot 4.7.2, KDE Wayland, NVIDIA GeForce RTX 3070 Ti, external Linux x86_64 release
template. Every run uses isolated local appearance preferences. The release package
is a temporary review build with a validation-only autoload exercising normal Main;
no executable, PCK, capture or external runtime is committed.

- Accepted baseline: **118 checks, 0 failures** each in Dark Forward+ and Light Compatibility.
- Candidate source: **339 checks, 0 failures** each for fresh Dark and Light starts
  in both Forward+ and Compatibility (four runs).
- Candidate Linux release Compatibility: **339 checks, 0 failures** each for fresh
  Dark and Light processes using the same exported package (two runs).
- Each candidate records **49 banner states**: initial selection, repeated Light/Dark
  live changes and reopening in empty/loaded viewers, ordinary/compact/2× layouts.
- All recorded dialogs fit their actual logical viewports, checked independently
  from the requested window size. Actual high-scale window: **2560 × 1394**;
  KDE clamped the requested 3840 × 2160 window. These are simulated 2× checks,
  not physical 4K display acceptance.
- Existing immediate About checks pass for version identity, license pages and hashes,
  both URL callbacks including failure presentation, bottom Close, Escape and top-right X.
  Scientific presentation/committed sample, paused state, analysis request count and
  synthetic capture bytes remain unchanged through the About/theme operations.
- Two application-version Python tests, notices synchronization `--check`, Python
  compile, byte-identical approved asset checks and whitespace checks pass.

[Summary and package hashes](validation.json) and the eight run directories retain
raw reports/logs. The expanded existing `viewer/ui/about/test_about.gd` is the focused
regression; the Python driver adds optional `--expected-theme` for restart checks.
The separate violet-cleanup test's old square-image assumptions are updated to the
banner contract, but that unrelated full suite was not run. This scope covers resource
imports, active-theme selection, fitting, packaged availability and immediate About
interactions—the plausible impact of this branding-only change.

## Failures, skipped checks and limits

The initial fresh accepted-baseline archive was run before Godot import, so texture/font
preloads failed and the test timed out. [That failed setup attempt](setup-failure/native.txt)
is retained, not counted as a pass. After [import](before-import.txt), both unchanged
baseline runs completed cleanly.

The source import reported five pre-existing missing shell script UID sidecars recreated
from cache ([first log](source-import.txt)); the unchanged warm import is clean
([warm log](source-import-warm.txt)). Those unrelated generated sidecars are removed
from this patch. Package import/export and all counted native runs completed without
script/resource errors or shutdown timeouts.

Physical 4K/mixed-DPI display review, actual mouse/keyboard feel and browser paint are
not certified by these automated runs. Package Forward+ was not repeated; package
Compatibility verifies both banner resources and active-theme selection. No broad
camera, scientific-format, export-worker or playback suites are run for this local
presentation change. Real external browser dispatch is not invoked; existing mocked
URL success/failure routes are checked. The fixed README relative path is checked
locally; GitHub's branch README/image response is checked after pushing and reported
with the PR. Owner visual acceptance remains separate from automated success.

## Reproduction and owner checks

After importing the viewer, run the focused existing driver with an external Godot:

```sh
python tools/validate_about.py --godot /absolute/path/to/godot --renderer forward_plus --output-dir /tmp/about-review
python tools/validate_about.py --godot /absolute/path/to/godot --renderer gl_compatibility --export --output-dir /tmp/about-package-review
```

Use separate `XDG_DATA_HOME`/`XDG_CONFIG_HOME` for validation. To assert a fresh
preference, write `[appearance]` / `theme="Light"` (or `"Dark"`) to the isolated
`godot/app_userdata/WAVEZ/appearance.cfg` and pass `--expected-theme Light`/`Dark`.
When exporting with isolated data, preserve access to the externally installed Godot
export templates. No browser is opened unless `--open-browser` is supplied.

1. In source and the Linux package, select Light and open Help → About: confirm
   White banner, complete source proportions and the supplied white background.
2. Close About, select Dark and reopen: confirm Dark banner. Repeat both directions;
   inspect after an application restart. Check ordinary, compact and physical KDE/4K
   display sizing. Text may wrap; the image must remain centered and uncropped.
3. Confirm version v0.1.0.84, copyright/licensing text, repository/Documentation links,
   notice pages and bottom Close, top-right X and Escape behavior remain usable.
4. View this branch's root README on GitHub in both site themes: it must always show
   the Dark banner at `viewer/ui/about/Wavez_Banner_No_Slogan_No_Border_Dark.png`.
5. Review the unchanged square application icon and confirm no other branding/theme
   colors or scientific behavior changed. Accept or request a revision on the single PR.

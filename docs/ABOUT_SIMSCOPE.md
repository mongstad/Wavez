# About SimScope — issue #96

Current #147 update: About uses the owner-supplied violet logo without changing
its layout, identity reader, notices or links. See [asset provenance](../viewer/ui/about/README.md)
and [the cleanup contract](UX5_CLEANUP.md). The original #96 report below is historical.

Pending owner review on the existing
`96-ux-about-001-add-about-simscope-dialog` branch. #96 was the only Ready issue
when selected, based on accepted main `653f817` (PR #132). Fetch/prune completed,
the tree started clean and the previous local issue branch was already absent.

## Behavior

Help → About SimScope replaces the temporary standalone Version menu and surface.
It reads `application/config/version` through the existing reader; this PR proposes
build 2 under the established policy. No independent version literal is added.

The Midnight Scientific dialog contains the unaltered owner-provided logo,
application identity, short description, copyright/rights holder, clearly separate
SimScope PolyForm Noncommercial and Godot MIT summaries, third-party acknowledgement,
runtime/platform information, the canonical GitHub link and Licenses and notices.
It opens without a capture. At normal sizes, the project link and notice action are
visible without scrolling. A smaller viewport uses wrapped text and vertical
scrolling; it does not crop or stretch the artwork.

Licenses and notices stays inside About. It offers the full project license,
third-party inventory, branding terms, bundled font/colormap notices, Godot MIT
license and the running engine's third-party notices. Repository documents remain
canonical; `tools/sync_about_notices.py` generates a preloaded `.tres` resource,
and `--check` detects drift. The copyright line is extracted from LICENSE.
The resource and logo export through Godot's normal resource dependency handling,
without external development-tree paths or custom non-resource inclusion filters.

The logo filename named in the issue had moved to the owner's
`SimScope-Logo-Package` directory. The imported PNG is byte-identical; its source
hash and branding policy are recorded in [asset provenance](../viewer/ui/about/README.md).
Runtime binaries and dependencies remain external to the repository.

The project link dispatches only `https://github.com/mongstad/SimScope` through
`OS.shell_open`. A returned failure leaves the dialog usable and shows a selectable
address for manual copying. A successful dispatch cannot establish whether an
external browser later loaded the page; the permanent project link remains visible.

The implementation uses the documented
[Engine runtime/license APIs](https://docs.godotengine.org/en/stable/classes/class_engine.html)
and [platform URL-opening API](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-shell-open).
It has no scientific controller dependency, creates no analysis request, and does
not change capture/session/rendering settings or pause playback.

## Reproduction and review

```sh
python tools/sync_about_notices.py --check
python -m unittest tests.test_application_version
python tools/validate_about.py --godot /path/to/godot --output-dir /tmp/about-forward --renderer forward_plus
python tools/validate_about.py --godot /path/to/godot --output-dir /tmp/about-compat --renderer gl_compatibility
python tools/validate_about.py --godot /path/to/godot --export --output-dir /tmp/about-packaged --renderer forward_plus
```

Use fresh output directories and run native suites sequentially. `--open-browser`
additionally dispatches the real repository link through the normal platform handler;
otherwise URL success/failure is injected so routine tests do not open browser tabs.
`--export` uses installed Linux export templates and adds a validation-only autoload
to a temporary viewer copy. It drives the normal exported Main scene; production
project settings contain no test autoload. Executables and packs stay outside Git.

Owner verification:

1. Confirm Help contains About SimScope and no standalone Version entry.
2. Open About before and after loading a capture; compare the full version with
   `python tools/application_version.py --json`. Check copyright and the distinct
   SimScope/Godot licensing summaries.
3. Open Licenses and notices, select each document, and return to About.
4. Open GitHub; with no working URL handler, use the displayed address.
5. Check 1440×900, 1920×1080 and a smaller window; check the standalone Linux build.
6. Close with the button/Esc and verify the existing session/view remains intact.

No license terms, repository visibility, release policy or compatibility contract
were changed. No release/tag is created; historical evidence remains unchanged.

## Validation record — 2026-09-28

On Linux x86_64 with Godot 4.7.2 and NVIDIA RTX 3070 Ti:

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| About, source | 98 passed | 99 passed (includes real URL dispatch) |
| About, standalone Linux | 98 passed | 98 passed |
| Existing viewer shell regression | 668 passed | 668 passed |

All 1,729 native assertions passed, with no native errors. The two Python version
contract tests passed. Notice drift checking, Python compilation, Markdown links
and all three executable documentation examples passed. Source capture hashes
were unchanged. The shell regressions were run before the final error-message
scroll timing adjustment; all four focused About runs include that adjustment.

About checks cover 1440×900, 1920×1080, 800×600 and 480×480, live identity changes
and missing metadata, every packaged notice against its canonical hash, logo
availability/aspect ratio, closing/Escape, session state and analysis-request
invariance. Visual inspection confirmed normal layouts, compact actions and the
browser-failure message. [Machine-readable evidence](evidence/issue-96/validation.json)
retains the reports; representative exported screenshots:
[1920×1080](evidence/issue-96/about-1920.png),
[compact actions](evidence/issue-96/about-actions-480.png),
[browser unavailable](evidence/issue-96/browser-unavailable.png).

Development failures and corrections: the first release test timed out because
it tried an editor-only script entry point; the final harness uses the normal Main
scene and a test-only autoload in a temporary export. An initial synthetic Escape
event bypassed Window handling; the corrected event uses the native window ID.
Initial layout review found hidden normal-size actions and a compact error message
below the scroll area; both were corrected and now have visibility assertions.
The original issue asset path was absent; the matching owner package supplied the
unchanged artwork. No production capture rerun was needed for this informational UI.

Limitations: export validation is Linux x86_64 only. The real platform URL handler
returned OK for the canonical repository URL; external browser page loading was
not observable. Missing-handler behavior is injected with ERR_UNAVAILABLE rather
than changing the user's browser configuration. Export validation uses the
validation-only autoload described above, not a separately distributed release.
Passing checks are not owner acceptance.

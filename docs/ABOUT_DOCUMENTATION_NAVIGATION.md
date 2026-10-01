# About documentation navigation — #171

Pending owner review. The sole Ready issue #171 started on the existing owner-linked
branch at accepted main `c1f7a51` (PR #170). Help now contains Shortcuts and About
WAVEZ. About contains separate repository and **Documentation** links; Documentation
opens `https://github.com/mongstad/Wavez#readme` through the platform browser handler.

The Handbook menu registration, file loading and command enablement were its only
runtime path and are removed. Shared Details infrastructure remains for File Details,
Shortcuts and load errors. No repository documentation file is removed and the root
README is unchanged. Handbook/status/About resource documentation now describes the
current entry point; historical design/review reports and evidence remain unchanged.

Both URLs share the same opening/error handler. If opening fails, About stays usable
and shows the actual requested URL for copying. Successful dispatch clears the error.
No scientific/session, licensing or runtime behavior changes. Version metadata stays
at accepted `v0.1.0.15` per this issue's explicit version-information boundary.

## Validation

Godot 4.7.2, Linux / NVIDIA RTX 3070 Ti:

- About Forward+ with real platform dispatch of both URLs: 120 checks PASS.
- About Compatibility: 118 checks PASS.
- Temporary packaged Linux release, normal Main scene with validation-only autoload,
  Forward+: 118 checks PASS; updated Help and both About links are present.
- Existing viewer shell: 659 checks PASS per renderer; current menu contract, shared
  Details, startup/lifecycle and source hashes preserved.
- 1440×900, 1920×1080, 800×600 and 480×480 About cases passed. Screenshots reviewed;
  desktop links are visible directly and compact fallback uses existing scrolling.
- Missing-handler simulation for both URLs and successful recovery passed; URL
  dispatch leaves scientific/session snapshots and committed sample unchanged.
- Notice hashes match canonical sources. Synthetic capture hashes unchanged.
- Documentation local links and three executable API examples PASS; version suite
  2/2 PASS; generated notices and whitespace checks PASS.

Initial failures: the first test assumed immediate visibility at 480×480; it was
corrected to exercise the existing scroll fallback. The first Linux package import
failed with Godot's dummy renderer `texture_2d_initialize` null-texture error; a fresh
retry imported/exported/ran successfully.

Limitations: the platform accepted both URLs, but the browser's final loaded page
and README anchor were not independently inspected. Packaged Compatibility, physical
mixed-DPI/4K and long-session checks were not run. No public release is produced.

## Owner verification

1. Launch with and without a capture on Forward+ and Compatibility. Help must contain
   Shortcuts and About WAVEZ, with no Handbook entry. Shortcuts and File Details should
   continue to work.
2. Open About. Click Documentation and confirm the browser reaches the Wavez README.
   Click the repository link and confirm it reaches the repository root.
3. Check normal and compact windows: links remain readable, with scroll access when
   needed; license actions, logo, version and runtime information remain intact.
4. Repeat in the packaged Linux build. If no browser handler is available, About
   should remain open with the requested URL available for copying.

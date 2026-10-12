# Third-party licenses and dependency notices

The root [Wavez license](LICENSE) applies to original Wavez material only.
Third-party software, libraries, fonts, palette data and tools retain their own
licenses, copyright notices and distribution obligations.

This inventory covers the source tree and the Linux standalone package. All
license links below are local paths preserved in the extracted package. The
packager copies original texts verbatim and checks their recorded digests;
[notice provenance](licenses/sources.json) identifies the audited sources.

## Godot runtime in the Linux standalone package

The executable embeds the official **Godot 4.7.2** Linux x86_64 release runtime
(`ed1daf0bf`). Its original MIT license is [GODOT_LICENSE.txt](GODOT_LICENSE.txt).
The complete upstream component copyright and license texts are in
[GODOT_COPYRIGHT.txt](GODOT_COPYRIGHT.txt), including Open Sans and other engine
components. This upstream inventory can include components not enabled in the
particular runtime; retaining it avoids shortening applicable notices.

Help → About → Licenses and notices also includes these canonical texts and the
running engine's own MIT/component information. No separate Godot installation
is required to run the standalone viewer. Godot remains an external development
and build dependency and is not vendored as an executable in this source tree.

## Bundled material

### Matplotlib-derived colormap lookup data

- **Location:** `viewer/colormaps.json`, generator `tools/generate_colormaps.py`.
- **Source route:** the current lookup table is generated from Matplotlib palette
  definitions. The retained upstream notice is
  [`viewer/COLORMAPS_LICENSE.txt`](viewer/COLORMAPS_LICENSE.txt).
- **Use:** display-only scalar lookup tables.
- **Changes:** palette definitions are sampled into 256 RGB entries, rounded to
  seven decimal places and stored as JSON. Matplotlib itself is not bundled.
  The full retained notices match Matplotlib 3.10.8; that version reproduces the
  current tables, but the original generation version was not recorded.
- **Obligation:** preserve the applicable Matplotlib and component notices. The
  generated palette data are not relicensed as original Wavez material.

### DejaVu Sans Mono 2.37

- **Location:** `viewer/ui/fonts/DejaVuSansMono.ttf`.
- **Notice:** [`viewer/ui/fonts/LICENSE-DejaVu.txt`](viewer/ui/fonts/LICENSE-DejaVu.txt).
- **Source note:** [`viewer/ui/fonts/README.md`](viewer/ui/fonts/README.md).
- **Use:** numeric typography in the optional UX component/theme library.
- **Modifications:** none recorded.

### Wavez SVG command icons

The SVG command icons under `viewer/ui/icons/` are original project assets recorded
by the accepted UX2 work and are covered as original Wavez material by the root
license.

The owner-supplied Wavez logo at `viewer/ui/about/wavez-logo-dark.png` is project
branding, not a third-party dependency. Its unchanged import is recorded in
[`viewer/ui/about/README.md`](viewer/ui/about/README.md); the existing
[branding policy](TRADEMARKS.md) applies.

About WAVEZ packages generated copies of the canonical notices as a Godot
resource for offline access. Run `python tools/sync_about_notices.py` after editing
the source notices, and `--check` to verify synchronization. Godot's MIT notice
and third-party component/license information are read from the running engine.

## External runtime/build dependencies — not vendored here

These dependencies are obtained separately and are not copied into this source
repository merely because Wavez can use them:

- **Python >= 3.10** — runtime for the Python package and analysis tools.
- **NumPy >= 1.23** — required Python runtime dependency.
- **scikit-image >= 0.26,<0.27** — optional analysis/isosurface dependency on
  supported Python versions.
- **backports.zstd >= 1.0** — optional Zstandard route on Python versions without
  `compression.zstd`.
- **setuptools >= 61** — build backend.
- **Godot Engine 4.7.x** — viewer runtime/development engine; Godot itself is not
  vendored in this repository.
- **FFmpeg** — optional external executable used by deterministic video export;
  Wavez invokes a separately installed executable and does not bundle FFmpeg
  in this source tree.

If a future release bundles Python wheels, a Godot executable/runtime, FFmpeg, or
other native libraries, include all notices and source-availability obligations
required by the exact artifacts shipped. A source checkout and a bundled desktop
application have different distribution inventories.

## Release rule

For every binary release, use `tools/package_linux.py` to assemble the archive
and checksum, then audit the exact uploaded ZIP. The workflow rejects missing or
changed upstream notices, an unaudited engine/template, stale About resources,
and unresolved local inventory links. Changing an audited dependency requires
reviewing its notices and updating their provenance/digests together.

Python, NumPy, scikit-image, compression packages and FFmpeg are not included in
the Linux ZIP. Only Wavez-owned analysis sources are included in the PCK. System
libraries and GPU/Vulkan drivers remain operating-system dependencies.

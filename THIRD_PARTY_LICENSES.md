# Third-party licenses and dependency notices

The root [SimScope license](LICENSE) applies to original SimScope material only.
Third-party software, libraries, fonts, palette data and tools retain their own
licenses, copyright notices and distribution obligations.

This inventory describes the current source tree. A future binary/installer
release must also be audited against the exact binaries and dependency versions
actually shipped.

## Bundled material

### Matplotlib-derived colormap lookup data

- **Location:** `viewer/colormaps.json`, generator `tools/generate_colormaps.py`.
- **Source route:** the current lookup table is generated from Matplotlib palette
  definitions. The retained upstream notice is
  [`viewer/COLORMAPS_LICENSE.txt`](viewer/COLORMAPS_LICENSE.txt).
- **Use:** display-only scalar lookup tables.
- **Obligation:** preserve the applicable Matplotlib and component notices. The
  generated palette data are not relicensed as original SimScope material.

### DejaVu Sans Mono 2.37

- **Location:** `viewer/ui/fonts/DejaVuSansMono.ttf`.
- **Notice:** [`viewer/ui/fonts/LICENSE-DejaVu.txt`](viewer/ui/fonts/LICENSE-DejaVu.txt).
- **Source note:** [`viewer/ui/fonts/README.md`](viewer/ui/fonts/README.md).
- **Use:** numeric typography in the optional UX component/theme library.
- **Modifications:** none recorded.

### SimScope SVG command icons

The SVG command icons under `viewer/ui/icons/` are original project assets recorded
by the accepted UX2 work and are covered as original SimScope material by the root
license.

## External runtime/build dependencies — not vendored here

These dependencies are obtained separately and are not copied into this source
repository merely because SimScope can use them:

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
  SimScope invokes a separately installed executable and does not bundle FFmpeg
  in this source tree.

If a future release bundles Python wheels, a Godot executable/runtime, FFmpeg, or
other native libraries, include all notices and source-availability obligations
required by the exact artifacts shipped. A source checkout and a bundled desktop
application have different distribution inventories.

## Release rule

Before a public binary release, generate an artifact-specific third-party inventory
from the actual package/engine/encoder build. Do not assume this source-tree list
is sufficient for a bundled executable or installer.

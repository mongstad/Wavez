# Notice provenance and maintenance

The four `.txt` files here are the canonical, unmodified upstream legal texts.
Their source URLs, audited versions and SHA-256 digests are in `sources.json`.
The same paths are used in the source checkout and extracted standalone ZIP.
Wavez's own `LICENSE` and `TRADEMARKS.md` remain at the root.

## Distribution obligation audit (#397)

Before relocation, the retained texts and original upstream terms were reviewed:

- [Godot MIT](https://github.com/godotengine/godot/blob/ed1daf0bf/LICENSE.txt)
  requires copyright and permission notices with copies/substantial portions.
  `GODOT_COPYRIGHT.txt` preserves the complete component inventory and its
  individual terms, including binary-distribution documentation notices. Both
  complete files accompany the executable in this folder and offline About.
- [DejaVu 2.37](https://github.com/dejavu-fonts/dejavu-fonts/blob/version_2_37/LICENSE)
  requires copyright/trademark and permission notices with distributed fonts.
  The full text, including Arev and other retained notices, accompanies the
  unchanged font in the package and offline About. No font rename is involved.
- [Matplotlib 3.10.8](https://matplotlib.org/3.10.8/project/license.html)
  requires retaining the agreement/copyright and a brief summary of derivative
  changes. The inventory retains the sampling/rounding summary; the complete
  existing license bundle retains its component notices, including binary
  documentation obligations.

These audited terms require accompanying notices, not the former root or
`viewer/` notice filenames. No legal text, asset, attribution or upstream digest
was changed by relocation. All retained component terms remain in the full files;
this summary does not replace them. No new third-party component is bundled.

## Packaging checks

`tools/distribution_licenses.py` verifies pinned notice bytes, the audited Godot
release template, inventory links, member readability and complete manifest
coverage. `tools/package_linux.py` copies these canonical paths into the ZIP and
checks actual exported offline About texts headlessly. After changing inventory
or notice sources, run `python tools/sync_about_notices.py` and `--check`.
Changes to an audited dependency require reviewing its obligations and pins.
Original notices must never be shortened or reformatted.

The owner-reported v0.1.0.107 Markdown viewer blocked local navigation while
opening a notice directly worked. That is reader-specific evidence, not a claim
about all readers. The inventory therefore supplies both links and literal paths.

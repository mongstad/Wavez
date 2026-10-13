# Third-party licenses and notices

Wavez's original code and assets use the [PolyForm Noncommercial license](LICENSE)
(`LICENSE`). The name and artwork follow the [branding policy](TRADEMARKS.md)
(`TRADEMARKS.md`). These files remain in the package root; they do not relicense
third-party material.

## Included components

Full original third-party texts are in `licenses/`, in both the source checkout
and the extracted Linux package. Paths below are relative to this file.

| Component | License / notice | Open this file |
|---|---|---|
| Godot 4.7.2 runtime included in the standalone viewer | MIT | [Godot license](licenses/GODOT_LICENSE.txt) — `licenses/GODOT_LICENSE.txt` |
| Godot runtime components, including Open Sans | Complete upstream copyright and license inventory | [Component notices](licenses/GODOT_COPYRIGHT.txt) — `licenses/GODOT_COPYRIGHT.txt` |
| DejaVu Sans Mono 2.37 font | Bitstream Vera / Arev notices; DejaVu changes are public domain | [Font notices](licenses/LICENSE-DejaVu.txt) — `licenses/LICENSE-DejaVu.txt` |
| Matplotlib-derived colormap data | Matplotlib and retained component notices | [Colormap notices](licenses/COLORMAPS_LICENSE.txt) — `licenses/COLORMAPS_LICENSE.txt` |

Colormap definitions are sampled into 256 RGB entries, rounded to seven decimal
places and stored as JSON. Matplotlib itself is not included. The notices match
Matplotlib 3.10.8; the original generation version was not recorded. The DejaVu
font is unmodified. Godot's complete inventory may also name components not
enabled in this runtime.

## Open notices offline

Open the `licenses` folder beside this file and open any `.txt` file with a text
editor. Markdown readers differ: some block local links. If clicking a link does
nothing, use the literal filename in the table above. No GitHub access is needed.
Help → About → Licenses and notices also contains the full texts offline.

## Separately installed tools

Python, NumPy, scikit-image, backports.zstd, setuptools and FFmpeg are external
dependencies with their own licenses; they are not included in the Linux package.
Godot is externally installed for source development; its runtime is included in
the standalone viewer. System libraries and GPU drivers are supplied by the OS.

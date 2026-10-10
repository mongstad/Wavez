# About resources

The current About repository link displays `github.com/mongstad/Wavez` and opens
`https://github.com/mongstad/Wavez` (#164). The adjacent **Documentation** link
opens `https://github.com/mongstad/Wavez#readme` (#171), replacing the removed
in-app Help → Handbook route. Both links use the platform browser handler and
show a copyable requested URL if it is unavailable.

## Current About banners (#318)

About uses the unchanged owner-approved, slogan-free, borderless banners from
`Wavez_ThemeBranding` outside the Git root. Both are 2172 × 724 RGB PNGs; their
provided backgrounds are retained, with no image alteration or transparency added.

| Active application theme | Canonical resource in this directory | SHA-256 |
| --- | --- | --- |
| Light | `Wavez_Banner_No_Slogan_No_Border_White.png` | `77b60b43c1d26e0d14b83c201475c30630774fbac80383705784e3257cd34800` |
| Dark | `Wavez_Banner_No_Slogan_No_Border_Dark.png` | `81426cb5a6b248a7f1948d86c911fb7147bd8f31dc53ded1d696b40edcd1b9e4` |

Both resources are preloaded into the exported PCK. The existing application-theme
refresh selects the active banner immediately, including while About is visible;
reopening uses that selection. Lossless mipmapped imports retain image quality.
The existing image slot is widened from 112 to 216 logical pixels, retaining its
112-pixel minimum height and centered aspect-preserving fit (216 × 72 artwork). About's
580 × 592 preferred dialog, other content, fonts, close controls and scrolling
remain unchanged. Compact layouts can use the existing vertical scrolling.

The root README points directly to the canonical **Dark** resource with its exact
filename, for every GitHub viewer theme. The former README banner is moved here
byte-for-byte, avoiding a duplicate. The unused Light square and its import are
retired; the Dark square remains the unchanged application icon. Branding stays
governed by [TRADEMARKS.md](../../../TRADEMARKS.md); no new third-party asset is added.
See [review evidence](../../../docs/evidence/issue-318/README.md).

## Previous square artwork (#155)

`wavez-logo-dark.png` is copied byte-for-byte from the owner-approved
`Wavez_ThemeBranding/Dark_Mode/Wavez_Square_Logo_No_Slogan_No_Border_Dark.png`.
It is a 1254 × 1254 PNG, SHA-256
`4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3`.
The #155 About layout used this square with aspect-preserving, lossless mipmapped fitting.
This resource remains the application icon. The resource import UID is retained.
No image recreation or restyling was performed; the approved dark artwork is unchanged.
The README uses the unchanged dark, no-slogan banner from the same package
(2172 × 724, SHA-256
`81426cb5a6b248a7f1948d86c911fb7147bd8f31dc53ded1d696b40edcd1b9e4`).
[TRADEMARKS.md](../../../TRADEMARKS.md) governs both assets.

## Previous Light square artwork (#289)

`wavez-logo-light.png` is copied byte-for-byte from the owner-approved
`Wavez_ThemeBranding/Light_Mode/Wavez_Square_Logo_No_Slogan_No_Border_White.png`
in the real project folder outside the Git root. It is a 1254 × 1254 PNG,
SHA-256 `fb48a4c75fb4c48800b21cad4541430611bccc83d46a4a580ff3d50bc39c8ddf`.
The branding pack contains no separate license file; the existing owner branding
policy in [TRADEMARKS.md](../../../TRADEMARKS.md) applies. The issue expressly
authorizes this official artwork. It is not a new third-party dependency.

The #289 About implementation preloaded both square images and switched with the
local application theme in a 112 × 112 aspect-preserving control. Issue #318
replaces that About artwork with the banners above; the Dark application icon
remains unchanged. No absolute workstation path is used at runtime. See
[application themes](../../../docs/APPLICATION_THEMES.md).

## Historical #147 artwork provenance

The then-current `wavez-logo.png` is the owner-provided violet artwork requested
by #147, copied unchanged from
`WAVEZ Theme Package/WAVEZ_Logo_Purple.png` outside the repository.

- Source/import SHA-256: `b666a782e6f3a482ae8e87bee5231aaaa7b7711e4d2ba7a91362f7cbdc6e9722`
- Dimensions: 1254 × 1254; original PNG bytes retained.
- The runtime path, import UID, lossless mipmapped import and aspect-preserving
  About layout remain unchanged. Only About consumes this resource.
- Branding remains governed by [TRADEMARKS.md](../../../TRADEMARKS.md).

## Original #96 asset provenance

The following records the original About artwork, replaced by #147:

`wavez-logo.png` is the owner-provided artwork named in issue #96:
`ChatGPT Image Sep 12, 2026, 04_04_12 PM (1).png`. The file had moved into the
owner's `WAVEZ-Logo-Package` directory when imported. It was copied unchanged;
no cropping, recreation or restyling was performed.

- Source/import SHA-256: `61de3bc7c7f6ee61bbfc5a589a7c1de57de02fc56fbb1f332ae04818c9554d03`
- Dimensions: 1254 × 1254; original PNG bytes retained.
- Runtime path: `res://ui/about/wavez-logo.png`, explicitly preloaded by About.
- Godot import: lossless texture with mipmaps for compact display; aspect ratio retained.
- Branding remains governed by [TRADEMARKS.md](../../../TRADEMARKS.md).

`notices.tres` is generated by [sync_about_notices.py](../../../tools/sync_about_notices.py)
from the canonical repository license, third-party inventory, branding policy,
colormap notices and font notices. Edit those sources, regenerate, then run
`python tools/sync_about_notices.py --check`. Runtime checks compare each displayed
notice's hash with its source. The resource is explicitly preloaded, so exports
include it without custom filters or paths outside the application.

Godot runtime copyright/component notices and license texts are obtained from
the running Engine API, keeping the acknowledgement specific to that runtime.

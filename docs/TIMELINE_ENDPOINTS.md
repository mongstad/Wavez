# Timeline endpoint alignment — #136

Pending owner review; candidate **v0.1.0.7**. #136 was the only Ready Project item.
The existing issue-linked branch was clean at accepted main `dd706ca` (merged
PR #140). Local main, origin/main and the linked branch matched. Remote refs were
pruned; the completed #97 local branch was already absent.

## Cause and correction

The native HSlider reserved half the 16-pixel grabber texture at each end of its
travel, while the native track and prepared-coverage overlay filled the control.
Rendered pixels confirmed **+8 px at the start and −8 px at the end** at normal
scale, with zero midpoint error. The error grew with UI scale.

The prepared timeline now overrides the native `center_grabber` theme constant.
This makes both native drawing and pointer mapping use the full track width;
there is no sample/time compensation. The adjacent time readouts reserve half
the actual themed grabber width plus their existing gap, so the circular handle
can straddle the endpoint without colliding with text. Other sliders are unchanged.

This follows [Godot's Slider implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/gui/slider.cpp),
where `center_grabber` controls both input travel and rendered handle placement.
The existing overlay already reads this constant; its endpoint and intermediate
mapping code is unchanged. No source timestamps, playback extent, seek/loop/reverse
semantics, worker/cache policy or preparation behavior changed.

Before, final position:

![Before: handle inset from right endpoint](evidence/issue-136/before-right.png)

After, final position:

![After: handle centred on right endpoint](evidence/issue-136/after-right.png)

After, first position:

![After: handle centred on left endpoint](evidence/issue-136/after-left.png)

## Validation

[Evidence ledger](evidence/issue-136/validation.json) contains before/after pixel
measurements and transport reports. Godot 4.7.2 / Linux x86_64 / RTX 3070 Ti.

- **104 geometry checks per renderer**, Forward+ and Compatibility: rendered
  first/middle/final centres, prepared coverage at both ends, actual native
  pointer dragging, Home/End/arrow navigation and unequal-time sample-index mapping.
- Geometry matrix: 200/600 logical pixel widths at 100%, 125%, 150%, 200% scale.
  All 24 rendered positions per backend have **0 px measured centre error**.
- **210 transport checks passed per renderer**. The full suite checks exact first/final recorded timestamps and indices,
  fractional seek, delayed seeks, reverse, looping, playback controls, sample hints,
  fullscreen, and 1440×900 / 1024×640 layouts including time-readout clearance.
- **81 rolling-cache checks passed headless**, including prepared spans/islands,
  endpoint/midpoint axis mapping, reclaim/protection and unchanged fixture SHA-256.
- Two application-version tests, Godot import, Python compilation, Markdown links,
  three executable documentation examples and whitespace checks passed.

Development test corrections: the first geometry script required explicit float
annotations for two inferred values. Initial coverage pixel probes hit the native
track outline; probes moved three pixels inside that outline. Before/after use the
same corrected measurement. These were test-harness errors, not changes to source
or coverage semantics.

Limits: UI scale is exercised through the rendered control transform, not a
physical mixed-DPI monitor matrix. No Windows/macOS, packaged application or
production-size scientific rerun. Synthetic source hashes are checked by the
transport and rolling suites. Historical reports remain unchanged; automated
results do not imply owner acceptance.

## Reproduction and owner checks

```sh
python tools/validate_timeline_geometry.py --godot /path/to/godot --output-dir /tmp/timeline-geometry
python tools/validate_timeline_geometry.py --godot /path/to/godot --output-dir /tmp/timeline-geometry-compat --renderer gl_compatibility
python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir /tmp/timeline-transport
python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir /tmp/timeline-transport-compat --renderer gl_compatibility
python tools/validate_rolling_cache.py --godot /path/to/godot --output-dir /tmp/timeline-rolling
```

1. Open a capture and seek to first/final samples: the circular handle centre must
   meet each visible track endpoint, with no text overlap or clipped circle.
2. Drag through the midpoint and both ends; try Home/End and arrow keys with the
   slider focused. Verify sample selection and time readouts.
3. Inspect prepared coverage at both ends and through gaps. Check forward/reverse
   playback and looping, at normal/compact sizes and the preferred desktop scale.
4. Review both renderers if used. No tooltip, marker or second buffer bar was added.

Stop for owner review; no merge, auto-merge, issue closure or Project changes.

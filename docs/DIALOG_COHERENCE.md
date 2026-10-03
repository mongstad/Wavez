# File and Tools dialog coherence — issue #161

Candidate build **v0.1.0.33** is pending owner visual review. The File and Tools
menu routes were audited against the current registration in
`viewer/ui/shell/viewer_shell.gd`. #160 removed Quick setup before this work;
there is no Quick setup menu entry or form. #181's accepted **Open File** native
picker and single **WAVEZ Scene Format** (`*.wvz`) filter remain authoritative.

The old shared Tools host opened almost every page at 600×720 regardless of
content and put the loaded filename above the form and the viewer status beneath
it. The host now uses the shell's violet theme, a square Wavez surface, a
matching header/X, a compact action row and a scrolling content area. It sizes
from the visible form, capped at 620 logical pixels high and the desktop extent.
The common source heading is gone. Tool-specific status remains only when it
reports an actual task state; Mapping has no duplicate status footer. Diagnostics
opens on Import CSV, showing its shared Name field, task selector and import
controls together. The original widgets, signals and controllers remain in
place. Closing a Tool still leaves active work running and restores focus.

## Menu route inventory

Dimensions are logical pixels measured at 1440×900 on Forward+ with the mixed
synthetic WVZ1 fixture. The old Tools size is the accepted main host default;
native filesystem picker dimensions belong to the desktop. “Custom” means the
application owns the surface. Scientific calculations and action semantics did
not change.

| Menu path | Dialog/tool | Before | After | Surface and text change | Functional change |
| --- | --- | ---: | ---: | --- | --- |
| File → Open file… | Open File | OS managed | OS managed | Accepted #181 native picker, unchanged | None |
| File → Details… | Source details | Godot content size | 560×360 | Custom Wavez header, scrolling text, right-aligned Close; source identity retained here | None |
| File → State → Save view preset… | Save preset | OS managed | OS managed | Existing native picker, unchanged | None |
| File → State → Load view preset… | Load preset | OS managed | OS managed | Existing native picker, unchanged | None |
| File → State → Save analysis | Analysis state | 600×720 | 560×506 | Custom host, Save beside Close; duplicate source heading removed | None |
| File → State → Load analysis | Analysis state | 600×720 | 560×466 | Custom host, Load beside Close; duplicate source heading removed | None |
| File → State → Resolve input | Referenced input | 70% viewport | OS managed | Native filesystem picker | None |
| File → Export → Image | Image options | 600×720 | 560×240 | Custom compact form, Save image… beside Close | None |
| File → Export → Video | Video options | 760×800 | 700×650 | Custom square form, scrollable settings, fixed estimate/progress/actions | None |
| File → Export → Data | Numerical data | 600×720 | 560×620 | Custom host, Export beside Close; long limits scroll | None |
| Tools → Selection | Selection | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Temporal | Temporal | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Space time | Space time | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Diagnostics | Diagnostics | 600×720 | 440×620 | Custom host; Import CSV shown first; Import beside Close; duplicate explanatory footer removed | None |
| Tools → Analysis → Compare | Compare | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Matched runs | Matched runs | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Period | Period | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Analysis → Bookmarks | Bookmarks | 600×720 | 560×464 | Custom content-sized host | None |
| Tools → Analysis → Results | Results | 600×720 | 560×620 | Custom host; source heading removed | None |
| Tools → Mapping | Mapping | 600×720 | 440×240 | Three aligned toggles; filename/status removed; Close near content | None |
| Tools → Derive range | Derive range | 600×720 | 560×384 | Custom content-sized host | None |
| Tools → Slice | Slice | 600×720 | 440×247 | Custom content-sized host | None |
| Tools → Clipping | Clipping | 600×720 | 440×620 | Custom scrolling host | None |
| Tools → Isosurface | Isosurface | 600×720 | 560×620 | Custom scrolling host | None |
| Tools → Source probe | Source probe | 600×720 | 440×578 | Custom content-sized host | None |
| Tools → Performance | Performance | 600×720 | 560×620 | Custom scrolling host | None |
| Tools → Geometry | Geometry | 600×720 | 440×620 | Custom scrolling host | None |

File → State → Copy state and File → Exit do not open dialogs. Help → About
already has a custom Wavez surface and does not share this Tools host. The
Navigate/Viewing **Camera** and **Global effects** forms do share the host and
therefore receive the same styling and sizing.

## Filesystem selection

The application-owned forms above stay custom. Their genuine file-selection
steps now request the native system picker when supported: Image folder, Video
MP4 destination, Diagnostics CSV/TSV, Geometry JSON override, numerical export
parent folder, inspection bundle parent folder, inspection JSON load,
referenced input, matched-run inspection JSON and output folder. Titles and
existing type filters remain operation-specific. Godot's built-in FileDialog
is the fallback where native integration is unavailable; #181's scene-open
picker was not modified. Native desktop bookmarks, Recent locations,
accessibility, and Open/Save/Cancel belong to the OS picker. Video's existing
overwrite confirmation and export settings semantics remain intact.

## Visual review

Representative unobstructed Forward+ captures from the candidate:

- [Mapping](evidence/issue-161/mapping.png)
- [Diagnostics](evidence/issue-161/diagnostics.png)
- [File → Export → Image](evidence/issue-161/image.png)
- [File → Details](evidence/issue-161/file-details.png)
- [Tools → Performance](evidence/issue-161/performance.png)
- [File → Export → Video](evidence/issue-161/video-export.png)
- [Video cancellation confirmation](evidence/issue-161/cancel-video.png)

The screenshots show the synthetic fixture and no production scientific data.
The separate desktop-native file picker is OS-owned, so it intentionally does
not use the Wavez shell appearance.

## Validation and limits

The focused dialog harness opened all 21 custom File/Tools destinations at
1440×900 and 1024×640, checked bounds, shared style, absence of duplicate
source headings, the native scene/MP4 picker contracts and unchanged fixture
bytes. **118 checks passed on each of Forward+ and Compatibility.** The
same **118 checks passed in a standalone Linux test package on each renderer**;
the normal owner-review package also imported, exported and started cleanly on
both renderers. The
existing focused Tools suite passed **1,904 checks per renderer**, preserving
scientific and request state. The File menu shell suite passed **662 checks per
renderer**. The picker suite passed **105 checks on Forward+ Wayland** and **105
on Compatibility X11**; the latter retained 12 known GL shutdown diagnostics
already attributed to the accepted engine path. A Compatibility Wayland
baseline process wrote its passing two-check report but stalled on shutdown;
that specific combination remains inconclusive. The directly affected
video/status lifecycle passed **257 checks on Forward+**, including export
start, backgrounding, cancellation and retained Details. The Fullscreen Tools,
File Details and scientific-state suite passed **75 checks on Forward+**, and
the violet widget review passed **52 checks on Forward+**. Native desktop portal details,
physical 4K/mixed-DPI behavior, assistive technology and long-session use still
need owner review.

Historical #50 and #181 reports and their review-time wording are unchanged.

## Owner verification

1. At normal and minimum window sizes, open Mapping, Diagnostics, File →
   Details, File → Export → Image/Video, and a long Tools form such as
   Performance. Judge coherence, spacing, scroll behavior and action placement.
2. In Diagnostics, confirm Name, Import CSV controls and Import/Close actions;
   switch sections and use Tab, Enter, Esc and the X. Check that closing a Tool
   leaves an active job running and returns focus.
3. Open a `.wvz` through File → Open file… and confirm #181's native picker,
   one WVZ filter, bookmark/recent behavior and successful/cancelled open.
4. Use Video → Browse…, Diagnostics → Choose CSV, Geometry → Load override and
   Image → Save image… to inspect native titles, filters, filesystem navigation,
   cancellation and overwrite behavior on the owner desktop.
5. Check representative small and large content on Forward+ and Compatibility,
   especially physical 4K and mixed display scaling. In Fullscreen, open and
   close Tools and File Details; start a video export, inspect the cancellation
   confirmation, then keep the job in the background.

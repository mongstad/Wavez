# Dialog title and section hierarchy

Issue #271 proposes a shared hierarchy treatment in candidate **v0.1.0.60**,
pending owner visual review. Dialog/panel titles use clear lavender `#c5a6ff`;
titled-group/category headers use the slightly quieter violet `#aa91df` in the same hue family.

The shared tokens `text.title` and `text.section` live in
`viewer/ui/theme/wavez_tokens.gd`. The theme builder assigns them to
`PanelTitle.font_color`, `Window.title_color` and `SectionTitle.font_color`.
The production violet theme inherits these assignments. Existing shared
headings in Keyboard Shortcuts, Video Export, File Details, File Locations,
Tools and Jobs inherit them without per-dialog colors. Future forms using
these variations or the reusable titled group receive the same hierarchy.
Native OS file-picker titles remain desktop-owned.

Ordinary labels, values and controls retain neutral text. Font sizes, layout,
spacing, group order, borders, hover/focus/selection, disabled text, tooltip
behavior and operational/scientific colors are unchanged. Section-header
buttons/disclosures retain their existing interaction styling.

[Revised evidence and screenshots](evidence/issue-271/revision-2/README.md) cover normal,
compact and simulated high scaling. Physical 4K and mixed-DPI acceptance remains
an owner check.

## Owner verification

1. Open **Edit → Preferences → Keyboard Shortcuts** at the normal size and at
   970 × 600 or smaller. Compare title, Navigation/Playback/File/Tools/Interface
   headers, ordinary labels and disabled Clear/Apply text. Scroll through every
   category and judge whether the accents make the hierarchy immediately visible while keeping row labels neutral.
2. Tab between rows and categories, hover binding/Clear buttons, start a key
   capture, cancel with Escape, and confirm focus/selection remain distinct.
   Check the fixed footer and tooltip-free behavior.
3. With a small capture open, choose **File → Export → Video**. Inspect Range,
   Video, Camera, Presentation, Output and Export summary; scroll and resize.
   Compare disabled preset values, hover a dropdown and check its selection.
4. Open **File → Details**, **Edit → Preferences → File Locations**, **Tools →
   Mapping** and **Jobs** to judge the inherited title treatment. Check normal
   and preferred high display scaling, especially a physical 4K/mixed-DPI setup.

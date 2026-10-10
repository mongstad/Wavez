# Dialog action buttons

Issue #325 proposes **v0.1.0.87**. Neutral actions in Wavez-owned dialogs use
`DialogButton` or `DialogSecondaryButton`: an existing `surface.2` fill and
one-pixel `border.control` outline make the unfocused action recognizable.
The previous normal Button surface was transparent; SecondaryButton used the
same surface as several dialog bodies without a border.

These roles inherit their original Button/SecondaryButton hover, pressed,
hover-pressed, disabled, focus, fonts, ink and metrics. The focus ring retains
its existing resource and geometry; it overlays the new resting surface when
focused without hover. Primary/destructive actions, selected shortcut capture,
header X controls, links, toggles and selectors keep their existing roles.
Dialog owners opt in explicitly, including AcceptDialog's internal action
buttons. Deferred Tools forms opt in when opened. Existing global button styles
and main-shell, inspector, category, panel and transport controls are unchanged.
No actions, content, tooltips, signal connections or scientific/export paths
are added or changed.

[The audit and evidence](evidence/issue-325/README.md) list inspected routes,
before/after Dark and Light screenshots, state/geometry comparisons, native
and packaged validation, and owner review steps. Earlier dialog/theme/video
reports retain their historical review-time claims.

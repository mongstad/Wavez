# Application themes

Edit → Preferences → Theme offers **Dark** and **Light**, including before a
capture is opened. Selection takes effect immediately and is saved locally in
`user://appearance.cfg`. A missing preference uses Dark. An unreadable preference
reports a warning and uses Dark; a failed save leaves the active choice unchanged.
This preference is not included in WVZ captures, portable view presets or export
state. Offline rendering workers do not read it.

Light uses differentiated cool-gray surfaces and deeper purple heading/accent
ink. The darker foundation keeps panels from reading as a white sheet; brighter
panel highlights preserve separation from inputs and dialog surfaces. Shared
semantic roles apply across the shell, inspector groups and dialogs:

| Role | Previous Light | Current Light |
| --- | --- | --- |
| Foundation / gradient shade | `#E6E8EF` | `#E1E3EA` |
| Atmosphere end | `#E1E4ED` | `#D9DDE6` |
| Panel fill / gradient highlight | `#F0F1F5` | `#EEF0F5` |
| Input / dropdown fill | `#E2E5ED` | `#D6DBE6` |
| Dialog surface | `#ECEEF3` | `#E5E8EF` |
| Hover / selection | `#DDD5F0` | `#DCD4EC` |
| Pressed surface | `#D8CFEC` | `#D9D0E9` |
| Title / section ink | `#7050B8` | `#563493` |
| Primary accent | `#7956C8` | `#563493` |
| Selected ink | `#51358E` | `#452776` |
| Secondary / muted ink | `#4C576E` / `#5C667D` | `#414E65` / `#4E596D` |
| Active control / decorative border | `#757D94` / `#D6D8E5` | `#626E85` / `#B7BECD` |

Primary/numeric ink (`#25283A`), focus (`#596DBC`), disabled ink, tier/status
colors, and the separate identity-purple/teal roles are retained. Success, warning
and error keep separate green, amber and red meanings. Light dropdowns and editable
inputs gain a one-pixel active boundary within their existing margins. Enabled
switches use white knobs against their tracks; slider thumbs retain their purple
body with a white outline where it crosses the darker track. Dimensions, fonts,
spacing and interactions stay the same. Hover, pressed, focused and inactive
states remain distinct; subtle panel borders are decorative, rather than the
sole signal of an interactive control.

The **Simulation** heading and all three pin accents share `accent.primary` in
Light (`#563493`). The owner approved this shared deeper-purple option after
reviewing the flagged alternatives for issue #320, before pin colors were changed.
`SimulationTitle` still inherits `PanelTitle` typography. Pin glyphs, state behavior
and hover motion remain unchanged. Dark keeps `#7270D8`, its original surfaces
and artwork. The earlier #316 measurement record remains historical:
[heading/pin consistency evidence](evidence/issue-316/README.md).

The actual Light Simulation gradient samples give **7.91–7.98:1**, compared with
**4.64–4.68:1** before this refinement. Rendered dropdown text samples give
**7.49–10.17:1** across active normal/hover/pressed states, including the existing
resting 0.94 control tint. Read-only and disabled states are documented separately.
The 119 semantic-pair checks and production-control measurements target
[WCAG 2.2 normal-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [meaningful non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
where applicable. Inactive controls and decorative boundaries have applicable
exceptions. These checks establish contrast headroom for the measured pairs,
not complete accessibility certification or proof of prolonged viewing comfort.
The pressed lavender remains slightly brighter than an early proposal to retain
contrast for semantic status ink. Physical KDE/4K comfort remains owner review.
See [issue #320 before/after screenshots, state measurements and tradeoffs](evidence/issue-320/README.md).

About uses `Wavez_Banner_No_Slogan_No_Border_White.png` in Light and
`Wavez_Banner_No_Slogan_No_Border_Dark.png` in Dark, switching immediately without
restarting or reloading a capture. Both approved banners retain their original
bytes, backgrounds and 3:1 proportions in a centered fit. The application icon
stays the Dark square; the repository README always uses the Dark banner.
See [About resource provenance](../viewer/ui/about/README.md) and
[issue #318 review evidence](evidence/issue-318/README.md).

Wavez-owned top-right dialog X controls share the shell close glyph, hit area and
state styling in both themes. Their visible keyboard focus stays inside the close
hit area; see [dialog close controls](DIALOG_CLOSE_CONTROLS.md).

Both variants use the existing base/violet theme builders and identical control
metrics. Local presentation overrides retain their geometry and original dark
resources. Theme changes and newly created or restyled controls trigger a
coalesced refresh; there is no per-frame theme process or added animation.
Scientific legends, color bars and screenshot notices are excluded, and shared
scientific theme resources are never mutated. Particle, field and mesh styles,
colormaps, camera state, source clocks and scientific export settings are untouched.

Native operating-system file pickers retain the accepted native integration and
follow the desktop's own theme. The embedded Godot fallback uses the application
palette while retaining its native widget metrics. Wavez does not change KDE's
system appearance setting.

Review evidence and known limitations are recorded in
[original theme evidence](evidence/issue-289/README.md) and the
[issue #310 palette review](evidence/issue-310/README.md). Physical 4K/KDE
comfort, scaling and owner interaction review remain required for the new palette.

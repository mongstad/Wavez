# Application themes

Edit → Preferences → Theme offers **Dark** and **Light**, including before a
capture is opened. Selection takes effect immediately and is saved locally in
`user://appearance.cfg`. A missing preference uses Dark. An unreadable preference
reports a warning and uses Dark; a failed save leaves the active choice unchanged.
This preference is not included in WVZ captures, portable view presets or export
state. Offline rendering workers do not read it.

Light uses the approved off-white, violet, periwinkle and deep-ink palette.
The focus ring is a darker periwinkle (`#687BCE`) for contrast on off-white.
Success, warning and error retain separate green, amber and red roles. Dark keeps
its original palette. About switches between the two official branding assets
without restarting or reloading a capture.

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
[issue #289 evidence](evidence/issue-289/README.md). Physical 4K/KDE scaling and
owner interaction review remain required before acceptance.

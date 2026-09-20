# Issue #41 native shell evidence

Pending owner review. Godot 4.7.2 on NVIDIA RTX 3070 Ti; native production UI,
synthetic SSC captures. [Implementation, limits and exact owner checks](../../UX3_SHELL.md).

[Machine-readable results](summary.json) record 79 passing shell checks per GPU
backend, verified logical dimensions, source-hash invariance and no instrumented
scientific activity during repeated shell layout/workspace transitions. Separate
existing regressions passed 3,051 recipe, 13,044 camera and 28 maintenance checks.

| Native Forward+ capture | Purpose |
|---|---|
| [Empty](empty.png) | Open action without dummy scientific forms |
| [1440×900](loaded-1440.png) | Command bar, desktop workspace navigation, retained inspector |
| [1024×640](loaded-1024.png) | Compact chooser and dock child bounds |
| [Appearance entry points](appearance-1440.png) | Bounded adapter, no full UX4 migration |
| [Failed replacement](failed-open.png) | Prior scene retained; durable failure survives later unrelated information |

The current context header is capture-level. Playback remains in the inspector.
The visible scene uses the existing full-frame camera projection. These screenshots
are UI evidence, not scientific-render or whole-application acceptance. Full raw
logs, fixtures and transient generated recipes remain ignored under `results/`.
Earlier reports and evidence are not rewritten.

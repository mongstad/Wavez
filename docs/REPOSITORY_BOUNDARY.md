# SimScope repository boundary

SimScope contains the capture/export library, Godot viewer, current specifications,
small repository-owned examples, regression tests and development tools.

Scientific simulations, research notebooks, generated captures, benchmark source
datasets, videos, screenshots, large result tables, local environments and caches
belong outside this repository. Integration and benchmark suites may consume
SimScope as a dependency through explicit paths or installed packages; they must
not become hidden product dependencies.

## Included

- `simscope_export/` — production Python library and analysis code
- `viewer/` — production Godot viewer, shaders, bundled UI assets and native tests
- `examples/` — small synthetic examples owned by this repository
- `tests/` — deterministic Python fixtures/regressions
- `tools/` — validators, import/export helpers and profilers
- `docs/` and root Markdown specifications — current product documentation and
  accepted development reports

## Excluded

- scientific solvers and research projects
- raw or generated scientific datasets
- `.ssc`, NPZ and other generated captures unless a deliberately tiny fixture is
  explicitly reviewed for inclusion
- benchmark payload archives and release assets
- generated videos/screenshots and local profiling output
- virtual environments, caches, credentials and machine-specific configuration

The package discovery rule includes only `simscope_export*`. New integrations
should use the public scene/capture API rather than copying simulator-specific
source into this repository.

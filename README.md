# SimScope

SimScope is a NumPy-first scientific capture and Godot visualization platform for
particles, meshes and uniform-grid scalar fields. New integrations use
`SceneCapture` / `SceneReader` and the SIMSCP3 (`.ssc`) capture format.

G0–G4 are implemented and accepted. The current viewer includes deterministic
video export, scientific inspection/analysis, bounded playback preparation, and
particle/mesh/volume rendering. UX1 and UX2 are accepted. The accepted UX3
[production shell](docs/UX3_SHELL.md) now hosts the [persistent transport](docs/UX3_TRANSPORT.md)
and [persistent status and Jobs](docs/UX3_STATUS.md). Recorded-time playback,
[media timing](docs/UX3_MEDIA_TRANSPORT.md), [delayed seek feedback](docs/UX3_TRANSIENT_STATUS.md),
[immersive fullscreen](docs/UX3_FULLSCREEN.md) and production-shell video overlays
are owner-merged, including final [UX3 integration validation](docs/UX3_REPORT.md)
in PR #64. The [UX4 design](docs/UX4_DESIGN.md) was owner-merged in PR #72.
[UX4 command menus](docs/UX4_MENUS.md) are pending owner review under #67;
the permanent-panel redesign and final focused tool composition remain gated.

Start with:

- [Quickstart](QUICKSTART.md)
- [Current status](docs/CURRENT_STATUS.md)
- [SimScope handbook](docs/SIMSCOPE_HANDBOOK.md)
- [Python API](SIMSCOPE_API.md)
- [Capture format](G3_FORMAT.md)
- [Simulation integration guide](docs/SIMULATION_INTEGRATION_GUIDE.md)
- [UX implementation plan](UX_IMPLEMENTATION_PLAN.md)

Repository layout:

- `simscope_export/` — installable capture/analysis library
- `viewer/` — Godot viewer and native regression tests
- `examples/` — small repository-owned examples
- `tests/` — Python regression tests
- `tools/` — validation, profiling and conversion tools
- `docs/` — current specifications, guides and accepted milestone reports

Scientific simulations, generated captures, benchmark payloads and research data
are intentionally outside this repository. See
[repository boundaries](docs/REPOSITORY_BOUNDARY.md).

## Licensing

Original SimScope material in this repository is offered under the
[PolyForm Noncommercial License 1.0.0](LICENSE). SimScope is source-available,
not OSI-approved open-source software. Commercial use is not granted by that
license and requires a separate written agreement with the rights holder.

Separately licensed bundled material retains its own terms. See
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). Branding is handled separately
in [TRADEMARKS.md](TRADEMARKS.md).

This repository begins from a fresh audited source snapshot rather than importing
prior development Git history. See [PROVENANCE.md](PROVENANCE.md) for the scope of
that reset.

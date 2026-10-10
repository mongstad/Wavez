# Getting Started — issue #95 review evidence

Candidate **v0.1.0.92**, based on accepted `main`
`3014e8a65e6eadd0ed0a0e509265fb97f8ecf1fb` (owner-merged PR #337).
Issue #95 was the only Ready item when selected. The checked-out branch matched
its GitHub linked branch and accepted main exactly; the tree was clean.
Owner review is pending. Historical evidence for prior issues is unchanged.

## What changed

[Getting Started](../../../GETTING_STARTED.md) separates Linux standalone viewing,
Python capture generation and source development. Its four independent scripts
use NumPy and the exact SceneCapture API, with synthetic units/meaning, explicit
IDs, noncubic xyz/zyx grid geometry and independent combined-scene cadences.
Part III links authoritative contracts and gives a source-reading path and an
AI-assistant prompt. Optional setup automation is a proposal only.

README and Quickstart receive minimal entry links. CURRENT_STATUS links the guide
and records the verified accepted baseline and this pending candidate. The sole
application version setting increments once, per repository policy. There are
no startup, exporter, reader, rendering, packaging, dependency or solver changes.
The new Python/Godot validation scripts are focused review tooling.

## Verified results

Environment: Linux x86_64, Python **3.14.8**, NVIDIA GeForce RTX 3070 Ti;
Godot **4.7.2.stable.official.ed1daf0bf** and its matching release template.

- Fresh `/tmp/wavez-95-venv`: `python -m venv` followed by `python -m pip install .`
  succeeded with isolated build dependencies. It built/installed wavez-export
  4.0.0 and installed NumPy 2.5.4. The wheel was 130,309 bytes, SHA-256
  `5be1567b16177a935cfd5439e03de40448c800011e5322c66a52d4be93cb8501`.
  Python generation additionally ran with the host NumPy 2.4.3 verifier.
- All four documented `python -m examples.getting_started_*` commands ran at
  their default paths. Each script also ran directly from an unrelated working
  directory with the installed package and no PYTHONPATH override.
- **15 records**: particles 3, field 3, mesh 3, combined 6. Whole-file strict
  verification checked descriptors, commits, payload hashes and field statistics.
  Full identity auditing, exact particle/mesh arrays, float64 preservation,
  noncubic grid shape/geometry, an independent known-node probe, object clocks,
  static topology and overwrite refusal passed. Rejected reruns left bytes intact.
- Source Forward+, source Compatibility, release Forward+ and release
  Compatibility each passed **92 native checks**, exited **0**, and produced
  clean runtime logs. Checks cover opening paused at zero, each object's
  committed source clock at 0.25/0.5/1 seconds, three particle instances, mesh
  buffers, xyz grid texture size and visible pixel contributions from every layer.
  All source hashes were unchanged after viewing.
- An additional release Forward+ run passed **92 checks** in a filesystem
  namespace hiding the checkout (including the external Godot engine), the
  Python 3.14 executable and the temporary Python environment. PATH was empty,
  PYTHONPATH empty and the package's staging source had been deleted. No separate
  development engine, installed exporter or Python worker was needed for viewing.
- A separately built, **uninstrumented production package** launched the combined
  capture in that namespace and exited **0** after 120 frames, with a clean log.
  Its application identity and artifact hashes are in
  [production-build.json](isolated/production-build.json).
- Two application-version unit tests passed. Python compilation and diff
  whitespace checks passed. Local documentation paths/anchors and executable
  filenames were checked; the guide teaches only WVZ1.

| Route | Retained report / log | Opening screenshots |
| --- | --- | --- |
| Source Forward+ | [Report](source-forward/validation.json), [log](source-forward/viewer.txt) | [Particles](source-forward/particles-opening.png), [field](source-forward/field-opening.png), [mesh](source-forward/mesh-opening.png), [combined](source-forward/combined-opening.png) |
| Source Compatibility | [Report](source-compat/validation.json), [log](source-compat/viewer.txt) | [Particles](source-compat/particles-opening.png), [field](source-compat/field-opening.png), [mesh](source-compat/mesh-opening.png), [combined](source-compat/combined-opening.png) |
| Release Forward+ | [Report](package-forward/validation.json), [log](package-forward/viewer.txt) | [Particles](package-forward/particles-opening.png), [field](package-forward/field-opening.png), [mesh](package-forward/mesh-opening.png), [combined](package-forward/combined-opening.png) |
| Release Compatibility | [Report](package-compat/validation.json), [log](package-compat/viewer.txt) | [Particles](package-compat/particles-opening.png), [field](package-compat/field-opening.png), [mesh](package-compat/mesh-opening.png), [combined](package-compat/combined-opening.png) |
| Namespace-isolated release | [Report](isolated/viewer-report.json), [log](isolated/viewer.txt), [production log](isolated/production-launch.txt) | Same fixture/settings as release Forward+ |

Each renderer directory also retains final scene and individual-layer pictures.
The pixel test compares each layer to a no-layer image at fixed camera/presentation
state and requires more than five changed samples at a two-pixel stride. It proves
visible contribution, not calibrated physical color. The initial opening uses
the normal shell; subsequent opens retain the Scientific view chosen by the
harness. This is explicitly a presentation test rather than simulated physics.

## Reproduce

Install the package into an environment as described in the guide. From the root:

```sh
python tools/validate_getting_started.py \
  --example-python /absolute/path/to/environment/bin/python \
  --output-dir /tmp/getting-python
python tools/validate_getting_started.py \
  --example-python /absolute/path/to/environment/bin/python \
  --godot /absolute/path/to/Godot --renderer forward_plus \
  --output-dir /tmp/getting-source
python tools/validate_getting_started.py \
  --example-python /absolute/path/to/environment/bin/python \
  --godot /absolute/path/to/Godot --renderer forward_plus --package \
  --output-dir /tmp/getting-release
python -m unittest tests.test_application_version -v
```

Repeat GPU commands with `--renderer gl_compatibility` and fresh output paths.
The release validator deletes its staging project and runs with empty PATH.
The stronger namespace check additionally used externally installed `bwrap`:

```sh
# Substitute your own paths; the hidden checkout contains the external engine here.
bwrap --ro-bind / / --tmpfs /home/Nozba/Codex/Wavez \
  --ro-bind /dev/null /usr/bin/python3.14 --tmpfs /tmp/wavez-95-venv \
  --dev-bind /dev /dev \
  --bind /tmp/wavez-95-isolated-checks /tmp/wavez-95-isolated-checks \
  --chdir /tmp/wavez-95-isolated-checks \
  --setenv PATH /tmp/wavez-95-empty-path --setenv PYTHONPATH '' \
  --setenv XDG_CONFIG_HOME /tmp/wavez-95-isolated-checks/config \
  --setenv XDG_DATA_HOME /tmp/wavez-95-isolated-checks/profile \
  /tmp/wavez-95-isolated-checks/WAVEZ.x86_64 \
  --rendering-method forward_plus --resolution 1200x800 --audio-driver Dummy \
  -- --getting-output=/tmp/wavez-95-isolated-checks
```

For that last command, the writable directory holds only the release validator's
executable/PCK and copies of its four captures; the empty PATH directory exists.
No third-party binaries, environments, captures or PCKs are committed here.

## Failures, limits and validation scope

The initial sandboxed editor import exited 0 but emitted settings/socket errors;
it is not a clean import pass. A native retry with temporary XDG editor settings
exited 0 without errors. Both logged four missing-UID cache warnings for existing,
unrelated resize diagnostic scripts. Generated sidecars for those scripts were
removed; the two new test-script UIDs are retained. The
[initial](installation/initial-import.txt) and [final](installation/final-import.txt)
logs preserve the diagnostics. The earlier preliminary native runs were superseded
by the retained 92-check runs after the harness added explicit committed-layer
clock assertions (the sampling function's return is a navigation bracket).

Python 3.10–3.13, Windows/macOS/other Linux architectures, optional dependency
installation, physical input, low-end graphics, long research captures and a
public distribution/install audit were not tested. The source declares the Python
minimum/extras; the guide distinguishes those declarations from this tested route.
The namespace hides development requirements, but does not remove the host's
desktop/graphics/system libraries or represent a separate clean OS installation.
No production simulation or broad camera/playback/export suite ran: the plausible
change surface is documentation, small example arrays and application identity.
Both renderers/packages are included specifically to verify installation and
example display claims, not unrelated subsystem acceptance.

The known release Popup defect documented in [ROOT_WINDOW_SIGNALS](../../ROOT_WINDOW_SIGNALS.md)
is neither exercised nor fixed by these no-popup routes. Clean logs here do not
invalidate the historical menu/dialog investigation. No passed test constitutes
owner acceptance or authorizes public release.

## Owner verification before acceptance

1. Read all three guide parts and check that the dependency distinctions are clear.
2. In a fresh virtual environment, run the installation commands and all four
   module commands from the checkout root. Confirm the printed paths and refusal
   to overwrite on a second run; use `--output` for a fresh filename.
3. Launch the Linux executable/PCK directly from outside the checkout. Open each
   file with File → Open. Confirm it starts paused at zero and chooses the useful
   Simulation category (Particles, Fields, Meshes, Particles respectively).
4. Press Play: confirm three points move upward, the scalar mound shifts in x,
   the mesh top vertex moves sideways, and the combined triangle stays static.
   Pause at 0.5 seconds in the combined file and confirm the field's source time
   is 0 seconds. Inspect Particles/Fields/Meshes and try Frame Scene.
5. Run `python tools/verify_wvz.py` for each file; inspect the source comments,
   explicit units/IDs and Part III reference/prompt for scientific correctness.
6. Repeat viewer opening with `--rendering-method gl_compatibility`. Review known
   Popup diagnostics separately and confirm Help → About shows candidate
   v0.1.0.92 before accepting. Reconcile BUILD if accepted main changes first.

Stop boundary: one PR from the existing linked branch, targeting main. The owner
controls acceptance/merge, issue closure and Project completion; #94 is separate.

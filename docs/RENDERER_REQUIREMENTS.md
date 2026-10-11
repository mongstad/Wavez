# Forward+ Vulkan requirements and troubleshooting

Issue #371 implements the owner's 2026-10-11 decision: **Forward+ with Vulkan is
Wavez's sole supported rendering backend**. Source viewing, Linux standalone
viewing, image export, ordinary video and explicit Matched Views use this same
backend. Machines without suitable Vulkan support are excluded. OpenGL /
Compatibility, Mobile, Direct3D and Metal are not supported Wavez launch options.
The currently validated standalone platform is Linux x86_64; this policy does
not establish Windows/macOS, mobile or web support.

## Hardware and driver prerequisites

Use a graphical Linux desktop, a Vulkan-capable GPU and working Vulkan drivers
for that GPU. Godot 4.7 documents full Vulkan 1.0 support as the Forward+ baseline
and recommends a dedicated GPU with Vulkan 1.2 support for simple projects:
[engine requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html).
These are engine prerequisites, not a measured minimum or performance promise
for arbitrary Wavez captures. Large volumes, particles, meshes and high-resolution
exports require additional GPU memory, system memory and processing headroom.
Use your GPU vendor/distribution's current driver instructions. Python capture
generation and CPU source inspection do not require Vulkan.

## Launch and failure reporting

Normal source launch uses the checked-in settings:

```sh
godot --path viewer
```

Normal standalone launch keeps the two package files together:

```sh
./WAVEZ.x86_64
```

For an explicit diagnostic launch, both accept
`--rendering-method forward_plus --rendering-driver vulkan`. The project disables
automatic OpenGL and Direct3D fallback. The viewer checks the actual method and
driver before creating its world or opening a capture. An unsupported override
exits with status 1 and a clear requirement message on stderr. Run from a terminal
to retain the message. Session logs record the actual method, driver and GPU.

**Vulkan initialization can fail before any Wavez script runs.** In that case
Godot owns the startup error/dialog and Wavez cannot replace its wording. Godot
may suggest OpenGL; that suggestion does not describe supported Wavez operation.
Keep the complete terminal output, engine version and GPU/driver details. Check
that the desktop session can access the GPU, update/install the appropriate
Vulkan driver and retry Forward+. There is no supported Compatibility fallback.
If `vulkaninfo` is installed externally, its report can help diagnose the driver;
Wavez neither bundles it nor installs drivers.

## Export and validation boundary

Video children explicitly receive one `forward_plus` method and one `vulkan`
driver. Development children receive `--path`; standalone children use their
PCK. Jobs requesting another method are rejected. Worker progress and metrics
record a refusal if scripts can start; pre-script engine failures retain the
existing parent startup-failure diagnostics. A real GPU display connection is
required even for minimized background workers. `--headless` is a dummy renderer
and cannot export or run a supported interactive viewer.

Maintenance validation exposes Forward+ plus explicit headless CPU tests where
appropriate. Headless tests remain allowed only in editor-build `--script`
harnesses and do not certify rendering. Historical Compatibility evidence and
separate investigative tools remain provenance, not supported launch guidance.

## Scientific limits and follow-up coordination

This policy changes the supported backend, not WVZ1 values, numerical probes,
geometry, clocks, color ranges, opacity transfer functions or scientific APIs.
GPU previews still use float32, bounded texture resolution and approximate
sampling/compositing. Forward+ pixels are not calibrated radiance or certified
universally precise. [#360](https://github.com/mongstad/Wavez/issues/360), concerning
Forward+ trilinear precision, remains separate. The historical mesh/particle/
field investigations retain their original measurements and failed tolerances.

[#94](https://github.com/mongstad/Wavez/issues/94) must consume this Vulkan-only
requirement when its public README work becomes Ready. The Compatibility-only
engine color experiment [#362](https://github.com/mongstad/Wavez/issues/362) needs
owner reassessment under this policy; it is not needed for supported Wavez
operation and is not pursued by #371. No engine fork, upstream submission,
distribution, release or repository-settings change is authorized here.

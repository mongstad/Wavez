# Issue #306 — HDR source prototype checkpoint

Recorded 2026-10-09 after owner approval of the isolated-pass prototype and
opt-in mapped-color Fields/Meshes policy, both default 0. This is a new checkpoint;
the initial investigation evidence is preserved as written.

The source gate passes on Forward+ and fails on Compatibility. Production
category Bloom is **not implemented**. See the [current prototype findings and
decision](../../../CATEGORY_BLOOM_PROTOTYPE.md) for the protocol, representative
numbers, interpretation and remaining scope.

| Run | Observation checks | Harness failures | HDR gate failures | Exit |
| --- | ---: | ---: | ---: | ---: |
| [Forward+ source](source-forward_plus.json) | 683 | 0 | 0/110 | 0 |
| [Forward+ release validation package](package-forward_plus.json) | 683 | 0 | 0/110 | 0 |
| [Compatibility source](source-gl_compatibility.json) | 683 | 0 | 90/110 | 1 |
| [Compatibility release validation package](package-gl_compatibility.json) | 683 | 0 | 90/110 | 1 |

Each JSON has its corresponding native `.log`. Package import/export logs are
also retained. [Summary](summary.json) records exact source/package equality,
script SHA-256 and scope. [Corrected attempts](attempts.json), the initial
[sandbox import](attempt-sandbox-import.log) and [clean native import](import-clean.log)
separate setup/harness corrections from the clean measurements. The first
sandbox import's socket errors are environmental; five incidental cached UIDs
were removed after the clean import. Only the prototype's own UID is retained.

![Measured source transfer](hdr-transfer.png)

The four runs contain 2,732 observation checks, no harness failures and 440
measured source samples. **These checks do not make Compatibility pass the HDR
gate**: 90/110 samples fail its source contract in each build. In 36 samples per
Compatibility run at least one positive input channel becomes zero, confirmed
both on the GPU and in float readback. Distinct grayscale 0.0001, 0.001 and 0.01
all become zero. The canvas positive control preserves them. Raising the same
source to 8 produces 9.5390625 with glow disabled, or 11.71875 with glow enabled
at zero intensity. A decoder after this viewport cannot recover collapsed values.

The package is an external **prototype validation executable**, with its main
scene pointing to the prototype instead of the production viewer. It does not
validate category panels, normal application interaction or completed export
integration. Godot templates and binaries remain external; nothing is vendored.
External artifacts are under
`/home/Nozba/Codex/Wavez/bloom-306/hdr-{source,package}-{forward_plus,gl_compatibility}`.

## Reproduce and review

From the substantive repository root, use a fresh output directory for each run:

```sh
python tools/prototype_category_bloom_hdr.py --godot /home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64 --renderer forward_plus --output-dir /tmp/wavez-306-owner-hdr-forward-plus
python tools/prototype_category_bloom_hdr.py --godot /home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64 --renderer gl_compatibility --output-dir /tmp/wavez-306-owner-hdr-compatibility
```

Add `--package` and choose another fresh directory to reproduce the release
validation package. Native display access and externally installed Godot export
templates are required. Forward+ should report gate PASS and exit 0;
Compatibility should report gate FAIL and exit 1. A build/runtime/harness error
is distinct and must not be counted as this expected measured gate result.

1. Inspect low-value `opaque` grayscale samples and the matching `canvas_control`
   and `gpu_positive` fields. Verify that Compatibility's loss occurs before the
   GPU consumer rather than in CPU PNG conversion.
2. Compare source/package `samples` arrays and the five variants. Transparent
   background and emission do not fix the failed source contract.
3. Choose the renderer direction in the current findings document. Existing
   Fields/Meshes policy approval remains valid. The PR is Draft; defer final
   visual acceptance until an actual implementation passes the remaining gates.

Unrun: full isolated graph and mixed-scene visual attribution, scientific output
regressions for a new graph, UI/input/theme matrix, ordinary PNG/MP4 exports,
heavy mixed workloads and extra-pass/cache/GPU-memory/frame-time measurements,
physical 4K/mixed-DPI and other GPU/platform/driver versions. The fixture-free
first gate justifies this focused scope: the production architecture was not
integrated after its prerequisite source contract failed.

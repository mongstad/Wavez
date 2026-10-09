# Issue #306: Forward+-only prototype evidence

Current interpretation and limitations:
[bounded prototype report](../../../CATEGORY_BLOOM_FORWARD_PROTOTYPE.md).
The original issue investigation and HDR-gate evidence are unchanged.

Accepted main: `65fd8fae15a1b8dd37c75eca3a197d75003ee4ee` (build 79).
Candidate: existing #306 branch / Draft PR #309 (build 80).
Environment: Godot `4.7.2.stable.official.ed1daf0bf`, NVIDIA RTX 3070 Ti,
8 GiB VRAM, Vulkan Forward+; Compatibility native comparisons use NVIDIA
OpenGL driver `615.71.09`. Source/project and release runs use isolated profiles.

## Evidence map

- `source.json`, `source-native.log`: 364 completed checks, five mixed scenes,
  particle calibration, real PNG capture and 24 GPU/memory/pacing benchmarks.
- `package.json`, `package-native.log`: 327 standalone release isolation checks;
  mixed-scene float records are identical to source. This validation package
  has an external first-party extraction helper, not a changed production package.
- `transitions.json` / `transition-native.log`: 33 checks, real physical target
  resizing and committed seeks, one-draw versus settled and round-trip hashes.
- `native_transitions.json` / `accepted-transition-native.log`: 23 corresponding
  accepted-main native checks; `native-transition-harness.patch` records the
  temporary harness's omitted graph operations.
- `accepted-*` / `candidate-*`: four native baseline runs, 32 checks each.
  `summary.json` verifies all 24 Cinematic/Scientific screenshot pairs exactly.
- `exports.json`, `exports/`, `temporary-worker.patch`: eleven real MP4 jobs,
  native progress/metrics/timing, 33 staged PNG frames, ffprobe results and frame
  pixel hashes. The prototype worker hooks exist only in an external staging
  directory. Four native accepted/candidate comparisons and the prototype
  Scientific bypass are exact; the prototype Cinematic repeat is deterministic.
- `device-telemetry.json`: timestamped nvidia-smi device and per-process VRAM
  samples; `summary.json` joins them to benchmark intervals. Short intervals
  with no telemetry sample are recorded as null, never estimated as zero.
- Actual full screenshots, two labeled crop contact sheets and `4k-costs.png`.
  Crops are concatenations of native pixels; no appearance is synthesized.
- `sha256.json`: collected artifact hashes. WVZ fixtures, binaries, PCKs,
  profiles/caches and MP4s stay outside Git; their reported payload/frame hashes
  and reproducible generators are retained instead.
- `final-smoke.json` / `final-smoke.log`, `final-import.log`, `verification.json`:
  65 final post-import checks, clean warmed import and two passing version tests.

875 primary Godot observation checks and 65 final smoke checks complete with
zero failures (940 total). Independent sources,
the declared HDR visibility tolerance and controlled particle calibration pass.
**Full Cinematic appearance does not pass**: the background Bloom contribution
is excluded (mean 7.44 / maximum 37 RGB codes). The resource gate is not accepted:
all-enabled 4K adds 14.47 ms GPU median and approximately 2.0 GiB process VRAM;
the provisional allocation model underestimates the measured increment.

## Reproduction

Use an external Godot installation, a native GPU display connection, Python,
NumPy, Pillow, Matplotlib, scikit-image, FFmpeg, ffprobe and nvidia-smi. A dummy
`--headless` renderer cannot establish these rendering/performance results.
Headless editor import/export is used only to build the validation package.
Run from the repository root; outputs must be external to the Git checkout.

```bash
python tools/prototype_category_bloom_forward.py \
  --godot /absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
  --output-dir /absolute/path/bloom-runs/forward-prototype

python tools/prototype_category_bloom_forward.py \
  --godot /absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
  --output-dir /absolute/path/bloom-runs/forward-prototype --transitions

python tools/prototype_category_bloom_forward.py \
  --godot /absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
  --output-dir /absolute/path/bloom-runs/forward-package --package

python tools/prototype_category_bloom_exports.py \
  --godot /absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
  --fixtures /absolute/path/bloom-runs/forward-prototype \
  --accepted-repo /absolute/path/accepted-main-archive \
  --output-dir /absolute/path/bloom-runs/export-prototype-final

python tools/collect_bloom_prototype_evidence.py \
  --runs /absolute/path/bloom-runs \
  --output-dir /absolute/path/review-evidence
```

For the baseline pairs, archive the accepted commit without changing branches,
copy only the two experiment GDScript files into that archive, and complete a
native editor import. Copy the same seven generated WVZ files into each run
directory. Invoke the driver with `--baseline`, `--project` pointing to the
accepted archive or candidate viewer, and `--renderer forward_plus` or
`--renderer gl_compatibility`. Name these output directories `accepted-forward`,
`candidate-forward`, `accepted-compatibility`, `candidate-compatibility` for the
collector. Baseline mode never attaches the graph. The native transition
comparison uses the same transition function in the temporary accepted archive,
with graph creation/synchronization/inventory/zero operations removed.

The native image proof uses `_capture_inspection_png` with sidecars disabled.
The video proof has three frames at 640×360 / 4 fps; it does not cover production
gain persistence, 4K/long/packaged video, v2 selections or cancellation. The
original reported disabled slider is unresolved without its original source.
No owner visual acceptance, production UI/state integration or merge is claimed.

Exploratory harness errors were corrected before the final records: incomplete
fixture regeneration, a Vector2/Vector2i check, missing archive import, a rounded
JSON timestamp comparison, live shader-material duplication and incorrect blend
mode. The superseded desktop-window benchmark was clamped to 3840×1394 and is
not used for 4K claims. Final benchmarks use verified 3840×2160 offscreen targets.
The superseded window-run reports and selected exploratory diagnostics remain
external under the local `bloom-306` runs.

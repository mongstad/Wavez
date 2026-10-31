"""Read-only N192 acceptance evidence, with an independent full-complex oracle.

Each native reconstruction runs in a fresh Python process and verification memo.
Cold means that lifecycle, not a flushed operating-system disk cache. No solver
is run; the explicitly named external capture is never opened for writing.
"""
import argparse
import hashlib
import json
from pathlib import Path
import resource
import subprocess
import sys
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneReader
from wavez_export.analysis import Context, SourceSnapshot

EXPECTED_BYTES = 6965545431
EXPECTED_SHA256 = "1af76f2e5e0642808f33119168d8f5e0c7cc847599e414790923c2c3585e3d7d"
EXPECTED_T40_AMPLITUDE = "721b14353b1329606c1b7e598e7e99a9e544b7ec1b9988807697393a73aa794c"
EDGES = (.125, .375)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for part in iter(lambda: stream.read(4*1024**2), b""): h.update(part)
    return h.hexdigest()


def array_digest(array):
    return hashlib.sha256(memoryview(np.ascontiguousarray(array)).cast("B")).hexdigest()


def process_memory():
    fields = {}
    for line in Path("/proc/self/status").read_text().splitlines():
        if line.startswith(("VmHWM:", "VmRSS:")):
            key, value, _unit = line.split(); fields[key.rstrip(":")+"_bytes"] = int(value)*1024
    fields["ru_maxrss_bytes"] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024
    return fields


def worker(args):
    from wavez_export.analysis.spectral_reconstruction import DenseReconstructionStore, run
    context = Context(memory_bytes=1024**3, wall_seconds=300, cpu_seconds=240)
    initial_memory = process_memory()
    started = time.monotonic()
    store = DenseReconstructionStore(args.output_dir/"worker", registry_root=args.output_dir)
    with SourceSnapshot(args.capture, committed_bytes=str(EXPECTED_BYTES), sha256=EXPECTED_SHA256, context=context) as source:
        indexed = time.monotonic()
        result = run(source, dict(object="field", channel="amplitude", index=args.native, boundary="periodic", edges=list(EDGES)), store)
        reconstructed = time.monotonic()
        source.verify()
        context.commit_publications()
        report = dict(data=result, identity=source.identity(), source_verify_seconds=indexed-started,
            reconstruction_seconds=reconstructed-indexed, total_seconds=time.monotonic()-started,
            context_metrics=context.metrics(), process_peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,
            initial_process_memory=initial_memory, completed_process_memory=process_memory(),
            cold_definition="Fresh process, fresh verification memo and complete committed-prefix SHA-256; operating-system caches were not flushed.")
    report["context_after_source_close"] = context.metrics()
    (args.output_dir/"worker.json").write_text(json.dumps(report, indent=2)+"\n")


def oracle(source, data, worker_root):
    """No production FFT/mask implementation, no reduced half-spectrum weights."""
    q = source
    shape = tuple(q.shape)
    spacing = data["geometry"]["spacing"]
    axes = [np.fft.fftfreq(n, d) for n, d in zip(shape, spacing[::-1])]
    radius = np.sqrt(axes[0][:, None, None]**2 + axes[1][None, :, None]**2 + axes[2][None, None, :]**2)
    transform = np.fft.fftn(q)
    total = np.zeros(shape, np.float64)
    mean = float(q.mean())
    source_ms = float(np.mean(q*q))
    source_ac = float(np.mean((q-mean)**2))
    bands = {}
    failures = []
    for name in ("original", "low", "intermediate", "high"):
        item = data["artifacts"][name]
        scientific = item["scientific"]
        scientific_path = worker_root/scientific["path"]
        display_path = worker_root/item["path"]
        field = np.fromfile(scientific_path, dtype="<f8").reshape(shape)
        display = np.fromfile(display_path, dtype="<f4").reshape(shape)
        if name == "original": expected = q; imaginary = 0.
        else:
            mask = radius < EDGES[0] if name == "low" else ((radius >= EDGES[0]) & (radius < EDGES[1])) if name == "intermediate" else radius >= EDGES[1]
            inverse = np.fft.ifftn(transform*mask)
            expected = inverse.real
            imaginary = float(np.max(np.abs(inverse.imag)))
            total += field
        residual = field-expected
        ms = float(np.mean(field*field)); ac = float(np.mean((field-field.mean())**2))
        row = dict(scientific_sha256=digest(scientific_path), display_sha256=digest(display_path),
            dtype=str(field.dtype), shape=list(field.shape), minimum=float(field.min()), maximum=float(field.max()),
            mean=float(field.mean()), rms=float(np.sqrt(ms)), mean_square=ms,
            total_mean_square_fraction=ms/source_ms, ac_variance_fraction=ac/source_ac,
            independent_oracle_max_abs=float(np.max(np.abs(residual))), independent_oracle_rms=float(np.sqrt(np.mean(residual*residual))),
            oracle_imaginary_max_abs=imaginary, display_cast_max_abs=float(np.max(np.abs(display.astype(np.float64)-field))),
            float32_cast_exact=bool(np.array_equal(display,field.astype(np.float32))))
        if row["scientific_sha256"] != scientific["sha256"] or row["display_sha256"] != item["sha256"]: failures.append(name+": artifact hash")
        if not row["float32_cast_exact"]: failures.append(name+": display differs from single float32 cast")
        if row["independent_oracle_max_abs"] > 2e-12*max(1.,float(np.max(np.abs(q)))): failures.append(name+": independent full-complex oracle mismatch")
        bands[name] = row
        del field, display, expected, residual
    residual = total-q
    summed_ms = sum(bands[name]["mean_square"] for name in ("low", "intermediate", "high"))
    report = dict(source_amplitude_sha256=array_digest(q), source_dtype=str(q.dtype), shape=list(shape),
        source_mean=mean, source_mean_square=source_ms, source_ac_variance=source_ac,
        reconstruction_max_abs=float(np.max(np.abs(residual))), reconstruction_rms=float(np.sqrt(np.mean(residual*residual))),
        parseval_relative_residual=abs(summed_ms-source_ms)/source_ms, bands=bands,
        oracle="Separate full complex fftn/ifftn, full frequency lattice and direct real-space mean squares; no production reconstruction functions or rFFT multiplicity.", failures=failures)
    if report["reconstruction_max_abs"] > 2e-12*max(1.,float(np.max(np.abs(q)))): failures.append("sum of bands differs from source")
    if report["parseval_relative_residual"] > 2e-12: failures.append("disjoint-band mean-square Parseval residual")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--native", type=int, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.native is not None: worker(args); return 0
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    before = args.capture.stat()
    if before.st_size != EXPECTED_BYTES: raise ValueError("Explicit reference capture size differs from audited N192 source")
    reports = []
    # Execute all numerical workers before the parent allocates any FFT oracle
    # arrays. Linux ru_maxrss may retain the parent's high-water mark across
    # fork/exec, so record /proc VmHWM/VmRSS independently as well.
    for index in (0,20,40):
        directory = out/("native-"+str(index)); directory.mkdir()
        command = [sys.executable, __file__, "--capture",str(args.capture.resolve()),"--output-dir",str(directory),"--native",str(index)]
        with (directory/"worker.log").open("w") as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=360, check=True)
    with SceneReader(args.capture, strict=True, cache_bytes=0) as reader:
        for index in (0,20,40):
            directory = out/("native-"+str(index))
            report = json.loads((directory/"worker.json").read_text())
            start = time.monotonic(); arrays = reader.read_sample("field",index); q = arrays["amplitude"]; del arrays
            native_geometry = dict(reader.samples["field"][index]["descriptor"]["geometry"], data_to_world=reader.objects["field"]["data_to_world"])
            report["independent"] = oracle(q, report["data"], directory/"worker")
            report["independent"]["scene_reader_decode_oracle_seconds"] = time.monotonic()-start
            report["independent"]["native_geometry_matches"] = native_geometry == report["data"]["geometry"]
            if not report["independent"]["native_geometry_matches"]: report["independent"]["failures"].append("native geometry changed")
            if index == 40:
                if report["independent"]["source_amplitude_sha256"] != EXPECTED_T40_AMPLITUDE: report["independent"]["failures"].append("audited t40 amplitude hash changed")
                fraction=report["independent"]["bands"]["intermediate"]["ac_variance_fraction"]
                if abs(fraction-.19975641570951452)>2e-12: report["independent"]["failures"].append("t40 intermediate AC variance not reproduced")
            (directory/"report.json").write_text(json.dumps(report,indent=2)+"\n"); reports.append(report)
            print(json.dumps(dict(native=index,seconds=report["total_seconds"],independent=report["independent"])),flush=True)
            del q
    after = args.capture.stat(); final_hash = digest(args.capture)
    unchanged = (before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_size,after.st_mtime_ns,after.st_ctime_ns) and final_hash==EXPECTED_SHA256
    failures = [failure for report in reports for failure in report["independent"]["failures"]]
    if not unchanged: failures.append("external source identity changed")
    summary = dict(source=str(args.capture.resolve()), bytes=before.st_size, final_sha256=final_hash, source_unchanged=unchanged,
        native_reports=reports, failures=failures, validation_exit_code=int(bool(failures)),
        limits="Three recorded Model A native samples and deterministic full-grid known values. No optical-energy interpretation, universal performance claim, or proof about filament connectivity.")
    (out/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
    return summary["validation_exit_code"]


if __name__ == "__main__": raise SystemExit(main())

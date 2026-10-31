#!/usr/bin/env python3
"""Bounded read-only audit of existing Model A captures; never runs the solver.

Run from any directory with the Wavez checkout's NumPy/SciPy interpreter.
Payload verification is deliberately sampled; metadata scans cover each record.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import sys
import time
import tomllib

import numpy as np
from scipy import fft
import scipy

REPO = Path(__file__).resolve().parents[3]
RUN_IDS = (
    "20261030T193414164759Z_b3a4a787cae945b0909004cac75740ca",
    "20261030T205345553035Z_678c9919a7b949bb91fb364e0c22c83c",
    "20261030T232217150259Z_4662e0aede704d96b2dd4edfaa85a2d4",
    "20261031T083021711514Z_f253e398edcf46669fa53f8fe0e4dbe1",
)
sys.path.insert(0, str(REPO))
from wavez_export import SceneReader


def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def stamp(path):
    s = path.stat()
    return dict(bytes=s.st_size, mtime_ns=s.st_mtime_ns, ctime_ns=s.st_ctime_ns,
                device=s.st_dev, inode=s.st_ino)


def digest_json(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def array_summary(a):
    return dict(shape=list(a.shape), dtype=str(a.dtype), bytes=a.nbytes,
                sha256=hashlib.sha256(memoryview(a).cast("B")).hexdigest(),
                finite=int(np.isfinite(a).sum()), negative=int((a < 0).sum()),
                minimum=float(a.min()), maximum=float(a.max()), mean=float(a.mean()),
                rms=float(np.sqrt(np.mean(a*a))))


def checkpoint_comparison(run, index, record, arrays, cfg):
    step = round(record["time"] / cfg["dt"])
    checkpoint = run / f"state_{step:09d}.npz"
    if not checkpoint.exists():
        return None
    before = stamp(checkpoint)
    with np.load(checkpoint, allow_pickle=False) as state:
        q, p = state["q"][0], state["p"][0]
        t, length = float(state["t"]), float(state["L"])
    assert t == record["time"] and length == cfg["L"]
    signed = arrays["amplitude"]
    assert np.array_equal(signed, q.transpose(2, 1, 0))
    # Numerical equality alone treats +0 and -0 as equal. Verify canonical
    # float64 bits after the documented axis transpose before claiming bitwise.
    assert signed.astype("<f8", copy=False).tobytes(order="C") == q.transpose(2, 1, 0).astype("<f8", copy=False).tobytes(order="C")
    # Independent transcription of the frozen exported local-energy expression.
    # Source arrays use xyz, whereas WVZ uses zyx. Zero even-grid derivative
    # Nyquist multipliers exactly as the source's real trigonometric derivative.
    n = q.shape[0]
    qh = fft.rfftn(q, workers=1)
    ks = [2*np.pi*fft.fftfreq(n, length/n),
          2*np.pi*fft.fftfreq(n, length/n),
          2*np.pi*fft.rfftfreq(n, length/n)]
    squared = np.zeros_like(q)
    for axis, k in enumerate(ks):
        if n % 2 == 0:
            k[n//2] = 0
        shape = [1, 1, 1]
        shape[axis] = len(k)
        g = fft.irfftn(1j*k.reshape(shape)*qh, s=q.shape, workers=1)
        squared += g*g
    r2 = q*q
    energy = .5*r2 - .25*r2*r2 + .05*r2*r2*r2 + .5*p*p + .5*squared
    grad = np.sqrt(squared)
    errors = {"amplitude": float(np.max(np.abs(signed-q.transpose(2, 1, 0)))),
              "energy_density": float(np.max(np.abs(arrays["energy_density"]-energy.transpose(2, 1, 0)))),
              "gradient_magnitude": float(np.max(np.abs(arrays["gradient_magnitude"]-grad.transpose(2, 1, 0))))}
    assert max(errors.values()) < 1e-12, errors
    assert stamp(checkpoint) == before
    return dict(path=str(checkpoint), sha256=sha_file(checkpoint), time=t,
                source_axes="xyz", capture_axes="zyx", q_bitwise_equal=True,
                max_abs_errors=errors, unchanged_stat=True)


def audit_run(run):
    summary = json.loads((run / "summary.json").read_text())
    provenance = json.loads((run / "provenance.json").read_text())
    config = json.loads((run / "configuration.json").read_text())
    capture, = run.glob("*.wvz")
    before = stamp(capture)
    reader = SceneReader(capture, strict=True, cache_bytes=0)
    rows = reader.samples["field"]
    channels = sorted({a["name"] for r in rows for a in r["descriptor"]["arrays"]})
    n = config["N"]
    assert summary["status"] == "complete" and summary["final_t"] == config["T"]
    assert rows[0]["time"] == 0.0 and rows[-1]["time"] == config["T"]
    assert np.allclose(np.diff([r["time"] for r in rows]), config["volume_interval"], rtol=0, atol=1e-12)
    report = dict(run_id=run.name.removeprefix("run_"), path=str(capture),
                  stat=before, metadata=reader.metadata, configuration=config,
                  summary_status=summary["status"], final_t=summary["final_t"],
                  summary_export_validation=summary["export_validation"],
                  records=len(reader.records), field_samples=len(rows),
                  sample_first=rows[0]["time"], sample_last=rows[-1]["time"],
                  time_delta_min=float(np.min(np.diff([r["time"] for r in rows]))),
                  time_delta_max=float(np.max(np.diff([r["time"] for r in rows]))),
                  channels=channels, geometry=rows[0]["descriptor"]["geometry"],
                  field_decoded_bytes=rows[0]["decoded"],
                  all_field_schemas_equal=all([(a["name"], a["shape"], a["dtype"]) for a in r["descriptor"]["arrays"]] == [(a["name"], a["shape"], a["dtype"]) for a in rows[0]["descriptor"]["arrays"]] and r["descriptor"]["geometry"] == rows[0]["descriptor"]["geometry"] for r in rows),
                  all_records_structural_checks_pass=True,
                  committed_end=reader.committed_end, eof_fully_committed=reader.committed_end == before["bytes"],
                  index_sha256=digest_json(dict(metadata=reader.metadata, records=reader.records)),
                  provenance_sha256=sha_file(run/"provenance.json"),
                  summary_sha256=sha_file(run/"summary.json"),
                  configuration_sha256=sha_file(run/"configuration.json"),
                  diagnostics_sha256=sha_file(run/"diagnostics.jsonl"),
                  provenance_boundary=provenance["boundary"], units=provenance["units"],
                  swss=provenance["swss"], simulation_version=provenance["version"],
                  source_hashes={}, exporter_hashes={}, sampled_payloads=[])
    assert report["all_field_schemas_equal"]
    for name, expected in provenance["source_sha256"].items():
        actual = sha_file(run/"source"/name)
        report["source_hashes"][name] = dict(sha256=actual, matches_provenance=actual == expected)
        assert actual == expected
    swss = tomllib.loads((run/"source"/"swss.toml").read_text())["swss"]
    report["swss_schema"] = swss["schema_version"]
    report["swss_declared_sources_match"] = all(sha_file(run/"source"/entry["path"]) == entry["sha256"] for entry in swss["source_files"])
    assert report["swss_declared_sources_match"]
    for name, expected in provenance["exporter"]["listed_source_sha256"].items():
        actual = sha_file(REPO/"wavez_export"/name)
        report["exporter_hashes"][name] = dict(current_sha256=actual, matches_recorded_exporter=actual == expected)
        assert actual == expected
    # All channels at three representative N192 times; energy-only endpoints
    # at N320. N256 originals receive structural/provenance checks only.
    indices = [0, len(rows)//2, len(rows)-1] if n == 192 else ([0, len(rows)-1] if n == 320 else [])
    for i in indices:
        start = time.perf_counter()
        arrays = reader.read_sample("field", i)
        assert all(np.isfinite(a).all() for a in arrays.values())
        entry = dict(index=i, time=rows[i]["time"], sequence=rows[i]["sequence"],
                     read_seconds=time.perf_counter()-start,
                     stored_and_raw_chunk_checksums_verified=True,
                     arrays={k:array_summary(v) for k,v in arrays.items()})
        if n == 192:
            entry["checkpoint_comparison"] = checkpoint_comparison(run, i, rows[i], arrays, config)
        report["sampled_payloads"].append(entry)
        del arrays
    report["marker_samples"] = len(reader.samples.get("derived_markers", []))
    report["marker_payloads_verified"] = 0
    if report["marker_samples"]:
        report["marker_count_range"] = [min(r["descriptor"]["arrays"][0]["shape"][0] for r in reader.samples["derived_markers"]), max(r["descriptor"]["arrays"][0]["shape"][0] for r in reader.samples["derived_markers"])]
    reader.close()
    report["capture_unchanged_stat"] = stamp(capture) == before
    assert report["capture_unchanged_stat"] and report["eof_fully_committed"]
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=Path, required=True, help="Existing Model-A outputs parent")
    parser.add_argument("--partial-copy", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Refuse writing research evidence into the external input tree.
    output = args.output.resolve()
    if output.is_relative_to(args.runs.resolve()) or (args.partial_copy and output == args.partial_copy.resolve()):
        raise ValueError("Output must be outside the read-only research inputs")
    report = dict(scope="Issue 135 bounded read-only metadata, sampled payload and checkpoint audit",
                  python=platform.python_version(), numpy=np.__version__, scipy=scipy.__version__,
                  full_capture_hashes="NOT COMPUTED: originals total over 300 GB; selected payload checksums and complete structural indexes retained",
                  finalization_boundary="WVZ1 commits samples, not a final-run marker; completion requires matching external run summary and configured final sample",
                  runs=[audit_run(args.runs / ("run_" + run_id)) for run_id in RUN_IDS])
    if args.partial_copy:
        before = stamp(args.partial_copy)
        reader = SceneReader(args.partial_copy, strict=True, cache_bytes=0)
        matches = [r for r in report["runs"] if r["metadata"]["uuid"] == reader.metadata["uuid"]]
        assert len(matches) == 1
        original = SceneReader(matches[0]["path"], strict=True, cache_bytes=0)
        report["partial_copy"] = dict(path=str(args.partial_copy), stat=before,
            uuid=reader.metadata["uuid"], records=len(reader.records), last_time=reader.times[-1],
            strict_structural_scan_pass=True, committed_end=reader.committed_end,
            matches_original_metadata_and_prefix_descriptors=reader.metadata == original.metadata and reader.records == original.records[:len(reader.records)],
            full_original_last_time=matches[0]["sample_last"],
            payload_prefix_byte_equality="NOT VERIFIED", payload_checksums_verified=0,
            suitable_for_final_run_claim=False)
        reader.close(); original.close()
        report["partial_copy"]["unchanged_stat"] = stamp(args.partial_copy) == before
        assert report["partial_copy"]["unchanged_stat"]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, allow_nan=False)+"\n")
    print(json.dumps({"output":str(output), "runs":len(report["runs"]),
                      "sampled_field_payloads":sum(len(r["sampled_payloads"]) for r in report["runs"]),
                      "result":"PASS"}))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Small read-only Model A sequence, owned-worker reuse and restart evidence.

Only the audited signed N192 reference is admitted. No solver or source copy is
run; result caches live in the chosen disposable output directory. This measures
CPU/worker paths, not graphical throughput or hardware-independent performance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import numpy as np

from tests.test_spatial_spectrum import WorkerSession
from tests.test_spatial_band_map import map_request
from tools.validate_spatial_band_map import (
    REFERENCE_BYTES, REFERENCE_SHA256, REFERENCE_UUID, stamp,
)


def run_job(worker, job):
    began = time.monotonic()
    worker.write("background_request.json", job)
    reply = worker.wait("background_result.json",
                        lambda row: row.get("id") == job["id"], timeout=150)
    elapsed = time.monotonic()-began
    if not reply.get("ok"):
        raise AssertionError(reply)
    # Worker metrics are sampled before staged publication commits: a cold
    # sequence still charges its writer then. The reply itself must follow the
    # completed transaction, with no pending result left in the owned store.
    cache = worker.directory.parent/"spectral-cache"/"results"
    if cache.exists() and any(path.name.startswith(".pending-") for path in cache.iterdir()):
        raise AssertionError("Worker replied before its sequence transaction completed")
    return dict(roundtrip_seconds=elapsed, reply=reply)


def sequence_job(capture, source, identifier):
    job = map_request(capture, [128]*3, source=source, native_cursor=20,
        fixed_start=32, start=(0, 0), hop=(32, 32), count=(3, 3),
        band=(.05, .15), request_id=identifier)
    job["operation"] = "spectral_band_sequence"
    job["arguments"].pop("time")
    job["arguments"]["indices"] = [20, 21, 22]
    return job


def validate(capture, out):
    capture = capture.resolve()
    before = stamp(capture)
    if before[2] != REFERENCE_BYTES:
        raise ValueError("Only the audited finalized signed N192 reference is admitted")
    source = dict(path=str(capture), format="WVZ1", uuid=REFERENCE_UUID,
                  committed_bytes=str(REFERENCE_BYTES), sha256=REFERENCE_SHA256,
                  complete_records=82)
    registry = out/"workers"
    observations = {}
    comparisons = []
    with WorkerSession(registry/"first") as worker:
        for label in ("first", "prepared"):
            observations[label] = run_job(worker, sequence_job(capture, source, label))
        first = observations["first"]["reply"]
        if first["data"]["cache"]["hit"]:
            raise AssertionError("Disposable first cache unexpectedly hit")
        maps = first["data"]["maps"]
        if len(maps) != 3:
            raise AssertionError("Expected exactly three selected native maps")
        for index, data in zip((20, 21, 22), maps):
            direct_job = map_request(capture, [128]*3, source=source, native_cursor=index,
                fixed_start=32, start=(0, 0), hop=(32, 32), count=(3, 3),
                band=(.05, .15), request_id=f"direct-{index}")
            direct = run_job(worker, direct_job)["reply"]
            if direct["source"] != source or first["source"] != source:
                raise AssertionError("Verified reference identity differs")
            for key in ("measurements", "coverage", "record", "geometry", "grid",
                        "support", "band", "units", "request_key"):
                if data[key] != direct["data"][key]:
                    raise AssertionError(f"Native {index}: cached/direct {key} differs")
            if data["coverage"]["measured"] != 9 or data["support"]["status"] != "insufficient_support":
                raise AssertionError("Expected nine complete, unresolved low-frequency windows")
            comparisons.append(dict(index=index, measured=9, exact_direct_parity=True,
                powers=[row["power"] for row in data["measurements"]],
                power_exact=[row["power_exact"] for row in data["measurements"]],
                request_key=data["request_key"], direct_timings=direct["data"]["timings"]))
        observations["first_worker_progress"] = worker.progress
    with WorkerSession(registry/"reopened") as worker:
        observations["reopened"] = run_job(worker, sequence_job(capture, source, "reopened"))
        observations["reopened_worker_progress"] = worker.progress
    for label in ("prepared", "reopened"):
        reply = observations[label]["reply"]
        if not reply["data"]["cache"]["hit"]:
            raise AssertionError(f"{label}: expected a verified exact-selection cache hit")
        if reply["metrics"]["decoded_bytes"] != 0:
            raise AssertionError(f"{label}: cache reuse decoded source channels")
        if reply["metrics"]["charged_bytes"] != 0:
            raise AssertionError(f"{label}: cache reuse retained logical allocations")
        for expected, actual in zip(maps, reply["data"]["maps"]):
            for key in ("measurements", "coverage", "record", "geometry", "grid",
                        "support", "band", "units", "request_key"):
                if actual[key] != expected[key]:
                    raise AssertionError(f"{label}: immutable {key} differs")
    if comparisons[0]["powers"] == comparisons[1]["powers"] or comparisons[1]["powers"] == comparisons[2]["powers"]:
        raise AssertionError("Expected time-dependent native Model A band changes")
    if stamp(capture) != before:
        raise AssertionError("Reference source stat changed during read-only validation")
    artifacts = []
    cache = registry/"spectral-cache"/"results"
    for path in sorted(cache.rglob("*")):
        if path.is_file():
            artifacts.append(dict(path=str(path.relative_to(cache)), bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    return dict(status="PASS", source=source, source_stat_unchanged=True,
        parameters=sequence_job(capture, source, "parameters")["arguments"],
        observations=observations, comparisons=comparisons,
        storage=dict(files=artifacts, logical_bytes=sum(row["bytes"] for row in artifacts)),
        limitations=["First/reopened worker has a cold verification memo; OS disk cache is uncontrolled.",
            "Worker logical/RSS metrics are sampled before staged publication commits; cold charged_bytes includes the still-open writer lease, which finish releases before replying.",
            "Direct parity uses the accepted shared numerical kernel; independent synthetic oracles are separate.",
            "No viewer, GPU, FPS, all-capture preprocessing or solver validation in this CPU probe.",
            "The low band remains unresolved and source coordinate/channel units remain undeclared."])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    if out.is_relative_to(args.capture.resolve().parent):
        parser.error("Output must remain outside the scientific source run")
    out.mkdir(parents=True, exist_ok=False)
    try:
        report = validate(args.capture, out)
    except Exception as exc:
        (out/"failure.json").write_text(json.dumps(dict(status="FAIL", error=repr(exc)), indent=2)+"\n")
        raise
    report.update(python=sys.version, numpy=np.__version__,
        validator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (out/"report.json").write_text(json.dumps(report, indent=2, allow_nan=False)+"\n")
    print(json.dumps(dict(status=report["status"], times=3, center_comparisons=27,
                         storage_bytes=report["storage"]["logical_bytes"], output=str(out))))


if __name__ == "__main__":
    main()

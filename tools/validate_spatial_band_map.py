#!/usr/bin/env python3
"""Focused numerical/owned-worker evidence for issue #415.

Synthetic tests use disposable source files. Optional --capture admits only the
audited signed N192 Model A reference, reads a pinned native time, and compares
nine 128-cube map centers with individual #413 exact-band analyses. No solver,
scientific capture copy, GPU or native viewer validation is performed here.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.test_spatial_band_map import SpatialBandMapTests, WORKER_OBSERVATIONS, map_request
from tests.test_spatial_spectrum import WorkerSession, request

REFERENCE_SHA256 = "1af76f2e5e0642808f33119168d8f5e0c7cc847599e414790923c2c3585e3d7d"
REFERENCE_UUID = "5848557b4ddd4d56b48e62f9f5700b23"
REFERENCE_BYTES = 6_965_545_431


def stamp(path):
    info = path.stat()
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def numerical_tests():
    WORKER_OBSERVATIONS.clear()
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(SpatialBandMapTests)
    began = time.monotonic()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    return dict(passed=result.wasSuccessful(), tests_run=result.testsRun,
                failures=len(result.failures), errors=len(result.errors), skipped=len(result.skipped),
                seconds=time.monotonic()-began, output=stream.getvalue(),
                worker_observations=list(WORKER_OBSERVATIONS))


def actual_reference(capture, work):
    capture = capture.resolve()
    before = stamp(capture)
    if before[2] != REFERENCE_BYTES:
        raise ValueError("Only the audited finalized signed N192 reference is admitted")
    source = dict(path=str(capture), format="WVZ1", uuid=REFERENCE_UUID,
                  committed_bytes=str(REFERENCE_BYTES), sha256=REFERENCE_SHA256, complete_records=82)
    units = dict(position_units="dimensionless", value_units="dimensionless")
    band = dict(low=.05, high=.15)
    batches, comparisons = [], []
    with WorkerSession(work / "model-worker") as worker:
        for side in (1, 2, 3):
            identifier = f"model-map-{side}"
            job = map_request(capture, [128]*3, source=source, native_cursor=20,
                fixed_start=32, start=(0, 0), hop=(32, 32), count=(side, side),
                band=(band["low"], band["high"]), arguments=units, request_id=identifier)
            began = time.monotonic()
            worker.write("background_request.json", job)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == identifier, timeout=90)
            roundtrip = time.monotonic()-began
            if not reply.get("ok"):
                raise AssertionError(reply)
            data = reply["data"]
            if reply["source"] != source:
                raise AssertionError("Map source identity changed")
            if data["coverage"]["measured"] != side*side or not all(data["coverage"]["mask"]):
                raise AssertionError("Expected complete finite 128-cube centers")
            if data["support"]["status"] != "insufficient_support":
                raise AssertionError("A 128-cube must not claim two cycles for low edge .05")
            if data["timings"]["decoded_samples"] != 1:
                raise AssertionError("Batch did not retain the single-decode contract")
            if reply["metrics"]["charged_bytes"] != 0:
                raise AssertionError("Batch retained request allocations")
            timings = data["timings"]
            batches.append(dict(center_count=side*side, support=data["support"], band=data["band"],
                record=data["record"], units=data["units"], geometry=data["geometry"], grid=data["grid"],
                measurements=data["measurements"], coverage=data["coverage"], warnings=data["warnings"],
                provenance=data["provenance"], timings=timings,
                seconds_per_center=timings["batch_seconds"]/(side*side),
                transport_roundtrip_seconds=roundtrip, reply_bytes=len(json.dumps(reply).encode()),
                workspace_bytes=data["workspace_bytes"], logical=reply["metrics"], worker_memory=reply["memory"],
                verification_memo=reply["verification_memo"], source=reply["source"]))
        mapped = data
        for index, center in enumerate(mapped["measurements"]):
            identifier = f"individual-{index}"
            individual = request(capture, [192]*3, source=source, native_cursor=20,
                start=center["start"], end=center["end"], request_id=identifier,
                arguments=dict(units, band=band))
            worker.write("background_request.json", individual)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == identifier, timeout=30)
            if not reply.get("ok"):
                raise AssertionError(reply)
            reference = reply["data"]
            for field in ("record", "units", "geometry"):
                if reference[field] != mapped[field]:
                    raise AssertionError(f"Individual/map {field} differs")
            if reply["source"] != source:
                raise AssertionError("Individual source identity changed")
            for edge in ("low", "high"):
                if reference["band"][edge] != mapped["band"][edge] or mapped["band"][edge] != band[edge]:
                    raise AssertionError("Exact requested band edge changed")
            if reference["provenance"]["normalization"] != mapped["provenance"]["normalization"]:
                raise AssertionError("Band power normalizations differ")
            np.testing.assert_allclose(center["power"], reference["band"]["power"], rtol=1e-13, atol=1e-15)
            np.testing.assert_allclose(center["total_power"], reference["total_power"], rtol=1e-13, atol=1e-15)
            np.testing.assert_allclose(center["mean"], reference["mean"], rtol=1e-13, atol=1e-15)
            expected_center = (np.array(center["start"])[::-1]+63.5)*np.array(mapped["geometry"]["spacing"])+np.array(mapped["geometry"]["origin"])
            np.testing.assert_allclose(center["center_xyz"], expected_center, rtol=1e-14, atol=1e-14)
            relative = abs(center["power"]-reference["band"]["power"])/max(abs(reference["band"]["power"]), np.finfo(float).tiny)
            comparisons.append(dict(row=center["row"], column=center["column"], start=center["start"],
                end=center["end"], center_xyz=center["center_xyz"], map_power=center["power"],
                individual_power=reference["band"]["power"], relative_error=relative,
                parseval_relative_error=center["parseval_relative_error"]))
        progress = worker.progress
    if stamp(capture) != before:
        raise AssertionError("Read-only reference source stat changed during validation")
    return dict(passed=True, capture=str(capture), source=source, source_stat_unchanged=True,
        batches=batches, comparisons=comparisons, progress=progress,
        scope="Unmodified owned Python worker, native t20, 128-cube support, 1/4/9 centers, exact band [.05,.15); no GUI/GPU/solver",
        independence="Synthetic tests use independent full complex direct DFT. Model A comparison checks map against individual #413 operation; their production FFT kernel is shared.",
        cache_note="First request verifies the full committed prefix. OS disk cache is uncontrolled; subsequent requests use the identity-checked worker memo.",
        timing_note="Roundtrip includes source/compute, IPC and polling; it is not pure IPC or native plot latency. Calculation timing includes window, FFT and normalization; reduction is reported separately.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--skip-synthetic", action="store_true", help="Only use after the focused unittest command already passed")
    args = parser.parse_args()
    if args.skip_synthetic and args.capture is None:
        parser.error("--skip-synthetic requires --capture; validation must perform checks")
    if args.capture and args.output.resolve().is_relative_to(args.capture.resolve().parent):
        raise ValueError("Validation output must remain outside the read-only reference run")
    report = dict(scope="issue415 focused band-power/source/batch/owned-worker validation", python=sys.version, numpy=np.__version__,
        validator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        tests_sha256=hashlib.sha256((ROOT / "tests/test_spatial_band_map.py").read_bytes()).hexdigest())
    if not args.skip_synthetic:
        report["synthetic"] = numerical_tests()
        if not report["synthetic"]["passed"]:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2, allow_nan=False)+"\n")
            print(report["synthetic"]["output"])
            return 1
    if args.capture:
        with tempfile.TemporaryDirectory(prefix="wavez-band-map-worker-") as temporary:
            report["model_a"] = actual_reference(args.capture, Path(temporary))
    report["status"] = "PASS"
    report["limitations"] = ["No native UI, viewport FPS, GPU memory or packaged measurement",
        "No solver, all-frame map, scientific source copy or alternate Model A capture",
        "CPU FFT cancellation occurs at bounded checkpoints; an individual NumPy FFT call is not interruptible"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False)+"\n")
    print(json.dumps(dict(status=report["status"], tests=report.get("synthetic", {}).get("tests_run"),
        model_comparisons=len(report.get("model_a", {}).get("comparisons", [])), output=str(args.output))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

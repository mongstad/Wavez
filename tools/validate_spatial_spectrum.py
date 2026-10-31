#!/usr/bin/env python3
"""Focused Python/owned-worker validation for issue #413.

Synthetic checks use disposable captures. --capture optionally reads only the
accepted #135 Model A reference and compares central ROIs at t=0,20,40 with its
retained oracle. No solver is run and no source capture/array is copied out.
Native UI/render validation belongs to validate_spatial_spectrum_ui.py.
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
from tests.test_spatial_spectrum import SpatialSpectrumTests, WorkerSession, request, WORKER_OBSERVATIONS

REFERENCE_SHA256 = "1af76f2e5e0642808f33119168d8f5e0c7cc847599e414790923c2c3585e3d7d"
REFERENCE_UUID = "5848557b4ddd4d56b48e62f9f5700b23"
REFERENCE_BYTES = 6_965_545_431


def stamp(path):
    info = path.stat()
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def numerical_tests():
    WORKER_OBSERVATIONS.clear()
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(SpatialSpectrumTests)
    began = time.monotonic()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    return dict(passed=result.wasSuccessful(), tests_run=result.testsRun,
                failures=len(result.failures), errors=len(result.errors),
                skipped=len(result.skipped), seconds=time.monotonic() - began,
                output=stream.getvalue(), worker_observations=list(WORKER_OBSERVATIONS))


def actual_reference(capture, work):
    capture = capture.resolve()
    before = stamp(capture)
    if before[2] != REFERENCE_BYTES:
        raise ValueError("Only the audited finalized N192 reference is admitted; no substitute capture")
    oracle_path = ROOT / "docs/research/spectral-135/evidence/experiment.json"
    oracle = json.loads(oracle_path.read_text())["model_a"]
    source = dict(path=str(capture), format="WVZ1", uuid=REFERENCE_UUID,
                  committed_bytes=str(REFERENCE_BYTES), sha256=REFERENCE_SHA256,
                  complete_records=82)
    comparisons = []
    with WorkerSession(work / "model-worker") as worker:
        for native_time in (0, 20, 40):
            known_sample = next(row for row in oracle["samples"] if row["time"] == native_time)
            for size in (32, 64, 128):
                identifier = f"model-{native_time}-{size}"
                args = dict(bins=256, position_units="dimensionless", value_units="dimensionless",
                            minimum_frequency=.1)
                job = request(capture, [192, 192, 192], source=source, native_cursor=native_time,
                              start=[96 - size // 2] * 3, end=[96 + size // 2] * 3,
                              request_id=identifier, arguments=args)
                began = time.monotonic()
                worker.write("background_request.json", job)
                reply = worker.wait("background_result.json", lambda row: row.get("id") == identifier, timeout=90)
                roundtrip = time.monotonic() - began
                if not reply.get("ok"):
                    raise AssertionError(reply)
                if reply["source"] != source:
                    raise AssertionError("source identity changed")
                expected = next(row for row in known_sample["channels"]["amplitude"]["local"]
                                if row["size"] == size and row["center_zyx"] == [96, 96, 96])
                data = reply["data"]
                if data["support"]["status"] != ("candidate" if size == 128 else "insufficient_support"):
                    raise AssertionError("window support no longer matches the declared frequency-of-interest criterion")
                np.testing.assert_allclose(data["mean"], expected["mean"], rtol=1e-12, atol=1e-14)
                np.testing.assert_allclose(data["total_power"], expected["power"], rtol=1e-12, atol=1e-14)
                np.testing.assert_allclose(data["radial"]["frequency"], expected["radial"]["frequency"], rtol=1e-13, atol=1e-14)
                np.testing.assert_allclose(data["radial"]["power"], expected["radial"]["power"], rtol=2e-11, atol=1e-14)
                if reply["metrics"]["charged_bytes"] != 0:
                    raise AssertionError("operation retained a request allocation")
                relative = abs(data["total_power"] - expected["power"]) / max(abs(expected["power"]), np.finfo(float).tiny)
                comparisons.append(dict(time=native_time, size=size,
                    mean=data["mean"], power=data["total_power"], oracle_power=expected["power"],
                    power_relative_error=relative, parseval_relative_error=data["parseval_relative_error"],
                    support=data["support"], warnings=data["warnings"], timings=data.get("timings", {}),
                    workspace_bytes=data["workspace_bytes"], transport_roundtrip_seconds=roundtrip,
                    logical=reply["metrics"], worker_memory=reply["memory"],
                    verification_memo=reply["verification_memo"], source=reply["source"]))
        # The lower k≈.5 feature remains under two cycles even in a 128-cube.
        low = request(capture, [192] * 3, source=source, native_cursor=0,
                      start=[32] * 3, end=[160] * 3, request_id="model-low-support",
                      arguments=dict(minimum_frequency=.5 / (2 * np.pi),
                                     position_units="dimensionless", value_units="dimensionless"))
        worker.write("background_request.json", low)
        low_reply = worker.wait("background_result.json", lambda row: row.get("id") == "model-low-support", timeout=90)
        if not low_reply.get("ok"):
            raise AssertionError(low_reply)
        if low_reply["data"]["support"]["status"] != "insufficient_support":
            raise AssertionError("128-cube falsely claims two cycles for angular k=.5")
        progress = worker.progress
    if stamp(capture) != before:
        raise AssertionError("reference source stat changed during validation")
    return dict(passed=True, capture=str(capture), source_sha256=REFERENCE_SHA256,
                source_stat_unchanged=True, comparisons=comparisons,
                low_k128_support=low_reply["data"]["support"],
                progress=progress,
                oracle=str(oracle_path.relative_to(ROOT)),
                oracle_sha256=hashlib.sha256(oracle_path.read_bytes()).hexdigest(),
                scope="Unmodified owned Python worker; nine central regions at native times0,20,40 and one low-k support check; no GUI/GPU/solver",
                cache_note="First source verification scans the prefix; OS disk cache uncontrolled. Later requests can use the verified memo.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--skip-synthetic", action="store_true",
                        help="Only use after the focused unittest command already passed")
    args = parser.parse_args()
    if args.skip_synthetic and args.capture is None:
        parser.error("--skip-synthetic requires --capture; a validation run must perform checks")
    if args.capture and args.output.resolve().is_relative_to(args.capture.resolve().parent):
        raise ValueError("validation output must be outside the read-only reference run")
    report = dict(scope="issue413 focused numerical/source/owned-worker validation",
                  python=sys.version, numpy=np.__version__,
                  validator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  tests_sha256=hashlib.sha256((ROOT / "tests/test_spatial_spectrum.py").read_bytes()).hexdigest())
    if not args.skip_synthetic:
        report["synthetic"] = numerical_tests()
        if not report["synthetic"]["passed"]:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
            print(report["synthetic"]["output"])
            return 1
    if args.capture:
        with tempfile.TemporaryDirectory(prefix="wavez-spectrum-worker-") as temporary:
            report["model_a"] = actual_reference(args.capture, Path(temporary))
    report["status"] = "PASS"
    report["limitations"] = ["No native UI/plot-display measurement", "No GPU or packaged measurement",
                             "No solver, all-frame analysis or alternate Model A capture"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(dict(status=report["status"], tests=report.get("synthetic", {}).get("tests_run"),
                          model_comparisons=len(report.get("model_a", {}).get("comparisons", [])), output=str(args.output))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

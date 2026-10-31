"""Independent numerical and owned-worker checks for regional spatial spectra.

All captures are disposable synthetic fixtures. The explicit exponential-sum
oracle deliberately does not call an FFT or the production spectrum helpers.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import numpy as np

from wavez_export import SceneCapture
from wavez_export.analysis import AnalysisError, Cancelled, Context, SourceSnapshot
from wavez_export.analysis.contracts import MIB, float_token, parse_float_token
from wavez_export.analysis.jobs import execute

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]
WORKER_OBSERVATIONS = []


def wave(shape, bins_zyx, amplitude=1., phase=0.):
    axes = np.ogrid[tuple(slice(n) for n in shape)]
    phase_grid = sum(axis * k / n for axis, k, n in zip(axes, bins_zyx, shape))
    return amplitude * np.cos(2 * np.pi * phase_grid + phase)


def field_capture(path, arrays, *, times=None, spacing=(1., 1., 1.),
                  centering="node", transform=None, position_units="m",
                  value_units="u", channel="amplitude", metadata=None):
    if isinstance(arrays, np.ndarray):
        arrays = [arrays]
    times = list(range(len(arrays))) if times is None else times
    declarations = dict(position_unit=position_units, time_unit="s",
                        channel_metadata={"field": {channel: {"units": value_units, "semantic": "signed"}}})
    declarations.update(metadata or {})
    with SceneCapture(path, objects=[dict(id="field", kind="volume", units=value_units,
                                         data_to_world=transform or IDENTITY)], metadata=declarations) as writer:
        for native_time, array in zip(times, arrays):
            writer.add_volume("field", native_time, {channel: array},
                              origin=[1.25, -2., 3.], spacing=list(spacing), centering=centering)
    return Path(path)


def request(path, shape, *, source=None, native_cursor=0., start=(0, 0, 0),
            end=None, request_id="spectrum", arguments=None, budget=None,
            revisions=(3, 5, 7)):
    args = dict(object="field", channel="amplitude", time=float_token(native_cursor),
                roi=dict(start=list(start), end=list(shape if end is None else end)))
    args.update(arguments or {})
    value = dict(version=1, id=request_id, scene_revision=revisions[0],
                 selection_revision=revisions[1], analysis_revision=revisions[2],
                 source=source or {"path": str(Path(path).absolute())},
                 operation="spatial_spectrum", arguments=args)
    if budget is not None:
        value["budget"] = budget
    return value


def independent_spectrum(array, spacing_xyz=(1., 1., 1.)):
    """Full direct DFT, including both signs; no real-FFT folding in this oracle."""
    array = np.asarray(array, dtype=np.float64)
    weights = np.ones(array.shape)
    for axis, n in enumerate(array.shape):
        factors = (1 - np.cos(2 * np.pi * np.arange(n) / n)) / 2
        shape = [1, 1, 1]
        shape[axis] = n
        weights *= factors.reshape(shape)
    mean = float(np.sum(weights * array) / np.sum(weights))
    residual = weights * (array - mean)
    matrices = [np.exp(-2j * np.pi * np.outer(np.arange(n), np.arange(n)) / n)
                for n in array.shape]
    coefficients = np.einsum("az,by,cx,zyx->abc", *matrices, residual, optimize=True)
    power = np.abs(coefficients) ** 2 / (array.size * np.sum(weights ** 2))
    frequencies = []
    for n, spacing in zip(array.shape, spacing_xyz[::-1]):
        indices = np.arange(n)
        signed = np.where(indices < (n + 1) // 2, indices, indices - n)
        frequencies.append(signed / (n * spacing))
    return dict(mean=mean, power=power, frequencies=frequencies,
                expected=float(np.sum(residual ** 2) / np.sum(weights ** 2)))


def independent_radial(oracle, width, count):
    """Sum full-DFT cells with scalar loops, independent of vectorized reduction."""
    result = np.zeros(count)
    axes = oracle["frequencies"]
    for index in np.ndindex(oracle["power"].shape):
        radius = math.sqrt(sum(float(axes[i][index[i]]) ** 2 for i in range(3)))
        slot = math.floor(radius / width + .5)
        if slot >= count:
            raise AssertionError(f"radial bin {slot} exceeds published length {count}")
        result[slot] += oracle["power"][index]
    return result


class WorkerSession:
    """Launch the unmodified production worker with a disposable owned directory."""
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True)
        self.process = None
        self.progress = []

    def write(self, name, value):
        path = self.directory / name
        temporary = path.with_suffix(path.suffix + ".test-tmp")
        temporary.write_text(json.dumps(value, allow_nan=False))
        os.replace(temporary, path)

    def start(self):
        self.write("lease.json", {"owner": os.getpid()})
        self.process = subprocess.Popen(
            [sys.executable, "-B", str(ROOT / "tools/analyze_selection.py"),
             "--directory", str(self.directory), "--owner-pid", str(os.getpid())],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return self.wait("ready.json", lambda result: result.get("pid") == self.process.pid)

    def wait(self, name, predicate=lambda result: True, timeout=10):
        deadline = time.monotonic() + timeout
        previous_progress = None
        while time.monotonic() < deadline:
            self.write("lease.json", {"owner": os.getpid()})
            try:
                progress = json.loads((self.directory / "background_progress.json").read_text())
                if progress != previous_progress:
                    self.progress.append(progress)
                    previous_progress = progress
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            try:
                result = json.loads((self.directory / name).read_text())
                if predicate(result):
                    return result
            except (FileNotFoundError, json.JSONDecodeError):
                pass
            if self.process.poll() is not None:
                stdout, stderr = self.process.communicate()
                raise AssertionError(f"worker exited {self.process.returncode}: {stdout}\n{stderr}")
            time.sleep(.005)
        raise AssertionError(f"timeout waiting for {name}; progress={self.progress[-3:]}")

    def close(self):
        if self.process is None:
            return
        self.write("close", {})
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)
        self.process.stdout.close()
        self.process.stderr.close()

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, *args):
        self.close()


class SpatialSpectrumTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.serial = 0

    def tearDown(self):
        self.temporary.cleanup()

    def capture(self, array, **kwargs):
        self.serial += 1
        return field_capture(self.root / f"field-{self.serial}.wvz", array, **kwargs)

    def evaluate(self, array, *, spacing=(1., 1., 1.), arguments=None, **kwargs):
        path = self.capture(array, spacing=spacing, **kwargs)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        result = execute(request(path, array.shape, arguments=arguments))
        self.assertTrue(result["ok"])
        self.assertEqual(result["metrics"]["charged_bytes"], 0)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
        return result

    def assert_oracle(self, array, *, spacing=(1., 1., 1.), bins=256):
        result = self.evaluate(array, spacing=spacing, arguments={"bins": bins})["data"]
        oracle = independent_spectrum(array, spacing)
        self.assertAlmostEqual(result["mean"], oracle["mean"], places=12)
        self.assertAlmostEqual(result["total_power"], oracle["expected"], places=12)
        self.assertLess(result["parseval_relative_error"], 1e-12)
        radial = result["radial"]
        expected = independent_radial(oracle, radial["bin_width"], len(radial["power"]))
        np.testing.assert_allclose(radial["power"], expected, rtol=2e-12, atol=2e-14)
        self.assertLessEqual(len(radial["power"]), bins)
        self.assertAlmostEqual(sum(radial["power"]), result["total_power"], places=12)
        return result

    def test_full_direct_dft_oracle_odd_even_and_anisotropic_axes(self):
        for shape in [(5, 6, 7), (6, 7, 8), (8, 9, 10)]:
            with self.subTest(shape=shape):
                array = wave(shape, (2, -2, 3), amplitude=1.7, phase=.37) + .3
                data = self.assert_oracle(array, spacing=(.25, .5, 1.5))
                np.testing.assert_allclose(data["df_xyz"], [1 / (shape[2] * .25), 1 / (shape[1] * .5), 1 / (shape[0] * 1.5)])
                np.testing.assert_allclose(data["nyquist_xyz"], [2, 1, 1 / 3])

    def test_single_mixed_modes_and_phase_interference_have_known_power(self):
        shape = (8, 8, 32)
        first = wave(shape, (0, 0, 4), amplitude=2)
        second = wave(shape, (0, 0, 10))
        quadrature = wave(shape, (0, 0, 4), amplitude=2, phase=np.pi / 2)
        opposite = wave(shape, (0, 0, 4), amplitude=2, phase=np.pi)
        for label, array, expected in [
            ("single", first + 3, 2), ("mixed", first + second, 2.5),
            ("constructive", 2 * first, 8), ("quadrature", first + quadrature, 4),
            ("destructive", first + opposite, 0), ("constant", np.full(shape, 4.), 0),
        ]:
            with self.subTest(case=label):
                data = self.evaluate(array)["data"]
                self.assertAlmostEqual(data["total_power"], expected, places=12)
                if label == "single":
                    self.assertAlmostEqual(data["mean"], 3, places=12)

    def test_coarsened_radial_bins_preserve_full_power(self):
        data = self.assert_oracle(wave((8, 9, 10), (2, 3, 4)), spacing=(.02, .7, 2.), bins=8)
        self.assertLessEqual(len(data["radial"]["frequency"]), 8)
        self.assertEqual(data["radial"]["convention"], "nearest-shell-sum")

    def test_complete_edge_roi_uses_only_selected_samples_and_never_wraps(self):
        array = np.zeros((12, 14, 16))
        expected = wave((6, 8, 10), (1, 2, 3), amplitude=1.2)
        array[6:12, 6:14, 6:16] = expected
        path = self.capture(array)
        result = execute(request(path, array.shape, start=(6, 6, 6), end=(12, 14, 16)))["data"]
        self.assertAlmostEqual(result["total_power"], independent_spectrum(expected)["expected"], places=12)
        for roi in [dict(start=[-1, 0, 0], end=[6, 8, 10]),
                    dict(start=[6, 6, 6], end=[13, 14, 16]),
                    dict(start=[0, 0, 0], end=[3, 8, 10]),
                    dict(start=[0, 0, 0], end=[6.5, 8, 10]),
                    dict(start=[0, 0, 0], end=[0, 8, 10])]:
            with self.subTest(roi=roi), self.assertRaises(AnalysisError):
                execute(request(path, array.shape, arguments={"roi": roi}))

    def test_nonfinite_roi_refused_without_zero_fill_and_outside_roi_ignored(self):
        array = wave((12, 12, 12), (2, 2, 2))
        array[0, 0, 0] = np.nan
        path = self.capture(array)
        with self.assertRaises(AnalysisError):
            execute(request(path, array.shape))
        result = execute(request(path, array.shape, start=(4, 4, 4), end=(12, 12, 12)))
        self.assertTrue(result["ok"])
        for bad in [np.inf, -np.inf]:
            array[5, 5, 5] = bad
            with self.assertRaises(AnalysisError):
                self.evaluate(array)

    def test_held_native_time_and_exact_tokens_do_not_follow_cursor(self):
        exact_time = .10000000000000003
        array = wave((8, 8, 8), (2, 2, 2))
        path = self.capture([array, 2 * array, 3 * array], times=[.1, exact_time, 2.75])
        reply = execute(request(path, array.shape, native_cursor=1.25))
        data = reply["data"]
        self.assertEqual(data["record"]["index"], 1)
        self.assertEqual(parse_float_token(data["record"]["native_time"]), exact_time)
        self.assertEqual(data["record"]["native_time"], float_token(exact_time))
        self.assertEqual(data["record"]["requested_time"], float_token(1.25))
        self.assertEqual(data["record"]["sampling"], "held")
        self.assertEqual(reply["source"]["committed_bytes"], str(path.stat().st_size))
        self.assertEqual(reply["source"]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertAlmostEqual(data["total_power"], independent_spectrum(2 * array)["expected"], places=12)
        with self.assertRaises(AnalysisError):
            execute(request(path, array.shape, native_cursor=.09))

    def test_missing_amplitude_never_substitutes_energy_density(self):
        array = np.ones((8, 8, 8))
        path = self.capture(array, channel="energy_density")
        with self.assertRaises(AnalysisError):
            execute(request(path, array.shape))
        reply = execute(request(path, array.shape, arguments={"channel": "energy_density"}))
        self.assertEqual(reply["data"]["channel"], "energy_density")

    def test_transform_and_unit_policies_are_explicit(self):
        array = wave((8, 8, 8), (2, 2, 2))
        translation = IDENTITY.copy()
        translation[3], translation[7], translation[11] = 4., -3., 2.
        translated = self.evaluate(array, transform=translation, centering="cell")
        self.assertTrue(translated["ok"])
        self.assertEqual(translated["data"]["roi"]["origin_xyz"], [1.25, -2., 3.])
        self.assertEqual(translated["data"]["geometry"]["centering"], "cell")
        for transform in [[2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0],
                          [0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
                          [1, .2, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]]:
            with self.subTest(transform=transform), self.assertRaises(AnalysisError):
                self.evaluate(array, transform=transform)
        unknown = self.evaluate(array, position_units="unknown", value_units="unknown")["data"]
        self.assertTrue(unknown["warnings"])
        path = self.capture(array)
        for key in ["position_units", "value_units"]:
            for bad in ["", 3, "x" * 129]:
                with self.subTest(key=key, bad=bad), self.assertRaises(AnalysisError):
                    execute(request(path, array.shape, arguments={key: bad}))

    def test_invalid_source_geometry_units_semantics_and_request_fields(self):
        from tests.scene_mutation import rewrite
        array = wave((8, 8, 8), (2, 2, 2))
        path = self.capture(array)
        rewrite(path, lambda sequence, record, descriptor, payload:
                descriptor["geometry"].update(spacing=[0., 1., 1.]))
        with self.assertRaises((ValueError, AnalysisError)):
            execute(request(path, array.shape))
        for metadata in [dict(position_unit=["m"]),
                         dict(channel_metadata={"field": {"amplitude": {"units": []}}}),
                         dict(channel_metadata={"field": {"amplitude": {"semantic": "phase"}}})]:
            path = self.capture(array, metadata=metadata)
            with self.subTest(metadata=metadata), self.assertRaises(AnalysisError):
                execute(request(path, array.shape))
        path = self.capture(array)
        for arguments in [dict(extra=True), dict(bins=7), dict(bins=513),
                          dict(minimum_frequency=0), dict(minimum_frequency=-1),
                          dict(time=float_token(float("1.0000000000000002")) | {"text": "1"})]:
            with self.subTest(arguments=arguments), self.assertRaises(AnalysisError):
                execute(request(path, array.shape, arguments=arguments))
        oversized_axis = np.ones((4, 4, 257), dtype="f4")
        path = self.capture(oversized_axis)
        with self.assertRaises(AnalysisError):
            execute(request(path, oversized_axis.shape))

    def test_support_sizes_change_resolution_without_inventing_wavelength(self):
        array = wave((128, 128, 128), (1, 1, 1)).astype("f4")
        path = self.capture(array, spacing=[1 / 6] * 3, position_units="dimensionless")
        for size in [32, 64, 128]:
            with self.subTest(size=size):
                data = execute(request(path, array.shape, start=[64 - size // 2] * 3,
                                       end=[64 + size // 2] * 3,
                                       arguments={"minimum_frequency": .1}))["data"]
                self.assertEqual(data["support"]["status"], "candidate" if size == 128 else "insufficient_support")
                np.testing.assert_allclose(data["support"]["cycles_xyz"], [.1 * size / 6] * 3)
                np.testing.assert_allclose(data["df_xyz"], [6 / size] * 3)
                self.assertNotIn("dominant_wavelength", data)
                self.assertEqual(data["provenance"]["source_dtype"], "f4")
        low = execute(request(path, array.shape, arguments={"minimum_frequency": .5 / (2 * np.pi)}))["data"]
        self.assertEqual(low["support"]["status"], "insufficient_support")
        self.assertIn("not a resolution guarantee", low["support"]["criterion"])

    def test_out_of_band_target_and_numerical_range_fail_explicitly(self):
        array = wave((8, 8, 8), (2, 2, 2))
        path = self.capture(array, spacing=(1., 2., 4.))
        for frequency in [.125, 1.]:
            with self.subTest(frequency=frequency), self.assertRaises(AnalysisError) as caught:
                execute(request(path, array.shape, arguments={"minimum_frequency": frequency}))
            self.assertEqual(caught.exception.code, "unsupported_frequency")
        for values, spacing in [(array * 1e200, (1., 1., 1.)),
                                (array, (1e-320, 1., 1.)),
                                (array, (1e308, 1., 1.))]:
            path = self.capture(values, spacing=spacing)
            context = Context()
            with self.subTest(spacing=spacing), self.assertRaises(AnalysisError) as caught:
                execute(request(path, array.shape), context=context)
            self.assertEqual(caught.exception.code, "numerical_range")
            self.assertEqual(context.used, 0)

    def test_source_mutation_truncation_and_payload_corruption_are_refused(self):
        for mode in ["mutation", "truncation", "replacement"]:
            array = wave((8, 8, 8), (2, 2, 2))
            path = self.capture(array)
            with SourceSnapshot(path) as source:
                identity = source.identity()
                offset = source.samples["field"][0]["offset"]
            raw = path.read_bytes()
            if mode == "truncation":
                path.write_bytes(raw[:-1])
            elif mode == "replacement":
                altered = bytearray(raw)
                altered[offset] ^= 1
                replacement = self.root / "replacement"
                replacement.write_bytes(altered)
                os.replace(replacement, path)
            else:
                with path.open("r+b") as output:
                    output.seek(offset)
                    output.write(bytes([raw[offset] ^ 1]))
            with self.subTest(mode=mode), self.assertRaises((AnalysisError, ValueError)):
                execute(request(path, array.shape, source=identity))
        # An initially unpinned file still must verify the selected payload hashes.
        with self.assertRaisesRegex((AnalysisError, ValueError), "checksum"):
            execute(request(path, array.shape))

    def test_low_memory_refusal_precedes_fft_and_releases_leases(self):
        array = wave((16, 16, 16), (2, 2, 2))
        path = self.capture(array)
        context = Context(memory_bytes=12 * MIB)
        with mock.patch("numpy.fft.rfftn", side_effect=AssertionError("FFT must not run")):
            with self.assertRaises(AnalysisError) as caught:
                execute(request(path, array.shape), context=context)
        self.assertEqual(caught.exception.code, "memory_limit")
        self.assertEqual(context.used, 0)

    def test_direct_cancellation_unwinds_and_does_not_modify_source(self):
        array = wave((16, 16, 16), (2, 2, 2))
        path = self.capture(array)
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        for target in ["decode", "window", "fft", "reduce"]:
            active = {"cancel": False}
            def progress(stage, completed, total):
                if target in stage:
                    active["cancel"] = True
            context = Context(cancelled=lambda: active["cancel"], progress=progress)
            with self.subTest(stage=target), self.assertRaises(Cancelled):
                execute(request(path, array.shape), context=context)
            self.assertEqual(context.used, 0)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)

    def test_source_change_after_decode_prevents_publication(self):
        array = wave((16, 16, 16), (2, 2, 2))
        path = self.capture(array)
        with SourceSnapshot(path) as source:
            identity = source.identity()
            offset = source.samples["field"][0]["offset"]
        changed = []
        def progress(stage, completed, total):
            if stage == "spectrum_fft" and completed == 1 and not changed:
                with path.open("r+b") as output:
                    output.seek(offset)
                    original = output.read(1)
                    output.seek(offset)
                    output.write(bytes([original[0] ^ 1]))
                changed.append(True)
        context = Context(progress=progress)
        with self.assertRaises(AnalysisError) as caught:
            execute(request(path, array.shape, source=identity), context=context)
        self.assertTrue(changed)
        self.assertEqual(caught.exception.code, "source_changed")
        self.assertEqual(context.used, 0)

    def test_real_worker_revision_roundtrip_cancel_supersession_and_reuse(self):
        array = wave((16, 16, 16), (2, 2, 3), amplitude=1.5)
        path = self.capture(array)
        with WorkerSession(self.root / "worker") as worker:
            initial = request(path, array.shape, request_id="initial")
            worker.write("background_request.json", initial)
            reply = worker.wait("background_result.json", lambda result: result.get("id") == "initial")
            self.assertTrue(reply["ok"], reply)
            self.assertEqual([reply[k] for k in ["scene_revision", "selection_revision", "analysis_revision"]], [3, 5, 7])
            self.assertLess(len(json.dumps(reply).encode()), MIB)
            self.assertEqual(reply["metrics"]["charged_bytes"], 0)
            self.assertLessEqual(reply["shared_memory"]["peak"], 512 * MIB)
            worker.write("playback_pressure.json", {"underflow": True})
            time.sleep(.12)  # Respect the existing worker's progress/checkpoint throttles.
            held = request(path, array.shape, source=reply["source"], request_id="held")
            worker.write("background_request.json", held)
            worker.wait("background_progress.json", lambda r: r.get("id") == "held" and r.get("stage") == "paused_for_playback_underflow")
            began = time.monotonic()
            worker.write("background_cancel.json", {"id": "held"})
            cancelled = worker.wait("background_result.json", lambda r: r.get("id") == "held")
            self.assertFalse(cancelled["ok"])
            self.assertEqual(cancelled["code"], "cancelled")
            cancellation_seconds = time.monotonic() - began
            self.assertLess(cancellation_seconds, 2)
            self.assertEqual(cancelled["metrics"]["charged_bytes"], 0)
            time.sleep(.12)
            worker.write("background_request.json", request(path, array.shape, request_id="old"))
            worker.wait("background_progress.json", lambda r: r.get("id") == "old" and r.get("stage") == "paused_for_playback_underflow")
            worker.write("background_request.json", request(path, array.shape, request_id="new", revisions=(8, 9, 10)))
            worker.write("playback_pressure.json", {"underflow": False})
            current = worker.wait("background_result.json", lambda r: r.get("id") == "new")
            self.assertTrue(current["ok"], current)
            self.assertEqual([current[k] for k in ["scene_revision", "selection_revision", "analysis_revision"]], [8, 9, 10])
            self.assertEqual(current["metrics"]["charged_bytes"], 0)
            WORKER_OBSERVATIONS.append(dict(
                scope="unmodified worker cancellation while paused for playback pressure; not cancellation inside FFT",
                cancellation_seconds=cancellation_seconds,
                reply_bytes=len(json.dumps(reply).encode()),
                worker_memory=reply["memory"], logical=reply["metrics"],
                request_revisions=[8, 9, 10], stale_id_cannot_impersonate_new_reply=True))

    def test_owned_worker_close_while_paused_exits_without_complete_result(self):
        array = wave((16, 16, 16), (2, 2, 2))
        path = self.capture(array)
        with WorkerSession(self.root / "closing-worker") as worker:
            worker.write("playback_pressure.json", {"underflow": True})
            worker.write("background_request.json", request(path, array.shape, request_id="closing"))
            worker.wait("background_progress.json", lambda r: r.get("stage") == "paused_for_playback_underflow")
            began = time.monotonic()
            worker.write("close", {})
            worker.process.wait(timeout=2)
            self.assertEqual(worker.process.returncode, 0)
            self.assertFalse((worker.directory / "background_result.json").exists())
            WORKER_OBSERVATIONS.append(dict(scope="owned worker close during playback-pressure pause",
                                            close_seconds=time.monotonic() - began,
                                            complete_result_published=False))


if __name__ == "__main__":
    unittest.main()

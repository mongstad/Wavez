"""Independent source-grid band-power and real owned-worker checks for #415.

The numerical oracle is a full complex exponential-sum DFT. It does not call
production spectrum helpers or NumPy's FFT implementation. All fixture captures
are disposable; optional scientific capture checks belong to the validator.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest import mock

import numpy as np

from tests.test_spatial_spectrum import (
    IDENTITY, WorkerSession, field_capture, independent_spectrum, request, wave,
)
from wavez_export import SceneCapture
from wavez_export.analysis import AnalysisError, Cancelled, Context, SourceSnapshot
from wavez_export.analysis.contracts import MIB, float_token
from wavez_export.analysis.jobs import execute
from wavez_export.analysis.memo import VerificationMemo

ROOT = Path(__file__).resolve().parents[1]
WORKER_OBSERVATIONS = []


def independent_band(array, low, high, spacing_xyz=(1., 1., 1.)):
    """Sum signed full-DFT cells inside the exact half-open radial interval."""
    oracle = independent_spectrum(array, spacing_xyz)
    power = 0.
    cells = 0
    for index in np.ndindex(oracle["power"].shape):
        radius = math.hypot(*(float(oracle["frequencies"][axis][index[axis]])
                              for axis in range(3)))
        if low <= radius < high:
            power += float(oracle["power"][index])
            cells += 1
    return dict(mean=oracle["mean"], total_power=oracle["expected"],
                band_power=power, full_dft_cells=cells)


def regional_field(size=8):
    """Four disjoint complete x windows with amplitude ratios 1:2:3:4."""
    unit = wave((size, size, size), (0, 0, 2))
    return np.concatenate([amplitude * unit for amplitude in (1., 2., 3., 4.)], axis=2)


def map_request(path, support, *, band=(.1, .4), plane_axis="z", fixed_start=0,
                start=(0, 0), hop=(1, 1), count=(1, 1), arguments=None, **kwargs):
    result = request(path, support, **kwargs)
    result["operation"] = "spectral_band_map"
    result["arguments"].pop("roi")
    result["arguments"].update(support=list(support), band=dict(low=band[0], high=band[1]),
        grid=dict(plane_axis=plane_axis, fixed_start=fixed_start,
                  start=list(start), hop=list(hop), count=list(count)))
    result["arguments"].update(arguments or {})
    return result


class SpatialBandMapTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.serial = 0

    def tearDown(self):
        self.temporary.cleanup()

    def capture(self, array, **kwargs):
        self.serial += 1
        return field_capture(self.root / f"band-field-{self.serial}.wvz", array, **kwargs)

    def assert_oracle(self, array, *, spacing=(1., 1., 1.), band=(.1, .4), **kwargs):
        path = self.capture(array, spacing=spacing)
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        reply = execute(map_request(path, array.shape, band=band, **kwargs))
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["metrics"]["charged_bytes"], 0)
        row = reply["data"]["measurements"][0]
        oracle = independent_band(array, *band, spacing)
        self.assertEqual(row["status"], "measured")
        for actual, expected in [(row["power"], oracle["band_power"]),
                                 (row["mean"], oracle["mean"]),
                                 (row["total_power"], oracle["total_power"])]:
            self.assertAlmostEqual(actual, expected, places=12)
        self.assertLess(row["parseval_relative_error"], 1e-12)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)
        return reply

    def test_full_complex_dft_oracle_single_mixed_oblique_and_parity(self):
        for shape in [(5, 6, 7), (6, 7, 8), (8, 9, 10)]:
            for label, array in [
                ("single", wave(shape, (0, 0, 2), amplitude=2) + .37),
                ("mixed", wave(shape, (1, 1, 1)) + .4 * wave(shape, (2, -2, 3))),
                ("oblique", wave(shape, (1, -2, 2), phase=.71)),
            ]:
                with self.subTest(shape=shape, case=label):
                    self.assert_oracle(array, spacing=(.25, .5, 1.5), band=(.12, .32))

    def test_exact_half_open_edges_use_fft_cells_not_radial_bin_centers(self):
        array = wave((8, 8, 8), (0, 0, 2), amplitude=2)
        below, above = float(np.nextafter(.25, 0.)), float(np.nextafter(.25, 1.))
        at = self.assert_oracle(array, band=(.25, above))["data"]["measurements"][0]["power"]
        excluded = self.assert_oracle(array, band=(below, .25))["data"]["measurements"][0]["power"]
        self.assertGreater(at, .1)
        self.assertLess(excluded, 1e-25)
        wider = self.assert_oracle(array, band=(.2, .3))["data"]["measurements"][0]["power"]
        self.assertGreater(wider, at)  # Hann's perpendicular leakage also enters this band.
        self.assertLess(wider, 2.)  # This selected band does not contain all residual power.
        self.assert_oracle(array, band=(.25, .5))  # Upper Nyquist edge is allowed and remains exclusive.

    def test_regionally_varying_amplitude_preserves_squared_power_and_order(self):
        array = regional_field()
        path = self.capture(array)
        data = execute(map_request(path, [8]*3, band=(.2, .3), hop=(8, 8), count=(1, 4)))["data"]
        rows = data["measurements"]
        self.assertEqual([(r["row"], r["column"]) for r in rows], [(0, i) for i in range(4)])
        reference = independent_band(array[:, :, :8], .2, .3)["band_power"]
        np.testing.assert_allclose([r["power"] for r in rows], reference*np.array([1, 4, 9, 16]), rtol=1e-12)
        self.assertEqual(data["coverage"], dict(total=4, measured=4, unavailable=0, mask=[True]*4))

    def test_complete_edge_mask_has_no_zero_fill_wrapping_or_invented_measurement(self):
        array = np.concatenate([wave((8, 8, 8), (0, 0, 2)), 3*wave((8, 8, 8), (0, 0, 2))], axis=2)
        path = self.capture(array)
        data = execute(map_request(path, [8]*3, start=(0, -8), hop=(8, 8), count=(1, 4)))["data"]
        rows = data["measurements"]
        self.assertEqual([r["status"] for r in rows], ["outside_support", "measured", "measured", "outside_support"])
        self.assertEqual([r["power"] for r in (rows[0], rows[3])], [None, None])
        np.testing.assert_allclose([rows[1]["power"], rows[2]["power"]],
                                  [independent_band(array[:, :, :8], .1, .4)["band_power"],
                                   independent_band(array[:, :, 8:], .1, .4)["band_power"]], rtol=1e-12)
        empty = execute(map_request(path, [8]*3, fixed_start=-1))["data"]
        self.assertEqual(empty["coverage"]["measured"], 0)
        self.assertIsNone(empty["measurements"][0]["power"])

    def test_nonfinite_and_numerical_range_mask_only_affected_centers(self):
        array = regional_field()
        array[3, 3, 3] = np.nan
        array[:, :, 16:24] *= 1e200
        path = self.capture(array)
        data = execute(map_request(path, [8]*3, hop=(8, 8), count=(1, 4)))["data"]
        rows = data["measurements"]
        self.assertEqual([r["status"] for r in rows], ["nonfinite_samples", "measured", "numerical_range", "measured"])
        self.assertIsNone(rows[0]["power"])
        self.assertIsNone(rows[2]["power"])
        self.assertEqual(data["coverage"]["measured"], 2)

    def test_anisotropic_plane_axes_and_cell_centers_use_data_local_coordinates(self):
        shape, support, spacing = (12, 14, 16), [4, 6, 8], (.25, .5, 1.5)
        array = wave(shape, (2, 3, 4))
        translation = IDENTITY.copy()
        translation[3], translation[7], translation[11] = 9., 8., 7.
        path = self.capture(array, spacing=spacing, centering="cell", transform=translation)
        data = execute(map_request(path, support, band=(.1, .3), plane_axis="x", fixed_start=2,
                                   start=(1, 3), hop=(2, 3), count=(2, 2)))["data"]
        for row in data["measurements"]:
            start = np.array([1+2*row["row"], 3+3*row["column"], 2])
            center = (start + (np.array(support)-1)/2)[::-1]
            self.assertEqual(row["start"], start.tolist())
            np.testing.assert_allclose(row["center_index_xyz"], center)
            np.testing.assert_allclose(row["center_xyz"], [1.25, -2., 3.] + center*np.array(spacing))
            np.testing.assert_allclose(row["center_world_xyz"], [10.25, 6., 10.] + center*np.array(spacing))
            local = array[tuple(slice(a, a+n) for a, n in zip(start, support))]
            self.assertAlmostEqual(row["power"], independent_band(local, .1, .3, spacing)["band_power"], places=12)
        self.assertEqual(data["geometry"]["data_to_world"], translation)

    def test_batch_decodes_once_hashes_once_and_workspace_does_not_scale_with_centers(self):
        array = wave((16, 16, 16), (2, 3, 4))
        path = self.capture(array)
        memo = VerificationMemo()
        digest, read = SourceSnapshot._digest, SourceSnapshot.read_sample
        with mock.patch.object(SourceSnapshot, "_digest", autospec=True, side_effect=digest) as hashed, \
             mock.patch.object(SourceSnapshot, "read_sample", autospec=True, side_effect=read) as decoded:
            one = execute(map_request(path, [8]*3), memo=memo)
            self.assertEqual(hashed.call_count, 1)
            self.assertEqual(decoded.call_count, 1)
            many = execute(map_request(path, [8]*3, count=(8, 8)), memo=memo)
            self.assertEqual(hashed.call_count, 1)  # One cold prefix scan, then identity-checked memo.
            self.assertEqual(decoded.call_count, 2)  # One whole selected-channel decode per batch.
        self.assertEqual(many["data"]["coverage"]["measured"], 64)
        self.assertEqual(one["data"]["workspace_bytes"], many["data"]["workspace_bytes"])
        self.assertLess(abs(one["metrics"]["peak_charged_bytes"]-many["metrics"]["peak_charged_bytes"]), 128*1024)
        self.assertEqual(many["metrics"]["charged_bytes"], 0)

    def test_native_held_time_exact_tokens_and_source_pin_are_preserved(self):
        array = wave((8, 8, 8), (2, 2, 2))
        exact_time = .10000000000000003
        path = self.capture([array, 2*array, 3*array], times=[.1, exact_time, 2.75])
        result = execute(map_request(path, array.shape, native_cursor=1.25))
        self.assertEqual(result["data"]["record"]["native_time"], float_token(exact_time))
        self.assertEqual(result["data"]["record"]["requested_time"], float_token(1.25))
        self.assertEqual(result["data"]["record"]["sampling"], "held")
        self.assertEqual(result["data"]["record"]["index"], 1)
        self.assertEqual(result["source"]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertAlmostEqual(result["data"]["measurements"][0]["power"], independent_band(2*array, .1, .4)["band_power"], places=12)

    def test_invalid_band_grid_geometry_units_and_missing_signed_channel_are_refused(self):
        array = wave((8, 8, 8), (2, 2, 2))
        path = self.capture(array)
        for band in [(0, 0), (-.1, .2), (.2, .1), (.1, .50001)]:
            with self.subTest(band=band), self.assertRaises(AnalysisError):
                execute(map_request(path, [8]*3, band=band))
        for options in [dict(count=(8, 9)), dict(hop=(0, 1)), dict(hop=(-1, 1)),
                        dict(start=(.1, 0)), dict(plane_axis="q"), dict(fixed_start=.1)]:
            with self.subTest(options=options), self.assertRaises(AnalysisError):
                execute(map_request(path, [8]*3, **options))
        for arguments in [dict(support=[3, 8, 8]), dict(support=[4, 4, 257]),
                          dict(support=[193]*3),
                          dict(position_units=""), dict(value_units=[]), dict(extra=True)]:
            with self.subTest(arguments=arguments), self.assertRaises(AnalysisError):
                execute(map_request(path, [8]*3, arguments=arguments))
        for transform in [[2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0],
                          [0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
                          [1, .2, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]]:
            transformed = self.capture(array, transform=transform)
            with self.assertRaises(AnalysisError) as caught:
                execute(map_request(transformed, [8]*3))
            self.assertEqual(caught.exception.code, "unsupported_transform")
        energy = self.capture(array, channel="energy_density")
        with self.assertRaises(AnalysisError) as caught:
            execute(map_request(energy, [8]*3))
        self.assertEqual(caught.exception.code, "missing_channel")
        for metadata in [dict(position_unit=["m"]),
                         dict(channel_metadata={"field": {"amplitude": {"semantic": "phase"}}})]:
            malformed = self.capture(array, metadata=metadata)
            with self.subTest(metadata=metadata), self.assertRaises(AnalysisError):
                execute(map_request(malformed, [8]*3))
        unknown = self.capture(array, position_units="unknown", value_units="unknown")
        unknown_result = execute(map_request(unknown, [8]*3))["data"]
        self.assertEqual(unknown_result["units"]["position"], "unknown")
        self.assertTrue(any("unknown" in warning for warning in unknown_result["warnings"]))

    def test_request_keys_bind_channel_band_geometry_and_grid_parameters(self):
        array = wave((16, 16, 16), (2, 3, 4))
        path = self.root / "two-channels.wvz"
        with SceneCapture(path, objects=[dict(id="field", kind="volume", units="u", data_to_world=IDENTITY)]) as capture:
            capture.add_volume("field", 0., {"amplitude": array, "other": array}, origin=[1.25, -2., 3.], spacing=[1., 1., 1.])
        first = execute(map_request(path, [8]*3))["data"]
        variants = [dict(arguments={"channel": "other"}), dict(band=(.11, .4)),
                    dict(start=(1, 0)), dict(fixed_start=1), dict(hop=(2, 1)),
                    dict(arguments={"position_units": "cm"}), dict(native_cursor=.1)]
        keys = [first["request_key"]]
        for options in variants:
            reply = execute(map_request(path, [8]*3, **options))["data"]
            keys.append(reply["request_key"])
        self.assertEqual(len(keys), len(set(keys)))
        # Both channels have identical bytes, same descriptor, same region and same numbers.
        # Channel identity itself must distinguish the accepted individual operation too.
        one = execute(request(path, [8]*3))["data"]
        two = execute(request(path, [8]*3, arguments={"channel": "other"}))["data"]
        self.assertEqual(one["total_power"], two["total_power"])
        self.assertNotEqual(one["request_key"], two["request_key"])

    def test_source_mutation_truncation_checksum_and_midbatch_change_are_refused(self):
        array = wave((12, 12, 12), (2, 2, 2))
        for mode in ("changed", "truncated"):
            path = self.capture(array)
            with SourceSnapshot(path) as snapshot:
                identity = snapshot.identity()
                offset = snapshot.samples["field"][0]["offset"]
            raw = path.read_bytes()
            path.write_bytes(raw[:-1] if mode == "truncated" else raw[:offset]+bytes([raw[offset]^1])+raw[offset+1:])
            with self.subTest(mode=mode), self.assertRaises(AnalysisError):
                execute(map_request(path, [8]*3, source=identity))
            if mode == "changed":
                with self.assertRaisesRegex((AnalysisError, ValueError), "checksum"):
                    execute(map_request(path, [8]*3))
        path = self.capture(array)
        with SourceSnapshot(path) as snapshot:
            offset = snapshot.samples["field"][0]["offset"]
        changed = []
        def progress(stage, completed, total):
            if stage == "band_map_centers" and completed == 1 and not changed:
                with path.open("r+b") as stream:
                    stream.seek(offset)
                    first = stream.read(1)
                    stream.seek(offset)
                    stream.write(bytes([first[0]^1]))
                changed.append(True)
        context = Context(progress=progress)
        with self.assertRaises(AnalysisError) as caught:
            execute(map_request(path, [8]*3, count=(2, 2)), context=context)
        self.assertTrue(changed)
        self.assertEqual(caught.exception.code, "source_changed")
        self.assertEqual(context.used, 0)

    def test_memory_admission_and_midbatch_cancel_release_allocations(self):
        array = wave((12, 12, 12), (2, 2, 2))
        path = self.capture(array)
        context = Context(memory_bytes=12*MIB)
        with mock.patch("numpy.fft.rfftn", side_effect=AssertionError("FFT must not run")):
            with self.assertRaises(AnalysisError) as caught:
                execute(map_request(path, [8]*3), context=context)
        self.assertEqual(caught.exception.code, "memory_limit")
        self.assertEqual(context.used, 0)
        completed_centers = []
        def progress(stage, completed, total):
            if stage == "band_map_centers" and completed:
                completed_centers.append(completed)
        context = Context(progress=progress, cancelled=lambda: bool(completed_centers))
        with self.assertRaises(Cancelled):
            execute(map_request(path, [8]*3, count=(2, 2)), context=context)
        self.assertEqual(completed_centers, [1])
        self.assertEqual(context.used, 0)

    def test_individual_spectrum_band_agrees_without_changing_radial_diagnostic(self):
        array = wave((7, 8, 9), (1, 2, 3)) + .2*wave((7, 8, 9), (0, 0, 1))
        path = self.capture(array)
        ordinary = execute(request(path, array.shape))["data"]
        individual = execute(request(path, array.shape, arguments={"band": {"low": .1, "high": .4}}))["data"]
        mapped = execute(map_request(path, array.shape))["data"]["measurements"][0]
        self.assertEqual(ordinary["radial"], individual["radial"])
        self.assertEqual(ordinary["total_power"], individual["total_power"])
        self.assertEqual(individual["band"]["power"], mapped["power"])
        self.assertAlmostEqual(mapped["power"], independent_band(array, .1, .4)["band_power"], places=12)

    def test_real_worker_midbatch_cancel_supersession_and_revision_reuse(self):
        array = wave((128, 160, 160), (3, 4, 5)).astype("f4")
        path = self.capture(array)
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        with WorkerSession(self.root / "worker") as worker:
            large = map_request(path, [128]*3, hop=(4, 4), count=(8, 8), request_id="cancel-map")
            worker.write("background_request.json", large)
            progress = worker.wait("background_progress.json", lambda row:
                row.get("id") == "cancel-map" and row.get("stage") == "band_map_centers"
                and 0 < row.get("completed", 0) < row.get("total", 0))
            began = time.monotonic()
            worker.write("background_cancel.json", {"id": "cancel-map"})
            cancelled = worker.wait("background_result.json", lambda row: row.get("id") == "cancel-map")
            latency = time.monotonic()-began
            self.assertFalse(cancelled["ok"])
            self.assertEqual(cancelled["code"], "cancelled")
            self.assertEqual(cancelled["metrics"]["charged_bytes"], 0)
            self.assertLess(latency, 2.)
            self.assertNotIn("data", cancelled)  # Partial maps are never complete results.
            old = dict(large, id="superseded-map")
            worker.write("background_request.json", old)
            worker.wait("background_progress.json", lambda row:
                row.get("id") == "superseded-map" and row.get("stage") == "band_map_centers"
                and 0 < row.get("completed", 0) < row.get("total", 0))
            current = map_request(path, [128]*3, request_id="current-map", revisions=(8, 9, 10))
            worker.write("background_request.json", current)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "current-map")
            self.assertTrue(reply["ok"], reply)
            self.assertEqual([reply[k] for k in ["scene_revision", "selection_revision", "analysis_revision"]], [8, 9, 10])
            self.assertEqual(reply["data"]["coverage"]["total"], 1)
            self.assertEqual(reply["metrics"]["charged_bytes"], 0)
            self.assertLess(len(json.dumps(reply).encode()), MIB)
            WORKER_OBSERVATIONS.append(dict(scope="real unmodified worker; cancellation after a measured center, no pressure pause",
                cancellation_seconds=latency, observed_progress=progress, reply_bytes=len(json.dumps(reply).encode()),
                worker_memory=reply["memory"], logical=reply["metrics"], revisions=[8, 9, 10],
                superseded_map_not_published_as_current=True))
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)

    def test_owned_worker_close_midbatch_exits_without_complete_map(self):
        array = wave((128, 160, 160), (3, 4, 5)).astype("f4")
        path = self.capture(array)
        with WorkerSession(self.root / "closing-worker") as worker:
            worker.write("background_request.json", map_request(path, [128]*3, hop=(4, 4), count=(8, 8), request_id="close-map"))
            progress = worker.wait("background_progress.json", lambda row:
                row.get("id") == "close-map" and row.get("stage") == "band_map_centers"
                and 0 < row.get("completed", 0) < row.get("total", 0))
            began = time.monotonic()
            worker.write("close", {})
            worker.process.wait(timeout=2)
            self.assertEqual(worker.process.returncode, 0)
            self.assertFalse((worker.directory / "background_result.json").exists())
            WORKER_OBSERVATIONS.append(dict(scope="owned worker close after a measured center",
                close_seconds=time.monotonic()-began, observed_progress=progress, complete_map_published=False))


if __name__ == "__main__":
    unittest.main()

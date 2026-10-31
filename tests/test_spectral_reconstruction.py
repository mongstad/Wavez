"""Independent full DFT and lifecycle checks for native reconstructed volumes."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import numpy as np

from tests.test_spatial_spectrum import IDENTITY, WorkerSession, field_capture, wave
from wavez_export.analysis import AnalysisError, Cancelled, Context, SourceSnapshot
from wavez_export.analysis.contracts import MIB, parse_float_token
from wavez_export.analysis.jobs import execute
from wavez_export.analysis.spectral_reconstruction import (
    BANDS, DenseReconstructionStore, _Publication, run, workspace_bytes,
)


def request(path, index=0, **arguments):
    return dict(version=1, id="reconstruction", scene_revision=3, selection_revision=5,
        analysis_revision=7, operation="spectral_reconstruct", source=dict(path=str(path)),
        arguments=dict(object="field", channel="amplitude", index=index, boundary="periodic", **arguments),
        budget=dict(memory_bytes=1024*MIB))


def direct_dft(array, spacing, edges):
    """Exponential matrices, full signed frequencies and independent inverse.

    No FFT or production numerical helper is used by this small-grid oracle.
    """
    matrices = [np.exp(-2j*np.pi*np.outer(np.arange(n), np.arange(n))/n) for n in array.shape]
    coefficients = np.einsum("az,by,cx,zyx->abc", *matrices, array, optimize=True)
    axes = []
    for n, d in zip(array.shape, spacing[::-1]):
        i = np.arange(n)
        axes.append(np.where(i < (n+1)//2, i, i-n)/(n*d))
    radius = np.sqrt(sum(axis.reshape([len(axis) if i == j else 1 for j in range(3)])**2 for i, axis in enumerate(axes)))
    masks = (radius < edges[0], (radius >= edges[0]) & (radius < edges[1]), radius >= edges[1])
    result = {}
    for name, mask in zip(BANDS, masks):
        field = np.einsum("az,by,cx,abc->zyx", *(m.conj() for m in matrices), coefficients*mask, optimize=True).real/array.size
        result[name] = dict(array=field, cells=int(mask.sum()), power=float(np.sum(abs(coefficients*mask)**2)/array.size**2))
    return result


class ReconstructionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry = self.root/"registry"
        self.registry.mkdir()
        self.store = DenseReconstructionStore(self.registry/"test-reconstruction", registry_root=self.registry)
        self.serial = 0

    def tearDown(self):
        self.tmp.cleanup()

    def capture(self, array, **kwargs):
        self.serial += 1
        return field_capture(self.root/f"field-{self.serial}.wvz", array, **kwargs)

    def evaluate(self, array, spacing=(1., 1., 1.), edges=(.125, .375), **kwargs):
        path = self.capture(array, spacing=spacing, **kwargs)
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        reply = execute(request(path, edges=list(edges)), reconstruction_store=self.store)
        data = reply["data"]
        oracle = direct_dft(array, spacing, edges)
        self.assertEqual(reply["metrics"]["charged_bytes"], 0)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)
        reconstructed = []
        for name, item in data["artifacts"].items():
            scientific = item["scientific"]
            raw = Path(scientific["path"]).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), scientific["sha256"])
            self.assertEqual(len(raw), scientific["bytes"])
            values = np.frombuffer(raw, dtype="<f8").reshape(array.shape)
            display = np.fromfile(item["path"], dtype="<f4").reshape(array.shape)
            np.testing.assert_array_equal(display, values.astype(np.float32))
            if name == "original":
                np.testing.assert_array_equal(values, array)
            else:
                np.testing.assert_allclose(values, oracle[name]["array"], atol=3e-14, rtol=2e-13)
                self.assertEqual(data["metrics"]["bands"][name]["full_dft_cells"], oracle[name]["cells"])
                self.assertAlmostEqual(data["metrics"]["bands"][name]["mean_square"], oracle[name]["power"], places=12)
                reconstructed.append(values)
        np.testing.assert_allclose(sum(reconstructed), array, atol=2e-14, rtol=2e-13)
        self.assertLess(data["metrics"]["residual_relative_rms"], 1e-12)
        self.assertLess(data["metrics"]["parseval_relative_error"], 1e-12)
        manifest = Path(data["manifest"]["path"]).read_bytes()
        self.assertEqual(hashlib.sha256(manifest).hexdigest(), data["manifest"]["sha256"])
        self.assertEqual(json.loads(manifest)["artifacts"], data["artifacts"])
        self.assertEqual(len(list(self.store.results.iterdir())), 1)
        return data

    def test_independent_single_mixed_oblique_odd_even_and_anisotropic(self):
        for shape in [(5, 6, 7), (6, 7, 8)]:
            for bins, spacing in [((0, 0, 1), (1., 1., 1.)), ((1, -2, 2), (.25, .5, 1.5))]:
                with self.subTest(shape=shape, bins=bins, spacing=spacing):
                    array = .37 + wave(shape, bins, phase=.71) + .23*wave(shape, (2, 1, -1), phase=-.37)
                    self.evaluate(array, spacing)

    def test_dc_nyquist_and_exact_half_open_edges(self):
        shape = (8, 8, 8)
        for bins, expected in [((0, 0, 0), "low"), ((0, 0, 1), "intermediate"), ((0, 0, 3), "high"), ((4, 4, 4), "high")]:
            with self.subTest(bins=bins):
                data = self.evaluate(wave(shape, bins))
                self.assertAlmostEqual(data["metrics"]["bands"][expected]["fraction"], 1., places=13)
        data = self.evaluate(np.zeros(shape))
        self.assertEqual(data["common_range"], [0., 0.])
        self.assertEqual(data["metrics"]["residual_max"], 0.)

    def test_index_pins_exact_native_record_and_preserves_cell_geometry(self):
        arrays = [wave((6, 6, 6), (0, 0, 1)), 2*wave((6, 6, 6), (1, 1, 1))]
        path = self.capture(arrays, times=[.1, 20.25], centering="cell")
        data = execute(request(path, 1), reconstruction_store=self.store)["data"]
        self.assertEqual(data["record"]["index"], 1)
        self.assertEqual(parse_float_token(data["record"]["native_time"]), 20.25)
        self.assertEqual(data["geometry"]["centering"], "cell")
        self.assertEqual(data["geometry"]["origin"], [1.25, -2., 3.])
        self.assertEqual(data["source_stamp"]["mtime_ns"], str(path.stat().st_mtime_ns))
        np.testing.assert_array_equal(np.fromfile(data["artifacts"]["original"]["scientific"]["path"], dtype="<f8").reshape(arrays[1].shape), arrays[1])

    def test_weak_ac_on_large_dc_uses_stable_centered_power(self):
        array = 1e6 + 1e-4*wave((8, 8, 8), (0, 0, 1))
        path = self.capture(array)
        data = execute(request(path), reconstruction_store=self.store)["data"]
        expected = float(np.mean((array-array.mean())**2))
        self.assertAlmostEqual(data["metrics"]["ac_mean_square"]/expected, 1., places=12)
        self.assertGreater(data["metrics"]["ac_mean_square"], 0.)
        self.assertAlmostEqual(data["metrics"]["bands"]["intermediate"]["ac_fraction"], 1., places=6)

    def test_refuse_float32_nonfinite_transform_missing_boundary_and_wrong_channel(self):
        shift = IDENTITY.copy()
        shift[3] = 1
        for array, kwargs, changed, code in [
            (np.ones((4, 4, 4), dtype=np.float32), {}, {}, "unsupported_channel"),
            (np.full((4, 4, 4), np.nan), {}, {}, "nonfinite_samples"),
            (np.ones((4, 4, 4)), {"transform": shift}, {}, "unsupported_transform"),
            (np.ones((4, 4, 4)), {}, {"boundary": None}, "unsupported_boundary"),
            (np.ones((4, 4, 4)), {}, {"channel": "energy"}, "unsupported_channel"),
            (np.ones((4, 4, 193)), {}, {}, "unsupported_geometry"),
            (np.ones((4, 4, 4)), {}, {"index": 2}, "invalid_request"),
        ]:
            path = self.capture(array, **kwargs)
            message = request(path)
            message["arguments"].update(changed)
            with self.subTest(code=code), self.assertRaises(AnalysisError) as caught:
                execute(message, reconstruction_store=self.store)
            self.assertEqual(caught.exception.code, code)
            self.assertEqual(list(self.store.results.iterdir()), [])

    def test_memory_and_disk_admission_refuse_without_partial_publication(self):
        path = self.capture(np.ones((32, 32, 32)))
        message = request(path)
        message["budget"]["memory_bytes"] = 16*MIB
        with self.assertRaises(AnalysisError) as caught:
            execute(message, reconstruction_store=self.store)
        self.assertEqual(caught.exception.code, "memory_limit")
        self.assertEqual(list(self.store.results.iterdir()), [])
        self.store.quota.limit = 1024
        with self.assertRaises(AnalysisError) as caught:
            execute(request(path), reconstruction_store=self.store)
        self.assertEqual(caught.exception.code, "disk_limit")
        self.assertEqual(list(self.store.results.iterdir()), [])
        # At the declared maximum, algorithm + separate reader lease + modest
        # source metadata fit 1 GiB; the kernel does not silently enlarge budgets.
        self.assertLess(workspace_bytes([192]*3) + 192**3*24 + 12*MIB, 1024*MIB)

    def test_cancel_during_active_reconstruction_cleans_unpublished_files(self):
        path = self.capture(wave((32, 32, 32), (2, 3, 4)))
        active = {"cancel": False}
        def progress(stage, *_):
            if stage == "reconstruction_low":
                active["cancel"] = True
        context = Context(memory_bytes=1024*MIB, progress=progress, cancelled=lambda: active["cancel"])
        with self.assertRaises(Cancelled):
            execute(request(path), context=context, reconstruction_store=self.store)
        self.assertTrue(active["cancel"])
        self.assertEqual(context.used, 0)
        self.assertEqual(list(self.store.results.iterdir()), [])

    def test_source_mutation_before_publication_is_rejected(self):
        path = self.capture(wave((8, 8, 8), (1, 1, 1)))
        original = _Publication.write_array
        def mutate(publication, name, values):
            result = original(publication, name, values)
            if name == "high":
                with path.open("r+b") as file:
                    file.seek(-1, 2)
                    byte = file.read(1)
                    file.seek(-1, 2)
                    file.write(bytes([byte[0] ^ 1]))
            return result
        with mock.patch.object(_Publication, "write_array", mutate), self.assertRaises(AnalysisError) as caught:
            execute(request(path), reconstruction_store=self.store)
        self.assertEqual(caught.exception.code, "source_changed")
        self.assertEqual(list(self.store.results.iterdir()), [])

    def test_atomic_stage_release_and_abandoned_reaper(self):
        path = self.capture(np.ones((4, 4, 4)))
        context = Context(memory_bytes=1024*MIB)
        with SourceSnapshot(path, context=context) as source:
            data = run(source, request(path)["arguments"], self.store)
        manifest = Path(data["manifest"]["path"])
        self.assertFalse(manifest.exists())
        self.assertTrue(manifest.parent.with_name(manifest.parent.name+".part").is_dir())
        context.commit_publications()
        self.assertTrue(manifest.exists())
        self.store.release(str(manifest.parent.parent/"../manifest.json"))
        self.assertTrue(manifest.exists())
        self.store.release(str(manifest))
        self.assertFalse(manifest.exists())
        owner = self.store.root/"owner.json"
        info = json.loads(owner.read_text())
        info["birth"] = "not-current-process-birth"
        owner.write_text(json.dumps(info))
        DenseReconstructionStore.reap_abandoned(self.registry, Context())
        self.assertFalse(self.store.root.exists())

    def test_worker_background_result_release_and_shutdown_cleanup(self):
        path = self.capture(wave((16, 16, 16), (1, 2, 3)))
        worker = WorkerSession(self.registry/"worker")
        try:
            worker.start()
            worker.write("background_request.json", request(path))
            result = worker.wait("background_result.json")
            self.assertTrue(result["ok"], result)
            self.assertEqual(result["shared_memory"]["used"], 0)
            manifest = Path(result["data"]["manifest"]["path"])
            self.assertTrue(manifest.exists())
            worker.write("reconstruction_release.json", {"manifest": str(manifest)})
            # A following interactive query is only served after idle release.
            message = request(path)
            message.update(id="describe", operation="describe", arguments={})
            worker.write("request.json", message)
            worker.wait("result.json", lambda result: result.get("id") == "describe")
            self.assertFalse(manifest.exists())
        finally:
            worker.close()
        self.assertFalse((self.registry/"worker-reconstruction").exists())

    def test_worker_cancels_active_batch_and_reaps_no_partial_result(self):
        # Large enough that a genuine computation stage is observable, still a
        # generated bounded fixture. Cancellation goes through production IPC.
        path = self.capture(wave((128, 128, 128), (3, 4, 5)))
        worker = WorkerSession(self.registry/"cancel-worker")
        try:
            worker.start()
            worker.write("background_request.json", request(path))
            progress = worker.wait("background_progress.json", lambda result: result.get("stage", "").startswith("reconstruction_"))
            self.assertEqual(progress["id"], "reconstruction")
            worker.write("background_cancel.json", {"id": "reconstruction"})
            result = worker.wait("background_result.json")
            self.assertFalse(result["ok"])
            self.assertEqual(result["code"], "cancelled")
            self.assertEqual(result["metrics"]["charged_bytes"], 0)
            self.assertEqual(list((self.registry/"cancel-worker-reconstruction"/"results").iterdir()), [])
        finally:
            worker.close()

    def test_private_quota_charges_dense_result_and_unknown_files_are_preserved(self):
        path = self.capture(wave((8, 8, 8), (1, 1, 1)))
        data = execute(request(path), reconstruction_store=self.store)["data"]
        usage = self.store.quota.usage(Context())
        self.assertGreaterEqual(usage["bytes"], 8**3*48)
        self.assertEqual(usage["files"], 10)
        unexpected = Path(data["manifest"]["path"]).parent/"keep-this.txt"
        unexpected.write_text("Unrecognized files must remain quarantined")
        with self.assertRaises(AnalysisError):
            self.store.clear()
        self.assertTrue(unexpected.exists())

    def test_worker_late_cancel_releases_unaccepted_reply_and_not_a_newer_result(self):
        path = self.capture(wave((8, 8, 8), (1, 2, 3)))
        worker = WorkerSession(self.registry/"late-cancel-worker")
        def barrier(serial):
            message = request(path)
            message.update(id="barrier-"+str(serial), operation="describe", arguments={})
            worker.write("request.json", message)
            worker.wait("result.json", lambda result: result.get("id") == message["id"])
        try:
            worker.start()
            worker.write("background_request.json", request(path))
            result = worker.wait("background_result.json")
            self.assertTrue(result["ok"], result)
            first = Path(result["data"]["manifest"]["path"])
            # Simulate cancel before the UI polls the completed reply: it cannot
            # send a manifest release because it has not accepted this result.
            worker.write("background_cancel.json", {"id": "reconstruction"})
            barrier(1)
            self.assertFalse(first.exists())
            second_request = request(path)
            second_request["id"] = "next-reconstruction"
            worker.write("background_request.json", second_request)
            result = worker.wait("background_result.json", lambda value: value.get("id") == second_request["id"])
            self.assertTrue(result["ok"], result)
            second = Path(result["data"]["manifest"]["path"])
            worker.write("reconstruction_release.json", {"manifest": str(first)})
            barrier(2)
            self.assertTrue(second.exists())
        finally:
            worker.close()


if __name__ == "__main__":
    unittest.main()

"""Selected native-time persistence, exact parity and owned-worker boundaries."""
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock

from tests.test_spatial_spectrum import WorkerSession, field_capture, wave
from tests.test_spatial_band_map import map_request
from wavez_export.analysis import AnalysisError, Cancelled, Context, SourceSnapshot
from wavez_export.analysis.contracts import MIB, float_token
from wavez_export.analysis.disk_quota import DiskQuota
from wavez_export.analysis.jobs import execute
from wavez_export.analysis.memo import VerificationMemo
from wavez_export.analysis.result_store import encoded
from wavez_export.analysis.spatial_band_sequence import SpectralCache, RESULT_BYTES


def sequence_request(path, support=(8, 8, 8), indices=(0, 1, 2), **kwargs):
    value = map_request(path, support, **kwargs)
    value["operation"] = "spectral_band_sequence"
    value["arguments"].pop("time")
    value["arguments"]["indices"] = list(indices)
    return value


class SpatialBandSequenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.arrays = [wave((8, 8, 16), (0, 0, 4))*a for a in (1., 2., 3.)]
        self.times = [0., .10000000000000003, 2.75]
        self.path = field_capture(self.root/"field.wvz", self.arrays, times=self.times)
        self.store = SpectralCache(self.root/"registry")
        self.request = sequence_request(self.path, start=(0, -8), hop=(8, 8), count=(1, 4))

    def tearDown(self):
        self.temporary.cleanup()

    def run_sequence(self, request=None, **kwargs):
        return execute(request or self.request, spectral_cache=self.store, **kwargs)

    def result_path(self):
        return next(self.store.cache.root.iterdir())

    def test_known_native_values_and_masks_equal_direct_maps_and_reopen_hits(self):
        digest = hashlib.sha256(self.path.read_bytes()).hexdigest()
        first = self.run_sequence()
        self.assertFalse(first["data"]["cache"]["hit"])
        for index, value in enumerate(first["data"]["maps"]):
            direct = execute(map_request(self.path, [8]*3, native_cursor=self.times[index],
                start=(0, -8), hop=(8, 8), count=(1, 4)))["data"]
            self.assertEqual(value["measurements"], direct["measurements"])
            self.assertEqual(value["coverage"], direct["coverage"])
            self.assertEqual(value["request_key"], direct["request_key"])
            self.assertEqual(value["record"]["native_time"], float_token(self.times[index]))
        powers = [value["measurements"][1]["power"] for value in first["data"]["maps"]]
        self.assertAlmostEqual(powers[1]/powers[0], 4.)
        self.assertAlmostEqual(powers[2]/powers[0], 9.)
        self.store = SpectralCache(self.root/"registry")
        with mock.patch("numpy.fft.rfftn", side_effect=AssertionError("Cache hit must not FFT")):
            second = self.run_sequence()
        self.assertTrue(second["data"]["cache"]["hit"])
        self.assertEqual(first["data"]["maps"], second["data"]["maps"])
        self.assertEqual(second["metrics"]["decoded_bytes"], 0)
        self.assertEqual(second["metrics"]["charged_bytes"], 0)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), digest)

    def test_one_verified_prefix_and_one_decode_per_selected_time_then_fresh_reverify(self):
        digest, read = SourceSnapshot._digest, SourceSnapshot.read_sample
        with mock.patch.object(SourceSnapshot, "_digest", autospec=True, side_effect=digest) as hashed, \
             mock.patch.object(SourceSnapshot, "read_sample", autospec=True, side_effect=read) as decoded:
            self.run_sequence(memo=VerificationMemo())
            self.assertEqual((hashed.call_count, decoded.call_count), (1, 3))
            second = self.run_sequence(memo=VerificationMemo())
            self.assertTrue(second["data"]["cache"]["hit"])
            self.assertEqual((hashed.call_count, decoded.call_count), (2, 3))

    def test_band_indices_grid_units_and_implementation_identity_are_bound(self):
        original = self.run_sequence()["data"]["request_key"]
        keys = [original]
        for change in ({"band": {"low": .11, "high": .4}}, {"indices": [0, 2]},
                       {"position_units": "cm"}, {"value_units": "different"},
                       {"grid": dict(plane_axis="z", fixed_start=0, start=[0, 0], hop=[8, 8], count=[1, 2])}):
            request = copy.deepcopy(self.request); request["arguments"].update(change)
            result = self.run_sequence(request)
            self.assertFalse(result["data"]["cache"]["hit"])
            keys.append(result["data"]["request_key"])
        with mock.patch("wavez_export.analysis.spatial_band_sequence.implementation_identity", return_value="0"*64):
            result = self.run_sequence()
            self.assertFalse(result["data"]["cache"]["hit"])
            keys.append(result["data"]["request_key"])
        self.assertEqual(len(keys), len(set(keys)))

    def test_append_new_extent_misses_old_pinned_prefix_can_reverify(self):
        full = self.path.read_bytes()
        with SourceSnapshot(self.path) as source:
            end = source.samples["field"][1]["end"]
        self.path.write_bytes(full[:end])
        request = sequence_request(self.path, indices=[0, 1])
        old = self.run_sequence(request)
        with self.path.open("ab") as stream: stream.write(full[end:])
        appended = self.run_sequence(request)
        self.assertFalse(appended["data"]["cache"]["hit"])
        self.assertNotEqual(old["data"]["request_key"], appended["data"]["request_key"])
        pinned = copy.deepcopy(request); pinned["source"] = old["source"]
        reused = self.run_sequence(pinned)
        self.assertTrue(reused["data"]["cache"]["hit"])
        self.assertEqual(old["data"]["request_key"], reused["data"]["request_key"])

    def test_mutation_truncation_and_replacement_cannot_reuse_pinned_entry(self):
        first = self.run_sequence()
        pinned = copy.deepcopy(self.request); pinned["source"] = first["source"]
        raw = self.path.read_bytes()
        with SourceSnapshot(self.path) as source:
            offset = source.samples["field"][0]["offset"]
        for mode in ("mutation", "truncation", "replacement"):
            self.path.write_bytes(raw)
            if mode == "mutation":
                self.path.write_bytes(raw[:offset]+bytes([raw[offset]^1])+raw[offset+1:])
            elif mode == "truncation":
                self.path.write_bytes(raw[:-1])
            else:
                replacement = field_capture(self.root/"replacement.wvz", [a*4 for a in self.arrays], times=self.times)
                os.replace(replacement, self.path)
            with self.subTest(mode=mode), self.assertRaises(AnalysisError):
                self.run_sequence(pinned)

    def test_mid_sequence_cancel_leaves_no_complete_or_pending_result(self):
        progress = []
        context = Context(progress=lambda stage, complete, total: progress.append(stage) if stage == "band_map_centers" and complete else None,
                          cancelled=lambda: bool(progress))
        with self.assertRaises(Cancelled): self.run_sequence(context=context)
        self.assertEqual(list(self.store.cache.root.iterdir()), [])
        self.assertEqual(context.used, 0)
        self.assertFalse(self.run_sequence()["data"]["cache"]["hit"])

    def test_mid_sequence_source_change_and_final_cancel_roll_back_publication(self):
        changed = []
        raw = self.path.read_bytes()
        with SourceSnapshot(self.path) as source: offset = source.samples["field"][0]["offset"]
        def mutate(stage, complete, total):
            if stage == "band_sequence_times" and complete == 1 and not changed:
                self.path.write_bytes(raw[:offset]+bytes([raw[offset]^1])+raw[offset+1:]); changed.append(True)
        context = Context(progress=mutate)
        with self.assertRaises(AnalysisError): self.run_sequence(context=context)
        self.assertEqual(list(self.store.cache.root.iterdir()), [])
        self.assertEqual(context.used, 0)
        self.path.write_bytes(raw)
        context = Context()
        self.run_sequence(context=context, defer_publication=True)
        self.assertTrue(all(p.name.startswith(".pending-") for p in self.store.cache.root.iterdir()))
        context.cancelled = lambda: True
        with self.assertRaises(Cancelled): context.commit_publications()
        context.abort_publications("cancelled")
        self.assertEqual(list(self.store.cache.root.iterdir()), [])
        self.assertEqual(context.used, 0)

    def test_corrupt_manifest_or_support_recomputes_without_returning_bad_values(self):
        for artifact in ("manifest.json", "support-000000.jsonl"):
            self.run_sequence()
            path = self.result_path()/artifact
            data = path.read_bytes(); path.write_bytes(data[:-1]+bytes([data[-1]^1]))
            result = self.run_sequence()
            self.assertFalse(result["data"]["cache"]["hit"])
            self.assertEqual(len(list(self.store.cache.root.iterdir())), 1)
            self.assertTrue(self.run_sequence()["data"]["cache"]["hit"])

    def test_rehashed_semantically_invalid_map_is_discarded_and_recomputed(self):
        self.run_sequence()
        directory = self.result_path()
        manifest_path = directory/"manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["maps"][0]["coverage"]["measured"] = 999
        payload = encoded(manifest); manifest_path.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        directory.rename(directory.parent/("r-"+digest[:32]))
        result = self.run_sequence()
        self.assertFalse(result["data"]["cache"]["hit"])
        self.assertEqual(result["data"]["maps"][0]["coverage"]["measured"], 2)

    def test_valid_json_manifest_rewrite_under_original_identity_is_rejected(self):
        self.run_sequence()
        directory = self.result_path()
        path = directory/"manifest.json"
        manifest = json.loads(path.read_text())
        manifest["maps"][0]["units"]["frequency"] = "invented frequency"
        path.write_bytes(encoded(manifest))
        result = self.run_sequence()
        self.assertFalse(result["data"]["cache"]["hit"])
        self.assertEqual(result["data"]["maps"][0]["units"]["frequency"], "cycles / (m)")
        path = self.result_path()/"manifest.json"
        path.write_bytes(b" "*(MIB+1))
        result = self.run_sequence()
        self.assertFalse(result["data"]["cache"]["hit"])

    def test_waiting_store_cancel_cannot_collect_active_transaction(self):
        first_context = Context()
        self.run_sequence(context=first_context, defer_publication=True)
        pending = list(self.store.cache.root.iterdir())
        self.assertEqual(len(pending), 1)
        self.assertTrue(pending[0].name.startswith(".pending-"))
        second_store = SpectralCache(self.root/"registry")
        ready, cancel = threading.Event(), threading.Event()
        second_context = Context(cancelled=cancel.is_set,
            progress=lambda stage, complete, total: ready.set() if stage == "source_hash" and complete == total else None)
        failures = []
        def waiting():
            try: execute(self.request, spectral_cache=second_store, context=second_context)
            except Exception as exc: failures.append(exc)
        thread = threading.Thread(target=waiting, daemon=True)
        try:
            thread.start()
            self.assertTrue(ready.wait(timeout=2))
            time.sleep(.05)
            self.assertTrue(thread.is_alive())
            self.assertEqual(list(self.store.cache.root.iterdir()), pending)
            cancel.set(); thread.join(timeout=2)
            self.assertFalse(thread.is_alive())
            self.assertEqual(len(failures), 1)
            self.assertIsInstance(failures[0], Cancelled)
            self.assertEqual(list(self.store.cache.root.iterdir()), pending)
            self.assertEqual(second_context.used, 0)
        finally:
            cancel.set()
            first_context.abort_publications("test owner closed before publication")
            thread.join(timeout=2)
        self.assertEqual(first_context.used, 0)
        self.assertEqual(list(self.store.cache.root.iterdir()), [])

    def test_two_live_workers_serialize_one_complete_cache_result(self):
        registry = self.root/"parallel-workers"
        with WorkerSession(registry/"one") as first, WorkerSession(registry/"two") as second:
            first.write("background_request.json", self.request)
            second.write("background_request.json", self.request)
            replies = [worker.wait("background_result.json", lambda row: row.get("id") == self.request["id"]) for worker in (first, second)]
            for reply in replies: self.assertTrue(reply["ok"], reply)
            self.assertEqual(sorted(reply["data"]["cache"]["hit"] for reply in replies), [False, True])
            self.assertEqual(replies[0]["data"]["maps"], replies[1]["data"]["maps"])
            self.assertEqual(len(list((registry/"spectral-cache"/"results").iterdir())), 1)

    def test_worker_releases_writer_lease_after_prepublication_metrics_snapshot(self):
        from tools.analyze_selection import Worker
        directory = self.root/"direct-worker"/"job"
        directory.mkdir(parents=True)
        (directory/"lease.json").write_bytes(encoded(dict(owner=os.getpid())))
        # Exercise the production perform/commit path. Only the optional process
        # address-space guard is disabled so the test runner's RLIMIT is unchanged.
        with mock.patch("tools.analyze_selection.guard", return_value=dict(enabled=False)):
            worker = Worker(directory, os.getpid())
        for hit in (False, True):
            request = copy.deepcopy(self.request)
            request["id"] = "warm" if hit else "cold"
            (directory/"background_request.json").write_bytes(encoded(request))
            worker.perform(request, True)
            reply = json.loads((directory/"background_result.json").read_text())
            self.assertTrue(reply["ok"], reply)
            self.assertEqual(reply["data"]["cache"]["hit"], hit)
            self.assertEqual(reply["metrics"]["charged_bytes"], 0 if hit else 2*MIB+2*16384)
            self.assertEqual(reply["shared_memory"]["used"], 0 if hit else 2*MIB+2*16384)
            self.assertEqual(worker.pool.used, 0)
            self.assertIsNone(worker.background_context)
            self.assertEqual(worker.spectral_cache.cache.active, set())
            self.assertTrue(all(not path.name.startswith(".pending-") for path in worker.spectral_cache.cache.root.iterdir()))

    def test_abandoned_partial_cleanup_never_publishes_or_deletes_unknown_files(self):
        pending = self.store.cache.root/(".pending-r-"+"1"*32)
        pending.mkdir(); (pending/"reservation.json").write_text("broken")
        (pending/"support-000000.jsonl.part").write_text("partial")
        result = self.run_sequence()
        self.assertFalse(result["data"]["cache"]["hit"])
        self.assertFalse(pending.exists())
        unknown = self.store.cache.root/(".pending-r-"+"2"*32)
        unknown.mkdir(); private = unknown/"keep-me.txt"; private.write_text("owner data")
        with self.assertRaises(AnalysisError): self.run_sequence()
        self.assertEqual(private.read_text(), "owner data")

    def test_quota_refusal_precedes_decode_and_eviction_is_bounded(self):
        self.store = SpectralCache(self.root/"small", byte_limit=RESULT_BYTES-1)
        with mock.patch.object(SourceSnapshot, "read_sample", side_effect=AssertionError("No decode before admission")):
            with self.assertRaises(AnalysisError) as caught: self.run_sequence()
        self.assertEqual(caught.exception.code, "result_limit")
        registry = self.root/"global-small"
        self.store = SpectralCache(registry, quota=DiskQuota(registry, limit=MIB, free_reserve=0))
        with self.assertRaises(AnalysisError) as caught: self.run_sequence()
        self.assertEqual(caught.exception.code, "disk_limit")
        self.store = SpectralCache(self.root/"eviction", entry_limit=2)
        for edge in (.1, .11, .12):
            request = copy.deepcopy(self.request); request["arguments"]["band"]["low"] = edge
            self.run_sequence(request)
        self.assertEqual(len(list(self.store.cache.root.iterdir())), 2)
        self.assertFalse(self.run_sequence()["data"]["cache"]["hit"])
        self.assertEqual(len(list(self.store.cache.root.iterdir())), 2)

    def test_oversized_invalid_and_low_memory_requests_refuse_before_fft(self):
        cases = [{"indices": []}, {"indices": list(range(9))}, {"indices": [0, 0]},
                 {"indices": [2, 1]}, {"indices": [True]}, {"indices": [-1]},
                 {"indices": [3]}, {"time": 0}, {"channel": "energy_density"},
                 {"support": [193]*3}, {"grid": dict(plane_axis="z", fixed_start=0, start=[0, 0], hop=[1, 1], count=[8, 9])}]
        with mock.patch("numpy.fft.rfftn", side_effect=AssertionError("Invalid request must not FFT")):
            for change in cases:
                request = copy.deepcopy(self.request); request["arguments"].update(change)
                with self.subTest(change=change), self.assertRaises(AnalysisError): self.run_sequence(request)
            with self.assertRaises(AnalysisError) as caught: self.run_sequence(context=Context(memory_bytes=20*MIB))
            self.assertEqual(caught.exception.code, "memory_limit")

    def test_real_worker_restart_and_cross_worker_cache_reuse(self):
        registry = self.root/"workers"
        replies = []
        for name in ("first", "reopened"):
            with WorkerSession(registry/name) as worker:
                worker.write("background_request.json", self.request)
                reply = worker.wait("background_result.json", lambda value: value.get("id") == self.request["id"])
                self.assertTrue(reply["ok"], reply)
                replies.append(reply)
        self.assertFalse(replies[0]["data"]["cache"]["hit"])
        self.assertTrue(replies[1]["data"]["cache"]["hit"])
        self.assertEqual(replies[1]["metrics"]["decoded_bytes"], 0)
        self.assertEqual(replies[0]["data"]["maps"], replies[1]["data"]["maps"])

    def test_maximum_selection_fits_reply_and_disk_reservation(self):
        path = field_capture(self.root/"maximum.wvz", [wave((8, 12, 12), (1, 2, 3))*a for a in range(1, 9)])
        request = sequence_request(path, [4]*3, indices=list(range(8)), count=[8, 8])
        result = self.run_sequence(request)
        self.assertEqual(result["data"]["admission"]["total_centers"], 512)
        self.assertLess(len(encoded(result)), MIB)
        self.assertLess(result["data"]["cache"]["stored_bytes"], RESULT_BYTES)
        cached = self.run_sequence(request)
        self.assertTrue(cached["data"]["cache"]["hit"])
        self.assertEqual(result["data"]["maps"], cached["data"]["maps"])

    def test_invalid_spectral_namespace_does_not_block_existing_worker_analysis(self):
        registry = self.root/"invalid-store"
        registry.mkdir(); (registry/"spectral-cache").write_text("not a directory")
        with WorkerSession(registry/"worker") as worker:
            ordinary = map_request(self.path, [8]*3, request_id="ordinary")
            worker.write("background_request.json", ordinary)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "ordinary")
            self.assertTrue(reply["ok"], reply)
            sequence = copy.deepcopy(self.request); sequence["id"] = "sequence"
            worker.write("background_request.json", sequence)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "sequence")
            self.assertFalse(reply["ok"])
            ordinary["id"] = "ordinary-again"
            worker.write("background_request.json", ordinary)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "ordinary-again")
            self.assertTrue(reply["ok"], reply)

    def test_real_worker_mid_batch_cancel_and_following_recovery(self):
        arrays = [wave((128, 160, 160), (3, 4, 5)).astype("f4")*a for a in (1, 2)]
        path = field_capture(self.root/"active.wvz", arrays)
        request = sequence_request(path, [128]*3, indices=[0, 1], hop=(4, 4), count=(8, 8), request_id="cancel-sequence")
        with WorkerSession(self.root/"workers"/"cancel") as worker:
            worker.write("background_request.json", request)
            worker.wait("background_progress.json", lambda row: row.get("id") == "cancel-sequence" and row.get("stage") == "band_map_centers" and 0 < row.get("completed", 0) < row.get("total", 0))
            started = time.monotonic(); worker.write("background_cancel.json", {"id": "cancel-sequence"})
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "cancel-sequence")
            self.assertFalse(reply["ok"]); self.assertEqual(reply["code"], "cancelled")
            self.assertLess(time.monotonic()-started, 2.)
            self.assertNotIn("data", reply)
            self.assertEqual(list((worker.directory.parent/"spectral-cache"/"results").iterdir()), [])
            request = sequence_request(path, [128]*3, indices=[0], request_id="recovered", revisions=(9, 10, 11))
            worker.write("background_request.json", request)
            reply = worker.wait("background_result.json", lambda row: row.get("id") == "recovered")
            self.assertTrue(reply["ok"], reply)
            self.assertEqual([reply[k] for k in ("scene_revision", "selection_revision", "analysis_revision")], [9, 10, 11])


if __name__ == "__main__":
    unittest.main()

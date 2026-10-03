from pathlib import Path
import tempfile
import unittest
import os

from wavez_export.analysis import SourceSnapshot,Context,AnalysisError
from wavez_export.analysis.memo import VerificationMemo
from wavez_export.analysis.sampling import epoch
from tests.g4.fixtures import scene


class MemoTests(unittest.TestCase):
    def test_prefix_digest_reuse_requires_exact_file_stamp_and_extent(self):
        with tempfile.TemporaryDirectory() as directory:
            path=scene(Path(directory)/"fixture.wvz");memo=VerificationMemo()
            with SourceSnapshot(path,memo=memo) as source:
                cold=source.context.read_bytes;ref=source.identity()
                prefix=source.samples["p"][1]["end"];payload=source.samples["p"][0]["offset"]
            with SourceSnapshot(path,memo=memo) as source:
                self.assertEqual(cold-source.context.read_bytes,int(ref["committed_bytes"]))
            with SourceSnapshot(path,committed_bytes=str(prefix),memo=memo) as source:
                self.assertNotEqual(source.sha256,ref["sha256"])
                self.assertGreaterEqual(source.context.read_bytes,prefix)
            stamp=path.stat()
            with path.open("r+b") as file:
                file.seek(payload);old=file.read(1);file.seek(payload);file.write(bytes([old[0]^1]))
            os.utime(path,ns=(stamp.st_atime_ns,stamp.st_mtime_ns))
            with self.assertRaisesRegex(AnalysisError,"SHA-256 mismatch"):
                SourceSnapshot(path,sha256=ref["sha256"],memo=memo)

    def test_repeated_epoch_skips_payload_but_revalidates_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path=scene(Path(directory)/"fixture.wvz");memo=VerificationMemo()
            with SourceSnapshot(path,memo=memo) as source:
                self.assertEqual(epoch(source,"mesh",3)["first_index"],2)
                before=source.context.decoded_bytes
                self.assertEqual(epoch(source,"mesh",0)["first_index"],0)
                self.assertEqual(epoch(source,"mesh",2)["first_index"],2)
                self.assertEqual(source.context.decoded_bytes,before)
            with SourceSnapshot(path,memo=memo) as reopened:
                self.assertEqual(epoch(reopened,"mesh",3)["first_index"],2)
                self.assertEqual(reopened.context.decoded_bytes,0)
                with path.open("r+b") as file:file.seek(-1,2);file.write(b"X")
                with self.assertRaises(AnalysisError):epoch(reopened,"mesh",3)

    def test_audit_coverage_reuse_is_bound_to_full_prefix(self):
        with tempfile.TemporaryDirectory() as directory:
            path=scene(Path(directory)/"fixture.wvz");memo=VerificationMemo()
            with SourceSnapshot(path,memo=memo) as source:
                result=source.audit_identity("p",2)
                self.assertEqual(result["through_index"],2)
            with SourceSnapshot(path,memo=memo) as source:
                self.assertEqual(source.audit_identity("p",1)["through_index"],2)
                self.assertEqual(source.context.decoded_bytes,0)
                self.assertEqual(source.audit_identity("p",3)["through_index"],3)
                self.assertGreater(source.context.decoded_bytes,0)
                prefix=source.samples["p"][1]["end"]
            with SourceSnapshot(path,committed_bytes=str(prefix),memo=memo) as source:
                self.assertEqual(source.audit_identity("p")["through_index"],1)
                self.assertGreater(source.context.decoded_bytes,0)

    def test_eviction_is_bounded_and_returned_values_cannot_mutate_cache(self):
        memo=VerificationMemo(8192)
        for i in range(200):memo.put(("epoch","hash","mesh",i),dict(first_index=i,fingerprint="a"*64))
        self.assertLessEqual(memo.used,8192);self.assertGreater(memo.evictions,0)
        self.assertIsNone(memo.get(("epoch","hash","mesh",0)))
        result=memo.get(("epoch","hash","mesh",199));result["first_index"]=-1
        self.assertEqual(memo.get(("epoch","hash","mesh",199))["first_index"],199)

    def test_memo_reservation_is_part_of_admission(self):
        with tempfile.TemporaryDirectory() as directory:
            path=scene(Path(directory)/"fixture.wvz");context=Context(memory_bytes=1048576)
            with self.assertRaisesRegex(AnalysisError,"memory budget"):
                SourceSnapshot(path,context=context,memo=VerificationMemo())
            self.assertEqual(context.used,0)


if __name__=="__main__":unittest.main()

"""WVZ1 wire identity, current path boundary, and bounded refusal."""
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from wavez_export import SceneCapture, SceneReader, MetadataCapacityError
from wavez_export import scene, storage
from wavez_export.analysis import AnalysisError, Context, SourceSnapshot


class SceneContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'capture.wvz'
        with SceneCapture(self.path, objects=[dict(id='p', kind='particles', units='m', identity='persistent_i8')]) as writer:
            for t in [0., 1.]:
                writer.add_particles('p', t, np.array([[t, 0., 0.]]), ids=[2**63-1])
        self.raw = self.path.read_bytes()

    def tearDown(self):
        self.temp.cleanup()

    def test_exact_wvz1_wire_envelope_and_record_tags(self):
        self.assertEqual(scene.PREFIX.size, 16)
        self.assertEqual(scene.FRAME.size, 80)
        self.assertEqual(scene.COMMIT.size, 48)
        self.assertEqual(self.raw[:16], scene.PREFIX.pack(b'WVZ1\0\0\0\0', 1,
                                                           struct.unpack_from('<I', self.raw, 12)[0]))
        start = 16 + struct.unpack_from('<I', self.raw, 12)[0]
        self.assertEqual(json.loads(self.raw[16:start])['version'], 1)
        tag, dlen, stored, *_ = scene.FRAME.unpack_from(self.raw, start)
        self.assertEqual(tag, b'FRM1')
        self.assertEqual(scene.COMMIT.unpack_from(self.raw, start + 80 + dlen + stored)[0], b'COMMIT1\0')

    def test_retired_magic_is_refused_even_with_current_suffix(self):
        for magic in [b'VBCOSM1\0', b'SIMSCP1\0', b'SIMSCP2\0', b'SIMSCP3\0', b'SIMSCP4\0']:
            with self.subTest(magic=magic):
                self.path.write_bytes(magic + self.raw[8:])
                for strict in [True, False]:
                    with self.assertRaisesRegex(ValueError, 'Unsupported scene format'):
                        SceneReader(self.path, strict=strict)
                context = Context()
                with self.assertRaises(AnalysisError) as error:
                    SourceSnapshot(self.path, context=context)
                self.assertEqual(error.exception.code, 'unsupported_format')
                self.assertEqual(context.used, 0)

    def test_suffix_and_version_are_both_required(self):
        renamed = self.path.with_suffix('.ssc')
        renamed.write_bytes(self.raw)
        with self.assertRaisesRegex(ValueError, r'requires a \.wvz path'):
            SceneReader(renamed)
        with self.assertRaisesRegex(AnalysisError, r'requires a \.wvz path'):
            SourceSnapshot(renamed)
        with self.assertRaisesRegex(ValueError, r'requires a \.wvz path'):
            SceneCapture(renamed.with_name('new.ssc'), objects=[dict(id='p', kind='particles', units='m', identity='anonymous')])
        wrong = bytearray(self.raw)
        struct.pack_into('<I', wrong, 8, 4)
        self.path.write_bytes(wrong)
        with self.assertRaisesRegex(ValueError, 'Unsupported scene format'):
            SceneReader(self.path)
        self.path.write_bytes(self.raw.replace(b'"version":1', b'"version":4', 1))
        with self.assertRaisesRegex(ValueError, 'Unsupported scene metadata/version'):
            SceneReader(self.path)

    def test_descriptor_ceiling_refuses_before_reading_payload(self):
        raw = bytearray(self.raw)
        start = 16 + struct.unpack_from('<I', raw, 12)[0]
        struct.pack_into('<I', raw, start+4, storage.MAX_DESC+1)
        self.path.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, 'allocation limit'):
            SceneReader(self.path, strict=False)
        context = Context()
        with self.assertRaisesRegex(ValueError, 'allocation limit'):
            SourceSnapshot(self.path, context=context)
        self.assertEqual(context.used, 0)

    def test_metadata_capacity_is_separate_from_corruption(self):
        with patch.object(scene.json, 'loads', side_effect=AssertionError('parse before admission')):
            with self.assertRaises(MetadataCapacityError):
                SceneReader(self.path, metadata_bytes=128)
        context = Context()
        with self.assertRaises(AnalysisError) as error:
            SourceSnapshot(self.path, context=context, metadata_bytes=128)
        self.assertEqual(error.exception.code, 'memory_limit')
        self.assertEqual(context.used, 0)
        with SceneReader(self.path) as reader:
            self.assertEqual(len(reader.records), 2)
            used = reader.metadata_budget.used
            reader.refresh(strict=True)
            self.assertEqual(reader.metadata_budget.used, used)
        self.assertEqual(reader.metadata_budget.used, 0)
        self.assertFalse(reader.records)
        raw = bytearray(self.raw)
        raw[-1] ^= 1
        self.path.write_bytes(raw)
        for strict in [True, False]:
            with self.assertRaisesRegex(ValueError, 'Commit checksum'):
                SceneReader(self.path, strict=strict)

    def test_late_admission_failure_and_shared_analysis_budget_release(self):
        with SceneReader(self.path) as reader:
            limit = reader.metadata_budget.peak - 1
        with self.assertRaises(MetadataCapacityError):
            SceneReader(self.path, metadata_bytes=limit)
        context = Context()
        with self.assertRaises(AnalysisError) as error:
            SourceSnapshot(self.path, context=context, metadata_bytes=limit)
        self.assertEqual(error.exception.code, 'memory_limit')
        self.assertEqual(context.used, 0)
        # A larger metadata sub-budget cannot bypass the enclosing job budget.
        context = Context(memory_bytes=1024*1024)
        reservation = context.acquire(context.limit-128)
        with self.assertRaises(AnalysisError) as error:
            SourceSnapshot(self.path, context=context, metadata_bytes=2**30)
        self.assertEqual(error.exception.code, 'memory_limit')
        self.assertEqual(context.used, reservation)
        context.release(reservation)

    def test_failed_refresh_drops_previous_metadata_and_can_reopen(self):
        reader = SceneReader(self.path)
        reader.metadata_budget.limit = 128
        with self.assertRaises(MetadataCapacityError):reader.refresh()
        self.assertEqual(reader.metadata_budget.used, 0)
        self.assertFalse(reader.records)
        reader.metadata_budget.limit = 512*1024**2
        reader.refresh(strict=True)
        self.assertEqual(len(reader.records), 2)
        reader.close()

    def test_writer_keeps_individual_descriptor_limit_and_committed_prefix(self):
        path = self.path.with_name('wide.wvz')
        with SceneCapture(path, objects=[dict(id='p', kind='particles', units='m', identity='anonymous')]) as writer:
            before = writer.file.tell()
            with self.assertRaisesRegex(ValueError, 'Record descriptor ceiling'):
                writer.add_particles('p', 0., np.zeros((1, 3)), **{'a'*storage.MAX_DESC: np.ones(1)})
            self.assertEqual(writer.file.tell(), before)
            self.assertEqual(writer.seq, 0)
            writer.add_particles('p', 0., np.zeros((1, 3)))
        with SceneReader(path) as reader:self.assertEqual(len(reader.records), 1)


if __name__ == '__main__':
    unittest.main()

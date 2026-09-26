"""Supported capture boundary and bounded refusal, independent of file suffix."""
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from simscope_export import SceneCapture, SceneReader, MetadataCapacityError
from simscope_export import scene, storage
from simscope_export.analysis import AnalysisError, Context, SourceSnapshot


class SceneContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'capture.ssc'
        with SceneCapture(self.path, objects=[dict(id='p', kind='particles', units='m', identity='persistent_i8')]) as writer:
            for t in [0., 1.]:
                writer.add_particles('p', t, np.array([[t, 0., 0.]]), ids=[2**63-1])
        self.raw = self.path.read_bytes()

    def tearDown(self):
        self.temp.cleanup()

    def test_retired_magic_is_refused_even_with_native_suffix(self):
        for magic in [b'VBCOSM1\0', b'SIMSCP1\0', b'SIMSCP2\0', b'SIMSCP3\0']:
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

    def test_native_reader_checks_magic_and_version_not_just_suffix(self):
        renamed = self.path.with_suffix('.capture')
        renamed.write_bytes(self.raw)
        with SceneReader(renamed) as reader:
            self.assertEqual(reader.read_sample('p', 1)['particle_id'][0], 2**63-1)
        wrong = bytearray(self.raw)
        struct.pack_into('<I', wrong, 8, 2)
        self.path.write_bytes(wrong)
        with self.assertRaisesRegex(ValueError, 'Unsupported scene format'):
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
        path = self.path.with_name('wide.ssc')
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

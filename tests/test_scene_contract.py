"""Supported capture boundary and bounded refusal, independent of file suffix."""
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from simscope_export import SceneCapture, SceneReader
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

    def test_index_ceiling_and_corrupt_commit_do_not_publish_partial_success(self):
        with patch.object(scene, 'MAX_INDEX', 128):
            with self.assertRaisesRegex(ValueError, 'Index metadata ceiling'):
                SceneReader(self.path)
        raw = bytearray(self.raw)
        raw[-1] ^= 1
        self.path.write_bytes(raw)
        for strict in [True, False]:
            with self.assertRaisesRegex(ValueError, 'Commit checksum'):
                SceneReader(self.path, strict=strict)


if __name__ == '__main__':
    unittest.main()

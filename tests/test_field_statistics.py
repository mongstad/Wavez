"""SIMSCP4 summaries, contiguous fields and bounded refusal."""
import hashlib
from pathlib import Path
import struct
import tempfile
import unittest

import numpy as np

from wavez_export import SceneCapture, SceneReader
from wavez_export import scene, storage
from wavez_export.field_statistics import summarize, validate, verify
from tools.verify_ssc import verify as verify_capture


class FieldStatisticsTests(unittest.TestCase):
    def fixture(self, path):
        values = np.array([np.nan, np.inf, -np.inf, -0., 0., -1., 1., np.nextafter(1., 2.)]).reshape(2, 2, 2)
        with SceneCapture(path, objects=[dict(id='field', kind='volume', units='m'),
                                       dict(id='p', kind='particles', units='m', identity='anonymous')]) as writer:
            for t in (0., .3):
                writer.add_volume('field', t, dict(exact=values, single=values.astype('f4')),
                                  origin=[0, 0, 0], spacing=[1, 1, 1])
                writer.add_particles('p', t+.1, np.array([[1., 2., 3.]], dtype='f8'))
        return values

    def test_extrema_counts_precision_and_nonfinite(self):
        for dtype in ('f4', 'f8'):
            for values in ([np.nan, np.inf, -np.inf], [0., -0.], [-3., -2.], [1., 2.], [-1., 0., 1.],
                           [np.nextafter(1., 2.), 1e-200, 1e200]):
                with np.errstate(over='ignore'):
                    a = np.array(values, dtype=dtype)
                s = summarize(a); validate(s, a.size); verify(s, a)
                finite = [float(v) for v in a if np.isfinite(v)]
                self.assertEqual(s['finite'], len(finite))
                self.assertEqual(s['nonpositive'], sum(v <= 0 for v in finite))
                if finite:
                    self.assertEqual(struct.unpack('<d', bytes.fromhex(s['minimum']))[0], min(finite))
                    self.assertEqual(struct.unpack('<d', bytes.fromhex(s['maximum']))[0], max(finite))

    def test_invalid_summaries_and_false_values(self):
        a = np.array([-1., 0., 1.]); good = summarize(a)
        for key, value in [('finite', True), ('finite', -1), ('nonfinite', 9), ('nonpositive', 4),
                           ('minimum', 'f'*16), ('maximum', 'bad'), ('minimum', None), ('extra', 0)]:
            bad = dict(good, **{key: value})
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):validate(bad, 3)
        false = dict(good, minimum=struct.pack('<d', -2.).hex())
        validate(false, 3)
        with self.assertRaisesRegex(ValueError, 'differs from source'):verify(false, a)

    def test_mandatory_summary_and_exact_bits(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'capture.ssc'; values = self.fixture(path)
            self.assertEqual(verify_capture(path), 4)
            with SceneReader(path) as reader:
                self.assertEqual(reader.metadata['version'], 4)
                self.assertIn('statistics_v1', reader.records[0]['descriptor']['arrays'][0])
                self.assertEqual(reader.read_sample('field', 0)['exact'].tobytes(), values.tobytes())
                desc = reader.records[0]['descriptor']; spec = desc['arrays'][0]
                stats = spec.pop('statistics_v1')
                with self.assertRaises(ValueError):scene.schema_valid(reader.objects['field'], desc, 96, 96)
                spec['statistics_v1'] = stats
                spec['chunks'][0]['origin'] = [0, 0, 0]
                with self.assertRaisesRegex(ValueError, 'contiguous'):scene.schema_valid(reader.objects['field'], desc, 96, 96)

    def test_writer_and_verifier_reject_forged_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'capture.ssc'; self.fixture(path)
            self.assertEqual(verify_capture(path), 4)
            raw = path.read_bytes(); start = 16+scene.PREFIX.unpack(raw[:16])[2]
            header = list(scene.FRAME.unpack(raw[start:start+80])); dlen = header[1]
            import json
            desc = json.loads(raw[start+80:start+80+dlen])
            desc['arrays'][0]['statistics_v1']['minimum'] = struct.pack('<d', -2.).hex()
            data = storage.dumps(desc); header[1] = len(data); header[-1] = hashlib.sha256(data).digest()
            h = scene.FRAME.pack(*header); end = start+128+dlen+header[2]
            path.write_bytes(raw[:start]+h+data+raw[start+80+dlen:end-48]+
                             scene.COMMIT.pack(b'COMMIT4\0', 0, hashlib.sha256(h+data).digest())+raw[end:])
            with self.assertRaisesRegex(ValueError, 'differs from source'):verify_capture(path)



if __name__ == '__main__':
    unittest.main()

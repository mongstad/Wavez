import tempfile
import unittest
from pathlib import Path
from simscope_export import SceneReader, MetadataCapacityError
from simscope_export.analysis import Context, SourceSnapshot
from tests.metadata_fixture import generate, arrays


class LongDescriptorCaptureTests(unittest.TestCase):
    def test_real_writer_crosses_old_boundary_without_changing_science(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'long.ssc'
            report = generate(path)
            self.assertGreater(report['aggregate_descriptor_charge'], 32*1024**2)
            with SceneReader(path, cache_bytes=0) as reader:
                self.assertEqual(len(reader.records), report['records'])
                for i in range(report['records']):
                    self.assertEqual(reader.records[i]['time'], i*.125)
                    result = reader.read_sample('field', i)
                    expected = arrays(i)
                    self.assertEqual(set(result), set(expected))
                    for name in expected:self.assertEqual(result[name].tobytes(), expected[name].tobytes())
                self.assertLessEqual(reader.metadata_budget.peak, reader.metadata_budget.limit)
            context = Context()
            with SourceSnapshot(path, context=context) as source:
                self.assertEqual(source.record_count, report['records'])
                for row in report['oracle']:
                    with source.read_sample('field', row['index']) as sample:
                        self.assertEqual(sample.arrays['field_63'].tobytes(), arrays(row['index'])['field_63'].tobytes())
                self.assertLessEqual(context.peak, context.limit)
            self.assertEqual(context.used, 0)
            with self.assertRaises(MetadataCapacityError):SceneReader(path, metadata_bytes=1024**2)


if __name__ == '__main__':unittest.main()

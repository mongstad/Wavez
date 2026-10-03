"""G3 writer/reader regression discovered by the G4 large-sample fixture."""
from pathlib import Path
import tempfile
import unittest

import numpy as np

from wavez_export import SceneCapture,SceneReader
from wavez_export.analysis import SourceSnapshot
from wavez_export.codec import MAX_CHUNK


class SceneChunkTests(unittest.TestCase):
    def test_vector_arrays_keep_full_backing_buffer_across_chunk_boundaries(self):
        count=400003
        position=np.arange(count*3,dtype="f4").reshape(count,3)
        velocity=(position.astype("f8")+1e-8)/3
        with tempfile.TemporaryDirectory() as temporary:
            for compression in ("none","zstd"):
                path=Path(temporary)/(compression+".wvz")
                with SceneCapture(path,objects=[dict(id="p",kind="particles",identity="anonymous",units="m")],compression=compression) as writer:
                    writer.add_particles("p",0,position,velocity=velocity)
                    writer.add_particles("p",1,position[::-1],velocity=velocity[::-1])
                with SceneReader(path,cache_bytes=0) as reader,SourceSnapshot(path) as source:
                    for index in (1,0):
                        expected_position=position[::-1] if index else position
                        expected_velocity=velocity[::-1] if index else velocity
                        full=reader.read_sample("p",index)
                        np.testing.assert_array_equal(full["position"],expected_position)
                        np.testing.assert_array_equal(full["velocity"],expected_velocity)
                        arrays=reader.samples["p"][index]["descriptor"]["arrays"]
                        self.assertEqual([len(a["chunks"]) for a in arrays],[2,3])
                        self.assertTrue(all(0<int(c["decoded"])<=MAX_CHUNK for a in arrays for c in a["chunks"]))
                        with source.read_sample("p",index,["velocity"]) as selected:
                            self.assertEqual(set(selected.arrays),{"velocity"})
                            np.testing.assert_array_equal(selected.arrays["velocity"],expected_velocity)

    def test_volume_chunks_cross_planes_and_preserve_float_bits(self):
        shape=(67, 129, 130)
        with tempfile.TemporaryDirectory() as directory:
            for dtype in ('f4','f8'):
                values=np.arange(np.prod(shape),dtype=dtype).reshape(shape)/7
                values[0,0,:4]=[np.nan,np.inf,-np.inf,-0.]
                for compression in ('none','zstd'):
                    path=Path(directory)/f'{dtype}-{compression}.wvz'
                    with SceneCapture(path,objects=[dict(id='f',kind='volume',units='m')],compression=compression) as writer:
                        writer.add_volume('f',0,dict(value=values),origin=[0]*3,spacing=[1]*3)
                    with SceneReader(path) as reader,SourceSnapshot(path) as source:
                        spec=reader.records[0]['descriptor']['arrays'][0]
                        self.assertEqual(len(spec['chunks']),(values.nbytes+MAX_CHUNK-1)//MAX_CHUNK)
                        self.assertTrue(all('origin' not in c and 'shape' not in c for c in spec['chunks']))
                        self.assertEqual(reader.read_sample('f',0)['value'].tobytes(),values.tobytes())
                        with source.read_sample('f',0,['value']) as sample:
                            self.assertEqual(sample.arrays['value'].tobytes(),values.tobytes())


if __name__=="__main__":unittest.main()

"""G3 writer/reader regression discovered by the G4 large-sample fixture."""
from pathlib import Path
import tempfile
import unittest

import numpy as np

from simscope_export import SceneCapture,SceneReader
from simscope_export.analysis import SourceSnapshot
from simscope_export.codec import MAX_CHUNK


class SceneChunkTests(unittest.TestCase):
    def test_vector_arrays_keep_full_backing_buffer_across_chunk_boundaries(self):
        count=400003
        position=np.arange(count*3,dtype="f4").reshape(count,3)
        velocity=(position.astype("f8")+1e-8)/3
        with tempfile.TemporaryDirectory() as temporary:
            for compression in ("none","zstd"):
                path=Path(temporary)/(compression+".ssc")
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


if __name__=="__main__":unittest.main()

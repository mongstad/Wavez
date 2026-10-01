import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from wavez_export import SceneCapture
from wavez_export.analysis import SourceSnapshot,AnalysisError
from wavez_export.analysis.derived import dispatch
from wavez_export.analysis.jobs import dispatch as query
from wavez_export.analysis.contracts import parse_float_token
from tests.test_picking import camera
from tools.extract_surface import ALGORITHM


class DerivedSelectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.path=self.root/"source.ssc"
        self.values=np.indices((2,2,2))[0].astype("f8")
        with SceneCapture(self.path,objects=[dict(id="grid",kind="volume",units="m")]) as writer:
            for t in [0.,1.]:writer.add_volume("grid",t,{"value":self.values},origin=[-1,-1,-1],spacing=[2,2,1])
        self.source=SourceSnapshot(self.path)
        self.provenance=dict(source_sha256=self.source.sha256,committed_bytes=str(self.source.committed_end),object="grid",channel="value",source_time=0.,
            geometry=self.source.samples["grid"][0]["descriptor"]["geometry"],data_to_world=self.source.objects["grid"]["data_to_world"],threshold=.5,algorithm=ALGORITHM,
            precision="source converted to float32 for Lewiner extraction; storage unchanged",invalid_policy="omit any cell with a nonfinite corner",smoothing=False,decimation=False)
        path=self.root/"artifact.ssc"
        self.z=float(np.float32(-.49999994))
        with SceneCapture(path,objects=[dict(id="isosurface",kind="mesh",identity="none",units="m",static=True)],metadata=dict(provenance=self.provenance)) as writer:
            writer.add_mesh("isosurface",0,np.array([[-1,-1,self.z],[1,-1,self.z],[0,1,self.z]],dtype="f4"),[[0,1,2]])
        self.ref=dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),signature=hashlib.sha256(json.dumps(self.provenance,sort_keys=True,separators=(",",":")).encode()).hexdigest())

    def tearDown(self):
        self.source.verify();self.source.close();self.assertEqual(self.source.context.used,0);self.tmp.cleanup()

    def inspect(self,mode="point",**kw):
        args=dict(object="grid",index=0,artifact=self.ref,mode=mode,camera=camera(),ray=dict(origin=[0,0,0],direction=[0,0,-1]));args.update(kw)
        return dispatch(self.source,args)["selection"]

    def test_artifact_point_keeps_approximation_and_cannot_follow_next_sample(self):
        definition=self.inspect()
        self.assertEqual(definition["kind"],"derived_surface");self.assertEqual(definition["time_policy"],"sample_local")
        self.assertTrue(definition["creation"]["approximate"])
        r=query(self.source,"resolve_selection",dict(selection=definition,time=0))
        self.assertEqual(r["status"],"approximate_artifact")
        self.assertEqual(parse_float_token(r["preview"][0]["position"][2]),self.z)
        r=query(self.source,"resolve_selection",dict(selection=definition,time=1))
        self.assertEqual((r["status"],r["present"]),("unavailable",0))
        self.assertEqual(r["reason"],"artifact_sample_changed")

    def test_explicit_probe_uses_original_grid_not_surface_threshold(self):
        definition=self.inspect("source_probe")
        self.assertEqual(definition["kind"],"probe");self.assertEqual(definition["time_policy"],"fixed_location")
        r=query(self.source,"probe",dict(object="grid",time=1,coordinate=definition["selector"]["coordinate"],channel="value"))
        self.assertEqual(r["value"]["value"],1+self.z)
        self.assertNotEqual(r["value"]["value"],.5)
        self.assertIn("artifact",definition["creation"])

    def test_whole_and_face_inspection_are_visual_only(self):
        for mode,count in [("object",3),("face",1)]:
            definition=self.inspect(mode)
            r=query(self.source,"resolve_selection",dict(selection=definition,time=0))
            self.assertEqual(len(r["preview"]),count)
            with self.assertRaisesRegex(AnalysisError,"cannot be frozen"):
                query(self.source,"freeze_selection",dict(selection=definition,time=0))

    def test_wrong_sample_hash_and_threshold_are_refused(self):
        with self.assertRaisesRegex(AnalysisError,"provenance"):self.inspect(index=1)
        with self.assertRaises(AnalysisError):self.inspect(artifact=dict(self.ref,sha256="0"*64))
        definition=self.inspect();definition["selector"]["threshold"]={"text":"1","f64_le_hex":"000000000000f03f"}
        with self.assertRaisesRegex(AnalysisError,"settings differ"):
            query(self.source,"resolve_selection",dict(selection=definition,time=0))

    @unittest.skipUnless(importlib.util.find_spec("skimage"),"Optional G3 extraction dependency unavailable")
    def test_actual_sphere_extraction_is_inspected_without_material_identity(self):
        from tools.extract_surface import extract
        path=self.root/"sphere.ssc"
        z,y,x=np.indices((12,12,12));field=(x-5.5)**2+(y-5.5)**2+(z-5.5)**2
        with SceneCapture(path,objects=[dict(id="grid",kind="volume",units="m")]) as writer:
            writer.add_volume("grid",0,{"value":field.astype("f8")},origin=[-5.5,-5.5,-5.5],spacing=[1,1,1])
        with SourceSnapshot(path) as source:
            extracted=extract(dict(source=str(path),extent=source.committed_end,sha256=source.sha256,object="grid",index=0,channel="value",threshold=9.,cache=str(self.root/"extracted")))
            ref={k:extracted[k] for k in ["path","sha256","signature"]}
            definition=dispatch(source,dict(object="grid",index=0,mode="object",artifact=ref))["selection"]
            r=query(source,"resolve_selection",dict(selection=definition,time=0,limit=8))
            self.assertLessEqual(len(r["preview"]),8);self.assertGreater(len(r["preview"]),0)
            self.assertEqual(r["status"],"approximate_artifact")


if __name__=="__main__":unittest.main()

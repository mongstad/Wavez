import hashlib
from pathlib import Path
import tempfile
import unittest
from decimal import Decimal
import numpy as np

from wavez_export import SceneCapture

from wavez_export.analysis import SourceSnapshot,Context,AnalysisError
from wavez_export.analysis.contracts import SharedBudget,MIB
from wavez_export.analysis import selectors as S
from wavez_export.analysis.native_analysis import run
from wavez_export.analysis.result_store import ResultCache
from tests.g4.fixtures import scene,HIGH_ID


class NativeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.path=scene(self.root/"capture.ssc");self.digest=hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.context=Context();self.source=SourceSnapshot(self.path,context=self.context)
        self.cache=ResultCache(self.root/"worker"/"results")
        self.ids=S.define(self.source,dict(object="p",kind="particle_ids",selector=dict(ids=["7",str(HIGH_ID),str(2**63-1)])))

    def tearDown(self):
        self.source.close();self.assertEqual(self.context.used,0)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest)
        self.tmp.cleanup()

    def analyze(self,definition=None,mode="trace",channels=None,**extra):
        args=dict(selections=[definition or self.ids],mode=mode,range=dict(axis="native_time",start=0,end=6),
                  channels=channels if channels is not None else [dict(channel="value")])|extra
        result=run(self.source,args,self.cache)
        page=self.cache.page(result["result"],context=self.context)
        return page["rows"],self.cache.manifest(result["result"],self.context),result["result"]

    def test_exact_ids_native_clocks_and_absence(self):
        rows,manifest,ref=self.analyze()
        self.assertEqual(len(rows),12)
        self.assertEqual([rows[i]["time"] for i in range(0,12,3)],["0","0.5","1.5","3"])
        high=[r for r in rows if r["entity_id"]==str(HIGH_ID)]
        self.assertEqual(high[-1]["reason"],"absent_at_sample")
        self.assertEqual(rows[2]["value"],"");self.assertEqual(rows[2]["reason"],"absent_at_sample")
        self.assertEqual(high[0]["source_dtype"],"f8");self.assertEqual(len(high[0]["value_f64_le_hex"]),16)
        support=self.cache.page(ref,kind="support",context=self.context)["rows"]
        self.assertEqual(support[0]["identity_audit"]["through_index"],3)
        self.assertEqual(next(iter(manifest["clocks"].values()))["time_units"],"s")

    def test_missing_channel_is_not_zero_count(self):
        rows,_,ref=self.analyze(mode="statistics",channels=[dict(channel="missing")],metrics=["count","mean"])
        self.assertTrue(all(r["value"]=="" and r["reason"]=="missing_channel" for r in rows))
        self.assertIsNone(self.cache.page(ref,kind="support",context=self.context)["rows"][0]["finite_count"])

    def test_statistics_and_population_own_native_samples(self):
        rows,_,_=self.analyze(mode="statistics",metrics=["count","mean","quantile:0.5"])
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="count"],["2","3","2","1"])
        rows,_,_=self.analyze(mode="population",channels=[])
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="selected"],["3"]*4)
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="present"],["2","3","2","1"])

    def test_interval_velocity_has_endpoints_midpoints_and_gap_refusal(self):
        rows,_,ref=self.analyze(mode="interval_velocity",channels=[],max_gap=1)
        high=[r for r in rows if r["entity_id"]==str(HIGH_ID) and r["component"]=="0"]
        self.assertEqual([r["time"] for r in high],["0.25","1","2.25"])
        self.assertEqual([r["value"] for r in high],["2","2",""])
        self.assertEqual(high[2]["reason"],"gap_exceeds_limit")
        support=self.cache.page(ref,kind="support",context=self.context)["rows"]
        self.assertEqual(support[0]["endpoint_indices"],[0,1])
        recorded,_,_=self.analyze(channels=[dict(channel="velocity",component=0)])
        self.assertEqual(recorded[0]["time_status"],"exact")
        self.assertEqual(recorded[0]["statistic"],"value")

    def test_grid_integral_and_declared_mass(self):
        region=S.define(self.source,dict(object="field",kind="roi",selector=dict(shape="box",lower=[-100]*3,upper=[100]*3)))
        rows,_,ref=self.analyze(region,mode="integral",channels=[dict(channel="constant",override=dict(units="kg/m^3"))])
        self.assertEqual([r["value"] for r in rows],["72"]*3)
        self.assertEqual([r["time"] for r in rows],["0","1","4"])
        support=self.cache.page(ref,kind="support",context=self.context)["rows"][0]
        self.assertEqual(support["effective_volume"],36);self.assertEqual(support["selected_cells"],6)
        with self.assertRaisesRegex(AnalysisError,"declared actual"):
            self.analyze(region,mode="integral",channels=[dict(channel="constant")],physical_mass=True)
        rows,_,_=self.analyze(region,mode="integral",physical_mass=True,channels=[dict(channel="constant",override=dict(quantity="mass_density",physical=dict(mass_unit="kg",length_unit="m",scale=2)))])
        self.assertEqual(rows[0]["value"],"144");self.assertEqual(rows[0]["units"],"kg")

    def test_mesh_face_expires_and_probe_keeps_native_clock(self):
        face=S.define(self.source,dict(object="mesh",kind="mesh_faces",association="face",selector=dict(index=0,rows=[0])))
        rows,_,_=self.analyze(face,channels=[dict(channel="face_value")])
        self.assertEqual([r["value"] for r in rows],["11","","",""])
        self.assertTrue(all(r["reason"]=="topology_changed" for r in rows[1:]))
        probe=S.define(self.source,dict(object="field",kind="probe",selector=dict(coordinate=[10.5,-2,6.5])))
        rows,_,_=self.analyze(probe)
        self.assertEqual([float(r["value"]) for r in rows],[13.75,14.75,17.75])
        self.assertTrue(all(r["value_status"]=="spatially_interpolated" for r in rows))

    def test_roi_is_dynamic_and_anonymous_trace_requires_freeze(self):
        region=S.define(self.source,dict(object="p",kind="roi",selector=dict(shape="box",lower=[-1,-1,-1],upper=[10,10,10])))
        rows,_,_=self.analyze(region,mode="population",channels=[])
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="matched"],["1","1","0","0"])
        with self.assertRaisesRegex(AnalysisError,"frozen"):
            self.analyze(region)

    def test_centroid_area_and_association(self):
        rows,_,_=self.analyze(mode="centroid",channels=[])
        self.assertEqual([float(r["value"]) for r in rows if r["component"]=="1"],[0,.5,1.5,3])
        face=S.define(self.source,dict(object="mesh",kind="mesh_object",association="face",selector={}))
        rows,_,_=self.analyze(face,mode="area",channels=[])
        self.assertEqual([float(r["value"]) for r in rows],[.5]*4)
        with self.assertRaisesRegex(AnalysisError,"association"):
            self.analyze(face,mode="statistics")

    def test_declared_phase_cannot_be_averaged_or_probe_blended(self):
        with self.assertRaisesRegex(AnalysisError,"not linear"):
            self.analyze(mode="statistics",channels=[dict(channel="particle_type")],metrics=["mean"])
        self.assertFalse(self.cache.active)
        self.assertEqual(list(self.cache.root.iterdir()),[])

    def test_native_weighted_statistics_and_grid_predicate(self):
        rows,_,ref=self.analyze(mode="statistics",metrics=["sum_weights","weighted_mean","weighted_quantile:0.5"],weight=dict(channel="value"))
        a=Decimal.from_float(7+1e-12);b=Decimal.from_float(HIGH_ID%101+1e-12)
        expected=float((a*a+b*b)/(a+b))
        self.assertAlmostEqual(float(rows[1]["value"]),expected,places=13)
        self.assertEqual(self.cache.page(ref,kind="support",context=self.context)["rows"][0]["paired_count"],2)
        grid=S.define(self.source,dict(object="field",kind="roi",selector=dict(shape="box",lower=[-100]*3,upper=[100]*3),predicate=[dict(channel="constant",op="range",lower=1,upper=3)]))
        rows,_,_=self.analyze(grid,mode="statistics",channels=[dict(channel="constant")],metrics=["count","mean"])
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="count"],["24"]*3)
        self.assertEqual([r["value"] for r in rows if r["statistic"]=="mean"],["2"]*3)

    def test_interval_velocity_cancels_large_affine_translation(self):
        path=self.root/"offset.ssc"
        with SceneCapture(path,objects=[dict(id="p",kind="mesh",identity="stable_topology",units="m",data_to_world=[2,0,0,1e18,0,1,0,0,0,0,1,0])],metadata=dict(time_unit="s")) as writer:
            for t in (0,1):writer.add_mesh("p",t,np.array([[float(t),0,0],[float(t),1,0],[float(t),0,1]],dtype="f8"),[[0,1,2]],vertex_channels=dict(vertex_id=np.array([7,8,9],dtype="i8"),velocity=np.tile([9.,0,0],(3,1))))
        with SourceSnapshot(path) as source:
            selected=S.define(source,dict(object="p",kind="mesh_vertices",selector=dict(ids=["7"])))
            args=dict(selections=[selected],mode="interval_velocity",range=dict(axis="native_time",start=0,end=1))
            result=run(source,args,self.cache)
        rows=self.cache.page(result["result"])["rows"]
        self.assertEqual([r["value"] for r in rows],["2","0","0"])

    def test_mesh_point_magnitude_follows_vector_interpolation(self):
        path=self.root/"vector.ssc"
        with SceneCapture(path,objects=[dict(id="mesh",kind="mesh",identity="none",static=True,units="m")]) as writer:
            writer.add_mesh("mesh",0,np.array([[0.,0,0],[1,0,0],[0,1,0]]),[[0,1,2]],vertex_channels=dict(velocity=np.array([[1.,0,0],[-1,0,0],[0,0,0]])))
        with SourceSnapshot(path) as source:
            point=S.define(source,dict(object="mesh",kind="mesh_point",selector=dict(index=0,face=0,barycentric=[.5,.5,0])))
            result=run(source,dict(selections=[point],mode="trace",range=dict(axis="native_time",start=0,end=0),channels=[dict(channel="velocity",component="magnitude")]),self.cache)
        self.assertEqual(self.cache.page(result["result"])["rows"][0]["value"],"0")

    def test_anonymous_temporal_identity_is_refused_and_bad_requests_abort(self):
        anonymous=S.define(self.source,dict(object="p",kind="sample_rows",selector=dict(index=0,rows=[0])))
        with self.assertRaisesRegex(AnalysisError,"no identity time trace"):self.analyze(anonymous)
        with self.assertRaisesRegex(AnalysisError,"Weights apply"):self.analyze(weight=dict(channel="value"))
        with self.assertRaisesRegex(AnalysisError,"not phase"):
            self.analyze(mode="statistics",weight=dict(channel="particle_type"),metrics=["weighted_mean"])
        self.assertFalse(self.cache.active)

    def test_cooperative_cursor_preserves_accumulator_and_shared_budget(self):
        pool=SharedBudget(128*MIB);background=Context(pool=pool);foreground=Context(pool=pool)
        seen=[]
        def cursor():
            with foreground.allocation(8*MIB):seen.append(pool.used)
        background.acquire(120*MIB);background.checkpoint=cursor
        background.check();self.assertEqual(seen,[128*MIB])
        with self.assertRaisesRegex(AnalysisError,"shared"):
            foreground.acquire(9*MIB)
        self.assertEqual(foreground.used,0)
        background.checkpoint=None;background.release(120*MIB);self.assertEqual(pool.used,0)
        baseline,_,_=self.analyze(mode="statistics",metrics=["sum"])
        checks=[]
        def inspect():
            checks.append(self.context.used)
            # Separate cursor work; the background stack/leases remain intact.
            other=Context(pool=pool)
            with SourceSnapshot(self.path,context=other) as source:
                with source.read_sample("p",0,["value"]) as sample:self.assertEqual(len(sample.arrays["value"]),2)
            self.assertEqual(other.used,0)
        self.context.checkpoint=inspect
        resumed,_,_=self.analyze(mode="statistics",metrics=["sum"])
        self.context.checkpoint=None
        self.assertGreater(len(checks),10)
        self.assertEqual([r["value"] for r in baseline],[r["value"] for r in resumed])


if __name__=="__main__":unittest.main()

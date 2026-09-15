import hashlib
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
import numpy as np

from simscope_export import SceneCapture
from simscope_export.analysis import AnalysisError,SourceSnapshot
from simscope_export.analysis.picking import dispatch,polygon_mask,triangle_hit,marker_mask
from simscope_export.analysis.contracts import parse_float_token


def camera():
    return dict(view=[1,0,0,0,0,1,0,0,0,0,1,0],
                projection=[1,0,0,0,0,1,0,0,0,0,-1,-.2,0,0,-1,0],
                viewport=[200,200],origin=[0,0,0],near=.1,far=100.,orthographic=False)


class PickingTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/"pick.ssc"
        with SceneCapture(self.path,objects=[dict(id="p",kind="particles",units="m",identity="persistent_i8"),
                         dict(id="mesh",kind="mesh",units="m",static=True,identity="none"),dict(id="grid",kind="volume",units="m")]) as w:
            w.add_particles("p",0,[[0.,0,-4],[0.,0,-2],[.5,0,-2],[0,0,2]],ids=[2**53+1,7,9,11],
                            opacity=np.array([1.,1.,0.,1.]),particle_type=np.array([0,1,0,0],dtype="u4"),
                            value=np.array([1.,2.,3.,4.]))
            w.add_mesh("mesh",0,[[-1.,-1,-1],[1.,-1,-1],[0,1,-1]],[[0,1,2]])
            w.add_volume("grid",0,{"value":np.ones((2,2,2))},origin=[-1,-1,-1],spacing=[2,2,1])
        self.hash=hashlib.sha256(self.path.read_bytes()).hexdigest();self.source=SourceSnapshot(self.path)

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.hash);self.tmp.cleanup()

    def pick(self,**kw):
        args=dict(object="p",mode="click",camera=camera(),time=0,point=[100,100]);args.update(kw)
        return dispatch(self.source,args)

    def test_click_positive_depth_then_exact_id(self):
        self.assertEqual(self.pick()["selection"]["selector"]["ids"],["7"])
        self.assertEqual(self.pick(style=dict(hidden_types=["1"]))["selection"]["selector"]["ids"],[str(2**53+1)])

    def test_rectangle_boundary_and_hidden_marker_excluded(self):
        result=self.pick(mode="polygon",polygon=[[99,99],[125,99],[125,101],[99,101]])
        self.assertEqual(result["selection"]["selector"]["ids"],["7",str(2**53+1)])
        np.testing.assert_array_equal(polygon_mask(np.array([[0,0],[1,0],[1,1],[2,2],[.2,.2]]),[[0,0],[1,0],[1,1],[0,1]]),[1,1,1,0,1])

    def test_lasso_is_not_its_bounding_rectangle(self):
        np.testing.assert_array_equal(polygon_mask(np.array([[.1,.1],[.9,.9],[.5,.5]]),[[0,0],[1,0],[0,1]]),[1,0,1])

    def test_visibility_and_clip_are_explicit(self):
        with self.assertRaisesRegex(AnalysisError,"visible target"):self.pick(style=dict(visible=False))
        result=self.pick(clip=dict(normal=[0,0,1],distance=-4,half_width=.1))
        self.assertEqual(result["selection"]["selector"]["ids"],[str(2**53+1)])

    def test_opaque_mesh_blocks_and_wireframe_does_not(self):
        with self.assertRaisesRegex(AnalysisError,"No eligible"):self.pick(occlusion="opaque",occluders=[dict(object="mesh",visible=True,wireframe=False)])
        self.assertEqual(self.pick(occlusion="opaque",occluders=[dict(object="mesh",visible=True,wireframe=True)])["selection"]["selector"]["ids"],["7"])

    def test_translucent_volume_is_not_an_opaque_blocker(self):
        entry=dict(object="grid",visible=True,slice=True,opacity=.99,channel="value",normal=[0,0,1],distance=-.5)
        self.assertEqual(self.pick(occlusion="opaque",occluders=[entry])["selection"]["selector"]["ids"],["7"])
        entry["opacity"]=1.
        with self.assertRaisesRegex(AnalysisError,"No eligible"):self.pick(occlusion="opaque",occluders=[entry])

    def test_mesh_source_face_and_barycentric_order(self):
        result=self.pick(object="mesh",mode="mesh_point",ray=dict(origin=[0,0,0],direction=[0,0,-1]))
        selector=result["selection"]["selector"]
        self.assertEqual(selector["face"],0)
        np.testing.assert_allclose([parse_float_token(v) for v in selector["barycentric"]],[.25,.25,.5],rtol=0,atol=1e-14)

    def test_backface_mode_is_explicit(self):
        positions=np.array([[-1.,-1,-1],[1.,-1,-1],[0,1,-1]])
        triangles=np.array([[0,2,1]])
        self.assertIsNone(triangle_hit(np.zeros(3),np.array([0,0,-1]),positions,triangles,backface="front"))
        self.assertIsNotNone(triangle_hit(np.zeros(3),np.array([0,0,-1]),positions,triangles,backface="both"))

    def test_reflection_preserves_source_front_and_barycentric_order(self):
        # G3 reverses render winding conditionally on transform determinant.
        original=np.array([[-1.,-1,-1],[1.,-1,-1],[0,1,-1]])
        reflected=original*np.array([-1.,1.,1.])
        hit=triangle_hit(np.zeros(3),np.array([0,0,-1]),reflected,np.array([[0,1,2]]),backface="front",orientation=-1.)
        self.assertIsNotNone(hit)
        np.testing.assert_allclose(hit[2],[.25,.25,.5],rtol=0,atol=1e-14)

    def test_volume_click_refuses_unspecified_depth_and_plane_probe_is_fixed(self):
        with self.assertRaisesRegex(AnalysisError,"plane/depth"):self.pick(object="grid")
        r=self.pick(object="grid",mode="probe",ray=dict(origin=[0,0,0],direction=[0,0,-1]),
                    plane=dict(normal=[0,0,1],distance=-.5,channel="value"))
        self.assertEqual(r["selection"]["time_policy"],"fixed_location")
        np.testing.assert_array_equal([parse_float_token(v) for v in r["selection"]["selector"]["coordinate"]],[0,0,-.5])

    def test_numeric_display_filter_freezes_source_cohort(self):
        r=self.pick(style=dict(color="value",color_bounds=[1,1.5],clamp=False))
        self.assertEqual(r["selection"]["selector"]["ids"],[str(2**53+1)])
        self.assertEqual(r["selection"]["predicate"],[])
        self.assertIn("style",r["selection"]["creation"]["query"])

    def test_face_and_probe_respect_camera_depth_and_opaque_policy(self):
        ray=dict(origin=[0,0,0],direction=[0,0,-1])
        cam=camera();cam["near"]=1.1
        with self.assertRaisesRegex(AnalysisError,"No source triangle"):
            self.pick(object="mesh",mode="mesh_face",ray=ray,camera=cam)
        cam=camera();cam["far"]=.4
        with self.assertRaisesRegex(AnalysisError,"depth bounds"):
            self.pick(object="grid",mode="probe",ray=ray,camera=cam,plane=dict(normal=[0,0,1],distance=-.5,channel="value"))
        blocker=dict(object="grid",visible=True,slice=True,opacity=1.,channel="value",normal=[0,0,1],distance=-.5)
        with self.assertRaisesRegex(AnalysisError,"opaque geometry"):
            self.pick(object="mesh",mode="mesh_face",ray=ray,occlusion="opaque",occluders=[blocker])
        # A mesh hit does not occlude itself, and geometry before near is clipped.
        self.pick(object="mesh",mode="mesh_face",ray=ray,occlusion="opaque",occluders=[dict(object="mesh",visible=True)])
        cam=camera();cam["near"]=1.1
        self.assertEqual(self.pick(camera=cam,occlusion="opaque",occluders=[dict(object="mesh",visible=True)])["selection"]["selector"]["ids"],["7"])

    def test_face_predicate_missing_operand_is_not_silently_ignored(self):
        with self.assertRaisesRegex(AnalysisError,"No source triangle"):
            self.pick(object="mesh",mode="mesh_face",ray=dict(origin=[0,0,0],direction=[0,0,-1]),predicate=[dict(channel="missing",op="finite")])

    def test_display_only_pack_limits_and_missing_channel_fallback(self):
        samples=SimpleNamespace(arrays=dict(visual_size=np.array([1.,1e-100,1e100,np.nan]),value=np.array([1e100]*4)))
        np.testing.assert_array_equal(marker_mask(samples,dict(size="visual_size"),4),[1,0,0,0])
        np.testing.assert_array_equal(marker_mask(samples,dict(brightness="value"),4),[0,0,0,0])
        np.testing.assert_array_equal(marker_mask(samples,dict(color="absent"),4),[1,1,1,1])
        samples.arrays=dict(visual_color=np.array([[1,1,1,1],[1e100,1,1,1],[1,1,1,1e-100],[0,0,0,1]],dtype="f8"))
        np.testing.assert_array_equal(marker_mask(samples,dict(color="visual_color"),4),[1,0,0,0])

    def test_combined_float32_style_underflow_is_not_pickable(self):
        sample=SimpleNamespace(arrays=dict(visual_color=np.array([[1e-30,1e-30,1e-30,1],[1,1,1,1e-30],[1,1,1,1.]],dtype='f8'),visual_brightness=np.array([1e-30,1,1.]),opacity=np.array([1,1e-30,1.])))
        np.testing.assert_array_equal(marker_mask(sample,dict(color='visual_color',brightness='visual_brightness'),3),[False,False,True])
        # This is solely display eligibility; none of the exact source values change.
        self.assertEqual(sample.arrays['visual_color'][0,0],1e-30)

    def test_anonymous_pick_is_sample_local_without_inferred_identity(self):
        path=Path(self.tmp.name)/"anonymous.ssc"
        with SceneCapture(path,objects=[dict(id="particles",kind="particles",units="u",identity="anonymous")]) as writer:
            for t in [0.,1.]:writer.add_particles("particles",t,np.array([[0,0,-2],[1,0,-2]],dtype="f4"))
        with SourceSnapshot(path) as source:
            result=dispatch(source,dict(object="particles",mode="click",camera=camera(),index=1,point=[100,100]))
            d=result["selection"]
            self.assertEqual(d["kind"],"sample_rows");self.assertEqual(d["selector"],dict(index=1,rows=[0]))
            self.assertEqual(d["time_policy"],"sample_local")
            # Defensive index-only sampling must never invent physical-time validity.
            source.samples["particles"][1]["time"]=0.
            result=dispatch(source,dict(object="particles",mode="click",camera=camera(),index=1,point=[100,100]))
            self.assertEqual(result["sampling"]["status"],"index_only")
            with self.assertRaises(AnalysisError):dispatch(source,dict(object="particles",mode="click",camera=camera(),time=0,point=[100,100]))


if __name__=="__main__":unittest.main()

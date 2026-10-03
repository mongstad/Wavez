import hashlib
from pathlib import Path
import tempfile
import unittest

import numpy as np

from wavez_export import SceneCapture
from wavez_export.analysis import AnalysisError,Context,SourceSnapshot
from wavez_export.analysis.contracts import parse_float_token
from wavez_export.analysis import selectors as S
from wavez_export.analysis.selection_jobs import dispatch
from tests.g4.fixtures import scene,HIGH_ID


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.path=scene(self.root/"scene.wvz");self.digest=hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.source=SourceSnapshot(self.path)

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest)
        self.temp.cleanup()

    def definition(self,kind,selector,object="p",**kw):
        return S.define(self.source,dict(kind=kind,selector=selector,object=object,**kw))

    def resolve(self,definition,time=0,**kw):
        return dispatch(self.source,"resolve_selection",dict(selection=definition,time=time,**kw))

    def test_ids_are_exact_deduplicated_and_seek_independent(self):
        d=self.definition("particle_ids",dict(ids=[str(HIGH_ID),"7","7"]))
        self.assertEqual(d["selector"]["ids"],["7",str(HIGH_ID)])
        for t,n in [(3,0),(.5,2),(1.5,1),(0,2),(4,0)]:
            r=self.resolve(d,t);self.assertEqual(r["selected"],2);self.assertEqual(r["present"],n)
        self.assertEqual(d["selector"]["ids"],["7",str(HIGH_ID)])
        with self.assertRaises(AnalysisError):self.definition("particle_ids",dict(ids=[HIGH_ID]))

    def test_marker_interpolation_and_unmatched_hold(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]))
        r=self.resolve(d,1.)
        rows={v["id"]:v for v in r["preview"]}
        self.assertEqual(rows["7"]["position_status"],"held_unmatched")
        self.assertEqual(parse_float_token(rows["7"]["position"][0]),8.)
        self.assertEqual(rows[str(HIGH_ID)]["position_status"],"interpolated_by_id")

    def test_rows_are_local_even_when_counts_match(self):
        d=self.definition("sample_rows",dict(index=0,rows=[1]))
        self.assertEqual(self.resolve(d,.1)["present"],1)
        self.assertEqual(self.resolve(d,.5)["reason"],"sample_local")
        self.assertEqual(self.resolve(d,0)["present"],1)

    def test_anonymous_roi_freezes_rows_not_identity(self):
        path=self.root/"anonymous.wvz"
        with SceneCapture(path,objects=[dict(id="p",kind="particles",units="m",identity="anonymous")]) as w:
            w.add_particles("p",0,[[0.,0,0],[2.,0,0]])
            w.add_particles("p",1,[[2.,0,0],[0.,0,0]])
        with SourceSnapshot(path) as s:
            with self.assertRaisesRegex(AnalysisError,"declared"):S.define(s,dict(kind="particle_ids",selector=dict(ids=["0"]),object="p"))
            d=S.define(s,dict(kind="roi",selector=dict(shape="sphere",center=[0,0,0],radius=1),object="p"))
            frozen=dispatch(s,"freeze_selection",dict(selection=d,time=0))["selection"]
            self.assertEqual(frozen["kind"],"sample_rows");self.assertEqual(frozen["selector"]["rows"],[0])
            self.assertEqual(dispatch(s,"resolve_selection",dict(selection=frozen,time=1))["reason"],"sample_local")

    def test_roi_shapes_boundaries_and_finite_support(self):
        points=np.array([[0,0,0],[1,0,0],[1.01,0,0],[0,0,1],[0,0,1.01],[np.nan,0,0]])
        for definition,expected in [
            (dict(shape="box",lower=[-1,-1,-1],upper=[1,1,1]),[1,1,0,1,0,0]),
            (dict(shape="sphere",center=[0,0,0],radius=1),[1,1,0,1,0,0]),
            (dict(shape="cylinder",start=[0,0,-1],end=[0,0,1],radius=1),[1,1,0,1,0,0]),
            (dict(shape="slab",center=[0,0,0],normal=[0,0,1],tangent=[1,0,0],width=2,height=2,thickness=2),[1,1,0,1,0,0])]:
            np.testing.assert_array_equal(S.inside(points,S.region(definition)),np.array(expected,dtype=bool))
        with self.assertRaises(AnalysisError):S.region(dict(shape="cylinder",start=[0,0,0],end=[0,0,0],radius=1))
        with self.assertRaises(AnalysisError):S.region(dict(shape="slab",center=[0,0,0],normal=[0,0,1],tangent=[0,0,1],width=2,height=2,thickness=2))

    def test_cohort_freeze_remains_distinct_from_region(self):
        d=self.definition("roi",dict(shape="box",lower=[6,-1,-1],upper=[8,.5,1]))
        frozen=dispatch(self.source,"freeze_selection",dict(selection=d,time=0))["selection"]
        self.assertEqual(frozen["selector"]["ids"],["7"])
        self.assertEqual(self.resolve(d,1)["matched"],1) # held source scalar/membership at .5
        self.assertEqual(self.resolve(d,1.5)["matched"],0)
        self.assertEqual(self.resolve(frozen,.5)["present"],1)

    def test_integer_filter_never_rounds_large_ids(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]),predicate=[dict(channel="particle_id",op="range",lower=str(HIGH_ID),upper=str(HIGH_ID))])
        self.assertEqual([v["id"] for v in self.resolve(d)["preview"]],[str(HIGH_ID)])
        bad=self.definition("particle_ids",dict(ids=["7"]),predicate=[dict(channel="particle_id",op="range",lower=0.,upper=1e18)])
        with self.assertRaises(AnalysisError):self.resolve(bad)

    def test_missing_predicate_excludes_unknown(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]),predicate=[dict(channel="not_recorded",op="finite")])
        r=self.resolve(d);self.assertEqual((r["selected"],r["present"],r["matched"],r["unknown"]),(2,2,0,2))

    def test_mesh_faces_never_resurrect(self):
        d=self.definition("mesh_faces",dict(index=0,rows=[0]),object="mesh")
        self.assertEqual(self.resolve(d,1)["present"],1)
        for t in [2,4,6]:self.assertEqual(self.resolve(d,t)["reason"],"topology_changed")
        self.assertEqual(self.resolve(d,0)["present"],1)

    def test_mesh_vertex_id_survives_face_topology_change(self):
        d=self.definition("mesh_vertices",dict(ids=[str(HIGH_ID)]),object="mesh")
        for t in [0,2,4,6]:self.assertEqual(self.resolve(d,t)["present"],1)

    def test_mesh_point_preserves_source_barycentric_order(self):
        d=self.definition("mesh_point",dict(index=0,face=0,barycentric=[.25,.25,.5]),object="mesh")
        pos=[parse_float_token(v) for v in self.resolve(d)["preview"][0]["position"]]
        np.testing.assert_array_equal(pos,[.25,.5,0.])
        self.assertEqual(self.resolve(d,4)["reason"],"topology_changed")

    def test_grid_xyz_and_transform_once(self):
        d=self.definition("grid_samples",dict(index=0,xyz=[[1,2,1]]),object="field")
        r=self.resolve(d,1)
        self.assertEqual(r["preview"][0]["row"],21)
        np.testing.assert_array_equal([parse_float_token(v) for v in r["preview"][0]["position"]],[11,1,8])
        with self.assertRaises(AnalysisError):self.definition("grid_samples",dict(index=0,xyz=[[4,2,1]]),object="field")

    def test_probe_local_and_world_placement(self):
        d=self.definition("probe",dict(coordinate=[.25,1,1.5]),object="field",coordinates=dict(space="data_local",units="m"))
        np.testing.assert_array_equal([parse_float_token(v) for v in self.resolve(d)["preview"][0]["position"]],[10.5,-2,6.5])

    def test_roi_grid_selects_source_nodes_independent_of_display(self):
        d=self.definition("roi",dict(shape="box",lower=[9,-4,4],upper=[11,-1,8]),object="field")
        self.assertEqual(self.resolve(d)["matched"],8) # world x10/11, y-3/-1, z5/8: 2*2*2

    def test_overlap_deduplicated_and_mixed_object_group_refused(self):
        a=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]),key="a")
        b=self.definition("particle_ids",dict(ids=["7"]),key="b")
        for op,expected in [("union",2),("intersection",1)]:
            r=dispatch(self.source,"combine_selections",dict(selection=a,other=[b],operation=op,time=0))
            self.assertEqual(r["selected"],expected)
        c=self.definition("mesh_vertices",dict(ids=["7"]),object="mesh")
        with self.assertRaisesRegex(AnalysisError,"Mixed"):dispatch(self.source,"combine_selections",dict(selection=a,other=[c],operation="union",time=0))

    def test_source_scope_and_unknown_policy_fail_before_mutation(self):
        d=self.definition("particle_ids",dict(ids=["7"]))
        d["source"]["sha256"]="0"*64
        with self.assertRaisesRegex(AnalysisError,"different committed"):self.resolve(d)
        d=self.definition("sample_rows",dict(index=0,rows=[0]));d["time_policy"]="fixed_cohort"
        with self.assertRaises(AnalysisError):self.resolve(d)

    def test_preview_thinning_does_not_change_cohort(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]))
        r=self.resolve(d,limit=1)
        self.assertEqual(r["selected"],2);self.assertEqual(len(r["preview"]),1)
        self.assertTrue(r["preview_policy"]["thinned"]);self.assertEqual(len(r["selection"]["selector"]["ids"]),2)

    def test_derived_artifact_is_not_a_material_selection(self):
        d=self.definition("derived_surface",dict(index=0,artifact_sha256="1"*64,threshold=1.,algorithm="test/source-f32"),object="field")
        self.assertEqual(self.resolve(d)["status"],"unavailable")
        self.assertEqual(self.resolve(d)["reason"],"artifact_reference_missing")

    def test_visual_filter_does_not_change_scientific_counts(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]))
        r=self.resolve(d,style=dict(hidden_types=["1"]))
        self.assertEqual((r["selected"],r["present"],r["matched"]),(2,2,2))
        self.assertEqual(r["display_eligible"],1)
        self.assertEqual(r["preview"][0]["id"],str(HIGH_ID))

    def test_group_union_resolves_each_members_own_channel_predicate(self):
        a=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]),predicate=[dict(channel="particle_type",op="in",values=["1"])])
        b=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]),predicate=[dict(channel="value",op="finite")])
        r=dispatch(self.source,"combine_selections",dict(selection=a,other=[b],time=0,operation="union"))
        self.assertEqual(r["selection"]["selector"]["ids"],["7",str(HIGH_ID)])

    def test_bounded_structural_json_numbers_and_set_edits(self):
        a=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]))
        b=self.definition("particle_ids",dict(ids=["7",str(2**63-1)]))
        a["revision"]=1.0 # Godot JSON parser representation, never an ID.
        for mode,expected in [("replace",[7,2**63-1]),("add",[7,HIGH_ID,2**63-1]),("subtract",[HIGH_ID]),("toggle",[HIGH_ID,2**63-1])]:
            result=dispatch(self.source,"edit_selection",dict(selection=a,incoming=b,mode=mode))
            self.assertEqual(result["selector"]["ids"],[str(i) for i in expected])
            self.assertEqual(result["revision"],2)
        a["revision"]=1.5
        with self.assertRaises(AnalysisError):S.validate(self.source,a)

    def test_selection_count_survives_before_layer_start(self):
        d=self.definition("particle_ids",dict(ids=["7",str(HIGH_ID)]))
        r=self.resolve(d,-1)
        self.assertEqual((r["selected"],r["present"]),(2,0))
        self.assertEqual(r["reason"],"before_first_sample")

    def test_slab_roundtrip_never_renormalizes_saved_scientific_basis(self):
        d=self.definition("roi",dict(shape="slab",center=[.1,.2,.3],normal=[1.,2.,3.],tangent=[-3.,0,1.],width=5,height=6,thickness=2))
        expected=d["selector"]
        for _ in range(20):
            d=S.validate(self.source,d)
            self.assertEqual(d["selector"],expected)

    def test_component_survives_godot_structural_json_representation(self):
        d=self.definition("particle_ids",dict(ids=["7"]),predicate=[dict(channel="velocity",component=1.0,op="range",lower=.9,upper=1.1)])
        self.assertEqual(self.resolve(d)["matched"],1)


if __name__=="__main__":unittest.main()

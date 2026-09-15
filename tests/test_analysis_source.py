import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest

import numpy as np

from simscope_export import SceneCapture, SceneReader
from simscope_export.analysis import AnalysisError, Cancelled, Context, SourceSnapshot
from simscope_export.analysis.contracts import MIB, exact_id, float_token, parse_float_token
from simscope_export.analysis.sampling import bracket, epoch, interpolated_positions, match_rows, mesh_compatible, probe_array, source_bracket, valid_axis
from tests.g4.fixtures import scene, HIGH_ID
from tests.scene_mutation import rewrite, set_ids


class SourceFoundationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.path = scene(self.root/"fixture.ssc")
        self.before = hashlib.sha256(self.path.read_bytes()).hexdigest()

    def tearDown(self):
        if self.path.exists() and self._testMethodName not in {"test_replacement_and_mutation", "test_prefix_truncation", "test_corruption_and_selective_read"}:
            self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), self.before)
        self.temp.cleanup()

    def test_native_clock_and_exact_statuses(self):
        with SourceSnapshot(self.path) as source:
            self.assertEqual([r["time"] for r in source.samples["p"]], [0,.5,1.5,3])
            self.assertEqual([r["time"] for r in source.samples["field"]], [0,1,4])
            self.assertEqual(source_bracket(source,"p",.75)["a"], 1)
            self.assertEqual(source_bracket(source,"field",.75)["a"], 0)
            self.assertEqual(source_bracket(source,"p",.5)["a"], source_bracket(source,"p",.5)["b"])
            self.assertEqual(source_bracket(source,"p",-.1)["reason"], "before_first_sample")
            held = source_bracket(source,"p",4)
            self.assertEqual((held["a"],held["b"],held["status"]), (3,3,"held"))

    def test_typed_precision_and_immutable_leases(self):
        context = Context()
        with SourceSnapshot(self.path, context=context) as source:
            baseline = context.used
            with source.read_sample("p",0,["value"]) as sample:
                self.assertEqual(set(sample.arrays), {"particle_id","value"})
                self.assertEqual(sample.arrays["value"].dtype, np.dtype("f8"))
                self.assertNotEqual(sample.arrays["value"][0], np.float32(sample.arrays["value"][0]))
                self.assertEqual(int(sample.arrays["particle_id"][1]), HIGH_ID)
                with self.assertRaises(ValueError):sample.arrays["value"].flags.writeable = True
            self.assertEqual(context.used, baseline)
        self.assertEqual(context.used,0)

    def test_birth_death_and_reorder_source_positions(self):
        with SourceSnapshot(self.path) as source:
            with source.read_sample("p",0,["position","value"]) as a, source.read_sample("p",1,["position"]) as b:
                pos,status = interpolated_positions(source.objects["p"],a.arrays,b.arrays,.5)
                np.testing.assert_array_equal(pos[:,0], a.arrays["position"][:,0]+.5)
                self.assertEqual(len(pos),2)  # b-only birth is not active.
                self.assertTrue(all(status=="interpolated_by_id"))
            with source.read_sample("p",1,["position"]) as a, source.read_sample("p",2,["position"]) as b:
                pos,status = interpolated_positions(source.objects["p"],a.arrays,b.arrays,.25)
                self.assertEqual(status[1],"held_unmatched")
                np.testing.assert_array_equal(pos[1], a.arrays["position"][1])
            self.assertEqual(source.audit_identity("p")["distinct_ids"],3)

    def test_exact_lookup_extremes(self):
        a=np.array([0,2**24+1,HIGH_ID,2**63-1],dtype="i8")
        np.testing.assert_array_equal(match_rows(a,a[::-1]),[3,2,1,0])
        np.testing.assert_array_equal(match_rows(a,np.empty(0,dtype="i8")),[-1]*4)
        for value in a:self.assertEqual(exact_id(str(value)),value)
        for bad in [HIGH_ID, float(HIGH_ID), "01", "-1", str(2**63),True]:
            with self.assertRaises(AnalysisError):exact_id(bad)

    def test_f64_tokens_roundtrip(self):
        for value in [.1, .10000000000000003, -0., 1e20+16384]:
            token=float_token(value)
            self.assertEqual(struct.pack("<d",value),struct.pack("<d",parse_float_token(json.loads(json.dumps(token)))))
        with self.assertRaises(AnalysisError):parse_float_token({"text":"0.1","f64_le_hex":float_token(.1)["f64_le_hex"]})

    def test_mesh_epochs_do_not_resurrect(self):
        with SourceSnapshot(self.path) as source:
            self.assertEqual([epoch(source,"mesh",i)["first_index"] for i in (0,1,2,3)], [0,1,2,2])
            with source.read_sample("mesh",0) as a, source.read_sample("mesh",1) as b:
                self.assertFalse(mesh_compatible(source.objects["mesh"],a.arrays,b.arrays))
            with source.read_sample("mesh",2) as a, source.read_sample("mesh",3) as b:
                self.assertTrue(mesh_compatible(source.objects["mesh"],a.arrays,b.arrays))
                self.assertEqual(a.descriptors["face_value"]["association"],"face")

    def test_float64_probe_matches_independent_linear_field(self):
        with SourceSnapshot(self.path) as source:
            with source.read_sample("field",0,["value"]) as sample:
                # local (.25,1,1.5); world affine (10.5,-2,6.5)
                result=probe_array(sample.arrays["value"],sample.record["descriptor"]["geometry"],source.objects["field"]["data_to_world"],[10.5,-2,6.5])
                self.assertAlmostEqual(result["value"],.25+2*1+3*1.5+7,places=12)
                self.assertEqual(probe_array(sample.arrays["value"],sample.record["descriptor"]["geometry"],source.objects["field"]["data_to_world"],[0,0,0])["reason"],"out_of_domain")

    def test_g3_probe_invalid_corner_and_cell_edge(self):
        g=dict(origin=[0,0,0],spacing=[1,2,3],centering="cell")
        transform=[1,0,0,0,0,1,0,0,0,0,1,0]
        a=np.full((2,3,4),2.,dtype="f8")
        self.assertEqual(probe_array(a,g,transform,[-.5,-1,-1.5])["value"],2)
        self.assertEqual(probe_array(a,g,transform,[-.5001,-1,-1.5])["reason"],"out_of_domain")
        a[1,1,1]=np.nan
        self.assertEqual(probe_array(a,g,transform,[0,0,0])["reason"],"nonfinite_support")

    def test_none_zstd_and_existing_reader_parity(self):
        compressed=scene(self.root/"compressed.ssc","zstd")
        for path in [self.path,compressed]:
            with SourceSnapshot(path) as s, SceneReader(path) as old:
                for oid in s.objects:
                    for i in range(len(s.samples[oid])):
                        with s.read_sample(oid,i) as result:
                            expected=old.read_sample(oid,i)
                            self.assertEqual(set(expected),set(result.arrays))
                            for key,a in expected.items():self.assertEqual(a.tobytes(),result.arrays[key].tobytes())

    def test_prefix_ignores_future_records_and_uncommitted_tail(self):
        with SourceSnapshot(self.path) as all_source:
            end=all_source.samples["p"][1]["end"]
        digest=hashlib.sha256(self.path.read_bytes()[:end]).hexdigest()
        with SourceSnapshot(self.path,committed_bytes=str(end),sha256=digest) as s:
            self.assertEqual(len(s.samples["p"]),2)
            self.assertEqual(len(s.samples["field"]),1)
            self.assertEqual(source_bracket(s,"p",4)["a"],1)
        partial=self.root/"partial.ssc"
        partial.write_bytes(self.path.read_bytes()[:end+25])
        with SourceSnapshot(partial) as s:self.assertEqual(s.committed_end,end)
        with self.assertRaises(ValueError):SourceSnapshot(partial,committed_bytes=str(end+25))

    def test_append_is_verified_but_never_extends(self):
        live=self.root/"live.ssc"
        with SourceSnapshot(self.path) as source:end=source.samples["p"][1]["end"]
        live.write_bytes(self.path.read_bytes()[:end])
        with SourceSnapshot(live) as s:
            with live.open("ab") as out:out.write(self.path.read_bytes()[end:])
            with s.read_sample("p",1,["value"]) as sample:self.assertEqual(sample.record["time"],.5)
            self.assertEqual(len(s.samples["p"]),2)
            self.assertEqual(s.committed_end,end)

    def test_replacement_and_mutation(self):
        for replacement in (False,True):
            with SourceSnapshot(self.path) as s:
                raw=self.path.read_bytes()
                if replacement:
                    q=self.root/"replace";q.write_bytes(raw);os.replace(q,self.path)
                else:
                    with self.path.open("r+b") as out:out.seek(-1,2);out.write(bytes([raw[-1]^1]))
                with self.assertRaises(AnalysisError):s.verify()
            self.path.write_bytes(raw)

    def test_prefix_truncation(self):
        with SourceSnapshot(self.path) as s:
            self.path.write_bytes(self.path.read_bytes()[:-1])
            with self.assertRaises(AnalysisError):s.read_sample("p",0)

    def test_corruption_and_selective_read(self):
        with SourceSnapshot(self.path) as s:
            r=s.samples["p"][0]
            desc=next(a for a in r["descriptor"]["arrays"] if a["name"]=="velocity")
            offset=r["offset"]+int(desc["chunks"][0]["offset"])
        with self.path.open("r+b") as out:out.seek(offset);out.write(b"\xff")
        with SourceSnapshot(self.path) as s:
            with s.read_sample("p",0,["value"]) as result:self.assertNotIn("velocity",result.arrays)
            with self.assertRaisesRegex(ValueError,"checksum"):s.read_sample("p",0)

    def test_external_identity_reuse_is_not_certified_by_seek(self):
        p=self.root/"invalid.ssc"
        with SceneCapture(p,objects=[dict(id="particles",kind="particles",units="u",identity="persistent_i8")]) as w:
            for i,ids in enumerate([[5,10],[10,11],[11,12]]):w.add_particles("particles",i,np.zeros((2,3),dtype="f8"),ids=ids)
        rewrite(p,lambda seq,r,d,payload:set_ids(seq,r,d,payload,[11,5]) if seq==2 else None)
        with SourceSnapshot(p) as s:
            with s.read_sample("particles",2) as result:self.assertEqual(result.arrays["particle_id"][1],5)
            self.assertEqual(s.audit_coverage,{})
            with self.assertRaises(AnalysisError) as error:s.audit_identity("particles")
            self.assertEqual(error.exception.code,"identity_contract_violation")

    def test_memory_and_cancel_failure_release(self):
        ctx=Context(memory_bytes=2*MIB)
        with SourceSnapshot(self.path,context=ctx) as s:
            before=ctx.used
            with self.assertRaises(AnalysisError):s.read_sample("field",0)
            self.assertEqual(ctx.used,before)
        self.assertEqual(ctx.used,0)
        counter=[0]
        def cancel():
            counter[0]+=1
            return counter[0]>8
        ctx=Context(cancelled=cancel)
        with self.assertRaises(Cancelled):SourceSnapshot(self.path,context=ctx)
        self.assertEqual(ctx.used,0)

    def test_anonymous_source_without_inferred_identity(self):
        p=self.root/"anonymous.ssc"
        with SceneCapture(p,objects=[dict(id="particles",kind="particles",units="u",identity="anonymous")]) as w:
            for t in [0,1,2]:w.add_particles("particles",t,np.array([[t,2,3]],dtype="f4"))
        with SourceSnapshot(p) as s,SceneReader(p) as reader:
            self.assertEqual(s.objects["particles"]["identity"],"anonymous")
            for i in [2,0,1]:
                with s.read_sample("particles",i,["position"]) as result:
                    np.testing.assert_array_equal(result.arrays["position"],reader.read_sample("particles",i)["position"])
        self.assertFalse(valid_axis([{"time":0},{"time":0},{"time":1}]))
        with self.assertRaises(AnalysisError):bracket([{"time":1},{"time":0}],.5)

    def test_empty_formats_and_static_before_timestamp(self):
        p=self.root/"empty.ssc"
        with SceneCapture(p,objects=[dict(id="particles",kind="particles",units="u",identity="anonymous")]):pass
        with SourceSnapshot(p) as s:self.assertEqual(s.record_count,0)
        static=bracket([{"time":5}],-10,static=True)
        self.assertEqual((static["a"],static["status"]),(0,"static"))
        self.assertEqual(bracket([],0)["reason"],"no_samples")


if __name__ == "__main__":
    unittest.main()

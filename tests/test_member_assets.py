import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

import numpy as np

from wavez_export import SceneCapture
from wavez_export.analysis import SourceSnapshot,Context,AnalysisError
from wavez_export.analysis.member_assets import MemberAssets
from wavez_export.analysis.selection_jobs import dispatch
from wavez_export.analysis import selectors as S


class MemberAssetTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.path=self.root/"source.ssc"
        self.ids=np.arange(4096,dtype="i8")+2**53+1;self.ids[-1]=2**63-1
        positions=np.column_stack((np.arange(len(self.ids))*.001,np.zeros((len(self.ids),2))))
        with SceneCapture(self.path,objects=[dict(id="p",kind="particles",units="m",identity="persistent_i8")]) as writer:
            writer.add_particles("p",0,positions,ids=self.ids)
            writer.add_particles("p",1,positions[::-1]+[1.,0,0],ids=self.ids[::-1])
        self.digest=hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.store=MemberAssets(self.root/"members")

    def tearDown(self):
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest)
        self.tmp.cleanup()

    def freeze(self,source):
        roi=S.define(source,dict(object="p",kind="roi",selector=dict(shape="box",lower=[-1,-1,-1],upper=[10,1,1])))
        return dispatch(source,"freeze_selection",dict(selection=roi,time=0))["selection"]

    def test_large_freeze_is_compact_and_preserves_exact_ids_after_reorder(self):
        context=Context()
        with SourceSnapshot(self.path,context=context,assets=self.store) as source:
            definition=self.freeze(source)
            self.assertNotIn("ids",definition["selector"])
            ref=definition["selector"]["ids_asset"]
            self.assertLess(len(json.dumps(definition)),4096)
            np.testing.assert_array_equal(source.member_array(ref),self.ids)
            with self.assertRaises(ValueError):source.member_array(ref).flags.writeable=True
            result=dispatch(source,"resolve_selection",dict(selection=definition,time=1,limit=4))
            self.assertEqual((result["selected"],result["present"]),(4096,4096))
            self.assertEqual(result["preview"][0]["id"],str(2**63-1))
            self.assertTrue(result["preview_policy"]["thinned"])
        self.assertEqual(context.used,0)
        self.assertEqual(self.store.used,4096*8)

    def test_asset_set_edits_stay_exact_and_deduplicate_storage(self):
        with SourceSnapshot(self.path,assets=self.store) as source:
            definition=self.freeze(source)
            same=self.freeze(source)
            self.assertEqual(same["selector"],definition["selector"]);self.assertEqual(self.store.count,1)
            incoming=S.define(source,dict(object="p",kind="particle_ids",selector=dict(ids=[str(2**63-1)])))
            changed=dispatch(source,"edit_selection",dict(selection=definition,incoming=incoming,mode="subtract"))
            self.assertEqual(S.member_count(changed["selector"],"ids"),4095)
            self.assertNotIn(2**63-1,source.member_array(changed["selector"]["ids_asset"]))
            toggled=dispatch(source,"edit_selection",dict(selection=changed,incoming=incoming,mode="add"))
            self.assertEqual(toggled["selector"],definition["selector"])

    def test_live_reference_collection_and_cancelled_temporary_cleanup(self):
        context=Context()
        a=self.store.put(np.arange(128,dtype="i8"),context)
        b=self.store.put(np.arange(129,dtype="i8"),context)
        self.store.set_owner(os.getpid())
        self.assertEqual(self.store.collect([b],context),1)
        self.assertFalse(self.store.path(a)[0].exists());self.assertTrue(self.store.path(b)[0].exists())
        self.assertTrue((self.store.root/"owner.json").exists())
        # An interrupted staging file is counted on restart and reclaimed.
        (self.store.root/"member-interrupted.part").write_bytes(b"incomplete")
        reopened=MemberAssets(self.store.root);self.assertEqual(reopened.collect([b],context),1)
        self.assertEqual(reopened.used,129*8)

    def test_abandoned_owned_cache_reaped_but_live_and_unknown_kept(self):
        context=Context();registry=self.root/"registry"
        dead=MemberAssets(registry/"dead"/"members");live=MemberAssets(registry/"live"/"members")
        unknown=MemberAssets(registry/"unknown"/"members")
        for store in [dead,live,unknown]:store.put(np.arange(128,dtype="i8"),context)
        dead.set_owner(os.getpid());live.set_owner(os.getpid())
        owner=json.loads((dead.root/"owner.json").read_text());owner["birth"]="different-start-time"
        (dead.root/"owner.json").write_text(json.dumps(owner))
        self.assertEqual(MemberAssets.reap_abandoned(registry,context),2)
        self.assertFalse(dead.root.exists());self.assertTrue(live.root.exists());self.assertTrue(unknown.root.exists())

    def test_request_collects_only_unpinned_assets_and_keeps_incoming_definition(self):
        from wavez_export.analysis.jobs import execute
        with SourceSnapshot(self.path,assets=self.store) as source:definition=self.freeze(source)
        spare=self.store.put(np.arange(65,dtype="i8"),Context())
        request=dict(version=1,id="collect",scene_revision=0,selection_revision=0,source=dict(path=str(self.path)),
                     member_pins=[],operation="resolve_selection",arguments=dict(selection=definition,time=0,limit=1))
        self.assertTrue(execute(request,assets=self.store)["ok"])
        self.assertEqual(self.store.count,1);self.assertFalse(self.store.path(spare)[0].exists())

    def test_anonymous_row_ceiling_is_distinct_from_persistent_id_ceiling(self):
        values=np.arange(1_000_001,dtype="i8");ref=self.store.put(values,Context())
        with SourceSnapshot(self.path,assets=self.store) as source:
            with self.assertRaisesRegex(AnalysisError,"association limit"):
                S.define(source,dict(object="p",kind="particle_ids",selector=dict(ids_asset=ref)))
        path=self.root/"large-anonymous.ssc"
        with SceneCapture(path,objects=[dict(id="p",kind="particles",identity="anonymous",units="m")]) as writer:
            writer.add_particles("p",0,np.zeros((len(values),3),dtype="f4"))
        with SourceSnapshot(path,assets=self.store) as source:
            d=S.define(source,dict(object="p",kind="sample_rows",selector=dict(index=0,rows_asset=ref)))
            self.assertEqual(S.member_count(d["selector"],"rows"),len(values))

    def test_corrupt_missing_and_linked_assets_refuse(self):
        with SourceSnapshot(self.path,assets=self.store) as source:
            definition=self.freeze(source);ref=definition["selector"]["ids_asset"]
            path,_,_=self.store.path(ref);original=path.read_bytes()
            path.write_bytes(bytes([original[0]^1])+original[1:])
            with self.assertRaisesRegex(AnalysisError,"checksum"):S.validate(source,definition)
            path.unlink()
            with self.assertRaisesRegex(AnalysisError,"unavailable"):S.validate(source,definition)
            path.symlink_to(self.path)
            with self.assertRaisesRegex(AnalysisError,"links"):S.validate(source,definition)

    def test_cached_member_mutation_is_detected_before_publication(self):
        with SourceSnapshot(self.path,assets=self.store) as source:
            definition=self.freeze(source);ref=definition["selector"]["ids_asset"]
            source.member_array(ref)
            path,_,_=self.store.path(ref)
            path.write_bytes(path.read_bytes())
            with self.assertRaisesRegex(AnalysisError,"changed"):source.verify_members()

    def test_private_and_shared_disk_quotas_refuse_without_partial_publish(self):
        limited=MemberAssets(self.root/"limited",limit=8000)
        context=Context()
        first=limited.put(np.arange(1000,dtype="i8"),context)
        with self.assertRaises(AnalysisError):limited.put(np.arange(1001,dtype="i8"),context)
        self.assertEqual(limited.used,8000);self.assertEqual(len(list(limited.root.iterdir())),1)
        registry=self.root/"registry"
        a=MemberAssets(registry/"one"/"members",registry_root=registry,global_limit=12000)
        b=MemberAssets(registry/"two"/"members",registry_root=registry,global_limit=12000)
        a.put(np.arange(1000,dtype="i8"),context)
        with self.assertRaisesRegex(AnalysisError,"disk budget"):b.put(np.arange(1000,dtype="i8"),context)
        self.assertEqual(b.count,0);self.assertEqual(context.used,0)

    def test_noninteger_negative_or_unsorted_identity_asset_refused(self):
        context=Context()
        for values in [np.array([1.5]),np.array([-1],dtype="i8"),np.array([2**63],dtype="u8")]:
            with self.assertRaises(AnalysisError):self.store.put(values,context)
        # A valid binary hash is not proof of the selection's identity schema.
        ref=self.store.put(np.array([7,7],dtype="i8"),context)
        with SourceSnapshot(self.path,assets=self.store) as source:
            with self.assertRaisesRegex(AnalysisError,"sorted, unique"):S.define(source,dict(object="p",kind="particle_ids",selector=dict(ids_asset=ref)))
        self.assertEqual(context.used,0)

    def test_reopen_store_keeps_hash_references_and_memory_budget(self):
        with SourceSnapshot(self.path,assets=self.store) as source:definition=self.freeze(source)
        reopened=MemberAssets(self.store.root)
        with SourceSnapshot(self.path,assets=reopened) as source:
            self.assertEqual(S.validate(source,definition)["selector"],definition["selector"])
        self.assertEqual(reopened.used,self.store.used)
        with self.assertRaises(AnalysisError):
            with SourceSnapshot(self.path,context=Context(memory_bytes=2*1048576),assets=reopened) as source:S.validate(source,definition)

    def test_anonymous_row_asset_remains_record_local(self):
        path=self.root/"anonymous.ssc"
        with SceneCapture(path,objects=[dict(id="p",kind="particles",units="m",identity="anonymous")]) as writer:
            writer.add_particles("p",0,np.zeros((128,3)))
            writer.add_particles("p",1,np.zeros((128,3)))
        with SourceSnapshot(path,assets=self.store) as source:
            d=S.define(source,dict(object="p",kind="sample_rows",selector=dict(index=0,rows=list(range(128)))))
            self.assertIn("rows_asset",d["selector"])
            self.assertEqual(dispatch(source,"resolve_selection",dict(selection=d,time=.5,limit=4))["present"],128)
            r=dispatch(source,"resolve_selection",dict(selection=d,time=1))
            self.assertEqual((r["selected"],r["present"],r["reason"]),(128,0,"sample_local"))

    def test_grid_address_asset_retains_xyz_and_source_row_order(self):
        path=self.root/"grid.ssc"
        with SceneCapture(path,objects=[dict(id="v",kind="volume",units="m")]) as writer:
            writer.add_volume("v",0,{"value":np.ones((3,4,9))},origin=[0,0,0],spacing=[1,1,1])
        with SourceSnapshot(path,assets=self.store) as source:
            roi=S.define(source,dict(object="v",kind="roi",selector=dict(shape="box",lower=[-1,-1,-1],upper=[10,10,10])))
            d=dispatch(source,"freeze_selection",dict(selection=roi,time=0))["selection"]
            self.assertEqual(d["selector"]["xyz_asset"]["shape"],[108,3])
            result=dispatch(source,"resolve_selection",dict(selection=d,time=0,limit=7))
            self.assertEqual(result["present"],108)
            self.assertEqual([row["row"] for row in result["preview"]],list(range(0,108,16)))


if __name__=="__main__":unittest.main()

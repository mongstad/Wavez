import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from simscope_export.analysis import AnalysisError,Context
from simscope_export.analysis.contracts import MIB,float_token
from simscope_export.analysis.disk_quota import DiskQuota
from simscope_export.analysis.member_assets import MemberAssets
from simscope_export.analysis.result_store import ResultCache


class ResultStoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.registry=Path(self.tmp.name)
        self.cache=ResultCache(self.registry/"one"/"results")

    def tearDown(self):self.tmp.cleanup()

    def row(self,i,units="m"):
        t=float_token(.10000000000000003)
        return dict(result_id="synthetic-result",selection_key="selected",source_key="source-hash",object="p",association="vertex",entity_id=str(2**53+i),
                    source_row=str(i),sample_index=str(i),time=t["text"],time_f64_le_hex=t["f64_le_hex"],channel="x",statistic="trace",value=str(i),source_dtype="i8",units=units,value_status="source",support_key=str(i))

    def publish(self,count=10):
        context=Context()
        with self.cache.begin(dict(result_id="synthetic-result"),expected_rows=count,byte_limit=16*MIB,context=context) as writer:
            for i in range(count):writer.append(self.row(i));writer.append(dict(key=str(i),selected=1,present=1),kind="support")
            ref=writer.finish()
        self.assertEqual(context.used,0);return ref

    def test_full_exact_rows_and_native_time_tokens_page_across_chunks(self):
        context=Context()
        with self.cache.begin(dict(result_id="synthetic-result"),expected_rows=3000,byte_limit=16*MIB,context=context) as writer:
            for i in range(3000):writer.append(self.row(i,units='quoted,"\n'+"u"*2048))
            ref=writer.finish()
        manifest=self.cache.manifest(ref,context)
        self.assertGreater(len(manifest["artifacts"]),1)
        boundary=manifest["artifacts"][1]["first"]
        r=self.cache.page(ref,offset=boundary-5,limit=20,context=context)
        self.assertEqual([row["entity_id"] for row in r["rows"]],[str(2**53+i) for i in range(boundary-5,boundary+15)])
        self.assertEqual(r["rows"][0]["time_f64_le_hex"],float_token(.10000000000000003)["f64_le_hex"])
        self.assertEqual(r["next_offset"],boundary+15)
        self.assertEqual(context.used,0)

    def test_complete_empty_result_and_support_pagination(self):
        empty=self.publish(0);r=self.cache.page(empty);self.assertEqual(r["rows"],[]);self.assertTrue(r["complete"])
        ref=self.publish(8);r=self.cache.page(ref,kind="support",offset=3,limit=2)
        self.assertEqual([s["key"] for s in r["rows"]],["3","4"])
        self.assertEqual(self.cache.page(ref,offset=8)["rows"],[])

    def test_no_partial_publication_after_error_or_stream_quota(self):
        context=Context()
        with self.assertRaises(AnalysisError):
            with self.cache.begin({},expected_rows=0,byte_limit=2*MIB,context=context) as writer:
                for i in range(1000):writer.append(self.row(i,units="u"*8192))
                writer.finish()
        self.assertEqual(list(self.cache.root.iterdir()),[]);self.assertEqual(context.used,0)
        with self.assertRaises(AnalysisError):
            with self.cache.begin({},expected_rows=0,byte_limit=2*MIB,context=context) as writer:writer.append(dict(entity_id=2**63-1))
        self.assertEqual(list(self.cache.root.iterdir()),[]);self.assertEqual(context.used,0)

    def test_shared_member_result_reservation_limits(self):
        self.cache.quota=DiskQuota(self.registry,limit=8*MIB,free_reserve=0)
        members=MemberAssets(self.registry/"two"/"members",registry_root=self.registry,global_limit=8*MIB)
        context=Context()
        with self.cache.begin({},expected_rows=0,byte_limit=6*MIB,context=context) as writer:
            with self.assertRaisesRegex(AnalysisError,"disk budget"):members.put(np.arange(400000,dtype="i8"),context)
            self.assertEqual(members.count,0)
        self.assertEqual(context.used,0)
        self.assertEqual(self.cache.quota.usage(context)["bytes"],0)

    def test_corruption_missing_file_and_path_traversal_refuse(self):
        ref=self.publish();path=self.cache.directory(ref);manifest=self.cache.manifest(ref,Context())
        chunk=path/manifest["artifacts"][0]["path"];original=chunk.read_bytes();chunk.write_bytes(original+b"x")
        with self.assertRaises(AnalysisError):self.cache.page(ref)
        chunk.unlink();chunk.symlink_to(path/"manifest.json")
        with self.assertRaisesRegex(AnalysisError,"links"):self.cache.page(ref)
        with self.assertRaises(AnalysisError):self.cache.page(dict(ref,id="../outside"))
        data=(path/"manifest.json").read_bytes();(path/"manifest.json").write_bytes(data+b" ")
        with self.assertRaisesRegex(AnalysisError,"checksum"):self.cache.page(ref)

    def test_cancelled_result_is_removed_and_pinned_results_survive_collection(self):
        a=self.publish();b=self.publish();context=Context()
        self.assertEqual(self.cache.collect([a],context),1)
        self.assertTrue(self.cache.directory(a).exists())
        with self.assertRaises(AnalysisError):self.cache.directory(b)
        calls=[0]
        def cancelled():calls[0]+=1;return calls[0]>20
        context=Context(cancelled=cancelled)
        with self.assertRaises(AnalysisError):
            with self.cache.begin({},expected_rows=100,context=context) as writer:
                for i in range(100):writer.append(self.row(i))
                writer.finish()
        self.assertEqual(context.used,0);self.assertEqual([p.name for p in self.cache.root.iterdir()],[a["id"]])

    def test_unrecognized_files_are_preserved_during_cleanup(self):
        ref=self.publish();path=self.cache.directory(ref);(path/"user.txt").write_text("keep")
        with self.assertRaisesRegex(AnalysisError,"Unknown files"):self.cache.collect([],Context())
        self.assertEqual((path/"user.txt").read_text(),"keep")

    def test_result_dependencies_pin_original_member_assets_after_request_is_forgotten(self):
        context=Context();assets=MemberAssets(self.registry/"one"/"members")
        member=assets.put(np.array([7,2**53+1,2**63-1],dtype="i8"),context)
        with self.cache.begin(dict(request=dict(selections=[dict(selector=dict(ids_asset=member))])),expected_rows=0,context=context) as writer:original=writer.finish()
        with self.cache.begin(dict(inputs=[dict(result=original)]),expected_rows=0,context=context) as writer:comparison=writer.finish()
        refs=self.cache.member_references([comparison],context)
        self.assertEqual(refs,[member]);assets.collect(refs,context)
        self.assertEqual(self.cache.collect([comparison],context),0)
        # A fresh worker/result-store instance reconstructs dependency pins.
        reopened=ResultCache(self.cache.root)
        self.assertEqual(reopened.member_references([comparison],context),[member])
        with context.allocation(MIB):
            values=assets.read(member,context);self.assertEqual(values.tolist(),[7,2**53+1,2**63-1]);del values
        self.assertEqual(context.used,0)


if __name__=="__main__":unittest.main()

from pathlib import Path
import tempfile
import unittest

from wavez_export.analysis import SourceSnapshot,Context,AnalysisError
from wavez_export.analysis.diagnostics import run as import_csv
from wavez_export.analysis.comparisons import run
from wavez_export.analysis.result_store import ResultCache
from tests.g4.fixtures import scene


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.source=SourceSnapshot(scene(self.root/"run_a.ssc"));self.other=SourceSnapshot(scene(self.root/"run_b.ssc"))
        self.cache=ResultCache(self.root/"owner"/"results")

    def tearDown(self):
        self.source.close();self.other.close()
        self.assertEqual(self.source.context.used,0);self.assertEqual(self.other.context.used,0);self.tmp.cleanup()

    def data(self,source,key,times,values,units="K",time_units="s"):
        path=self.root/(key+".csv");path.write_text("time,value\n"+"".join(f"{t},{v}\n" for t,v in zip(times,values)))
        ref=import_csv(source,dict(path=str(path),key=key,time_column="time",time_units=time_units,delimiter=",",values=[dict(column="value",dtype="i8",units=units)]),self.cache)["result"]
        return dict(source=source.identity(),result=ref,series=dict(selection_key=key,channel="value",component="",statistic="supplied_diagnostic",member_key=""),time=dict(units="s",reference="declared experiment origin"),value=dict(units="K",reference="declared scalar correspondence"))

    def compare(self,left,right,operation="difference"):
        output=run(self.source,dict(left=left,right=right,operation=operation,join=dict(mode="exact")),self.cache)
        return self.cache.page(output["result"])["rows"],self.cache.page(output["result"],kind="support")["rows"],output["result"]

    def test_exact_outer_join_has_unmatched_times_and_exact_integer_differences(self):
        a=self.data(self.source,"a",[0,1,2],[2**53+1,2**53+3,2**53+5]);b=self.data(self.other,"b",[0,.5,2],[2**53,2**53+1,2**53+3])
        rows,support,_=self.compare(a,b)
        self.assertEqual([r["time"] for r in rows],["0","0.5","1","2"])
        self.assertEqual([r["value"] for r in rows],["1","","","2"])
        self.assertEqual(rows[1]["reason"],"left:unmatched_time");self.assertEqual(rows[2]["reason"],"right:unmatched_time")
        self.assertEqual(support[0]["left"]["source_value"],str(2**53+1))
        self.assertNotEqual(support[0]["left"]["source"]["uuid"],support[0]["right"]["source"]["uuid"])

    def test_offsets_preserve_raw_times_and_zero_ratio_is_unavailable(self):
        a=self.data(self.source,"a",[0,1,2],[2,4,6]);b=self.data(self.other,"b",[10,11,12],[1,0,3]);b["time"].update(offset=10,origin="manual bookmark")
        rows,support,_=self.compare(a,b,"ratio")
        self.assertEqual([r["value"] for r in rows],["2","","2"])
        self.assertEqual(rows[1]["reason"],"zero_denominator")
        self.assertEqual(support[0]["right"]["native_time"]["text"],"10")
        self.assertEqual(support[0]["right"]["aligned_time"]["text"],"0")

    def test_time_and_value_conversions_require_explicit_compatible_mappings(self):
        a=self.data(self.source,"a",[0,1],[2,3]);b=self.data(self.other,"b",[0,1000],[1000,2000],units="mK",time_units="ms")
        with self.assertRaisesRegex(AnalysisError,"explicit scale"):self.compare(a,b)
        b["time"]["scale"]=.001;b["value"]["scale"]=.001
        rows,_,_=self.compare(a,b);self.assertEqual([r["value"] for r in rows],["1","1"])
        b["value"]["reference"]="different physical quantity"
        with self.assertRaisesRegex(AnalysisError,"same target"):self.compare(a,b)

    def test_source_changes_and_invalid_time_axes_refuse(self):
        a=self.data(self.source,"a",[0,1],[2,3]);b=self.data(self.other,"b",[1,0],[1,2])
        with self.assertRaisesRegex(AnalysisError,"native times"):self.compare(a,b)
        b=self.data(self.other,"b",[0,1],[1,2])
        (self.root/"b.csv").write_text("time,value\n0,9\n1,9\n")
        with self.assertRaisesRegex(AnalysisError,"differs"):self.compare(a,b)

    def test_pinning_comparison_keeps_both_input_results(self):
        a=self.data(self.source,"a",[0,1],[2,3]);b=self.data(self.other,"b",[0,1],[1,2])
        _,_,result=self.compare(a,b)
        self.assertEqual(self.cache.collect([result],Context()),0)
        self.assertTrue(self.cache.directory(a["result"]).is_dir());self.assertTrue(self.cache.directory(b["result"]).is_dir())
        self.assertEqual(self.cache.collect([],Context()),3)

    def test_schedule_holds_scalar_without_filling_missing_or_outside_range(self):
        a=self.data(self.source,"a",[0,1,2],[2,"",6]);b=self.data(self.other,"b",[0,1,2],[1,2,3])
        result=run(self.source,dict(left=a,right=b,operation="difference",join=dict(mode="schedule",start=0,step=.5,count=6)),self.cache)
        rows=self.cache.page(result["result"])["rows"]
        self.assertEqual([r["value"] for r in rows],["1","1","","","3",""])
        self.assertEqual(rows[-1]["reason"],"left:after_input_range")
        support=self.cache.page(result["result"],kind="support")["rows"]
        self.assertEqual(support[1]["left"]["time_status"],"held")
        self.assertEqual(support[1]["left"]["evaluation"]["native_results"][1]["native_time"]["text"],"1")

    def native(self,source,identity,channel="position",object="p"):
        from wavez_export.analysis import selectors as S
        from wavez_export.analysis.native_analysis import run as native
        d=S.define(source,dict(object=object,kind="particle_ids" if object=="p" else "mesh_vertices",selector=dict(ids=[str(identity)])))
        spec=dict(channel=channel)
        if channel=="position":spec["component"]=0 if object=="p" else 2
        ref=native(source,dict(selections=[d],mode="trace",range=dict(axis="native_time",start=0,end=6),channels=[spec]),self.cache)["result"]
        return dict(source=source.identity(),result=ref,series=dict(selection_key=d["key"],channel=channel,component=str(spec["component"]) if "component" in spec else "",statistic="value",member_key="id:"+str(identity)),time=dict(units="s",reference="manual experiment origin"),value=dict(units="m" if channel=="position" else "unknown",reference="manual quantity correspondence"))

    def test_schedule_source_positions_use_exact_ids_and_earlier_active_set(self):
        from tests.g4.fixtures import HIGH_ID
        a=self.native(self.source,HIGH_ID);b=self.native(self.other,7)
        result=run(self.source,dict(left=a,right=b,operation="difference",join=dict(mode="schedule",start=0,step=.25,count=9)),self.cache)
        rows=self.cache.page(result["result"])["rows"];support=self.cache.page(result["result"],kind="support")["rows"]
        base=HIGH_ID%101-7
        self.assertEqual(float(rows[1]["value"]),base)
        self.assertEqual(float(rows[3]["value"]),base+.5)
        self.assertEqual(rows[6]["value"],"")
        self.assertEqual(support[3]["left"]["position_status"],"interpolated_by_id")
        self.assertEqual(support[3]["right"]["position_status"],"held_unmatched")
        self.assertEqual(support[3]["left"]["evaluation"]["source_bracket"]["a"],1)

    def test_schedule_mesh_topology_change_holds_position(self):
        a=self.native(self.source,7,object="mesh");b=self.native(self.other,7,object="mesh")
        result=run(self.source,dict(left=a,right=b,operation="difference",join=dict(mode="schedule",start=1,step=1,count=5)),self.cache)
        support=self.cache.page(result["result"],kind="support")["rows"]
        self.assertEqual(support[0]["left"]["source_value"],"0")
        self.assertEqual(support[0]["left"]["position_status"],"held_unmatched")
        self.assertEqual(support[-1]["left"]["source_value"],"4")
        self.assertEqual(support[-1]["left"]["evaluation_value"],"5")
        self.assertEqual(support[-1]["left"]["position_status"],"interpolated_by_id")

    def test_second_source_mutation_during_finish_rolls_back_publication(self):
        from unittest.mock import patch
        from wavez_export.analysis.jobs import execute
        from wavez_export.analysis.result_store import ResultWriter
        a=self.data(self.source,"a",[0,1],[2,3]);b=self.data(self.other,"b",[0,1],[1,2]);original=ResultWriter.finish
        def finish(writer):
            ref=original(writer)
            path=self.root/"b.csv";path.write_text(path.read_text()+"2,9\n")
            return ref
        request=dict(version=1,id="comparison",scene_revision=0,selection_revision=0,source=self.source.identity(),operation="compare_series",arguments=dict(left=a,right=b,operation="difference",join=dict(mode="exact")))
        with patch.object(ResultWriter,"finish",finish):
            with self.assertRaisesRegex(AnalysisError,"final verification"):execute(request,results=self.cache)
        self.assertEqual(len(list(self.cache.root.iterdir())),2)


if __name__=="__main__":unittest.main()

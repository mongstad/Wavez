import hashlib
from pathlib import Path
import tempfile
import unittest

from wavez_export.analysis import SourceSnapshot,AnalysisError,Context
from wavez_export.analysis.diagnostics import run,Input,mapping
from wavez_export.analysis.result_store import ResultCache
from tests.g4.fixtures import scene


class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.capture=scene(self.root/"capture.wvz");self.source=SourceSnapshot(self.capture)
        self.cache=ResultCache(self.root/"owner"/"results");self.path=self.root/"diagnostic.csv"
        self.args=dict(path=str(self.path),key="supplied",time_column="time",time_units="s",values=[dict(column="value",dtype="f8",units="K"),dict(column="id",dtype="i8",units="1",semantic="identifier")],delimiter=",")

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0);self.tmp.cleanup()

    def import_rows(self,text,**options):
        self.path.write_text(text);before=hashlib.sha256(self.path.read_bytes()).hexdigest()
        result=run(self.source,self.args|options,self.cache)
        self.assertEqual(before,hashlib.sha256(self.path.read_bytes()).hexdigest())
        return self.cache.page(result["result"])["rows"],self.cache.manifest(result["result"],Context()),self.cache.page(result["result"],kind="support")["rows"]

    def test_independent_native_clock_exact_integer_and_raw_missing_cells(self):
        rows,manifest,support=self.import_rows("time,value,id\n0.10000000000000003,1.000000000000001,9007199254740993\n0.4,,9223372036854775807\n1.7,3,7\n",max_gap=.5,time_offset=.1,offset_origin="manual reference")
        self.assertEqual(len(rows),6);self.assertEqual(rows[1]["value"],"9007199254740993")
        self.assertEqual(rows[2]["value"],"");self.assertEqual(rows[2]["reason"],"missing_cell")
        self.assertEqual(support[0]["raw_time"],"0.10000000000000003")
        self.assertTrue(support[2]["gap_from_previous"])
        self.assertEqual(rows[0]["statistic"],"supplied_diagnostic");self.assertTrue(rows[0]["clock"].startswith("csv:"))
        self.assertIn("explicit",manifest["binding"]);self.assertEqual(support[1]["csv_line"],3)

    def test_bad_axis_keeps_order_index_only_and_refuses_physical_offset(self):
        rows,_,_=self.import_rows("time,value,id\n2,1,7\n1,2,8\n1,3,9\n")
        self.assertEqual([r["time"] for r in rows[::2]],["2","1","1"])
        self.assertTrue(all(r["time_status"]=="index_only" for r in rows))
        with self.assertRaisesRegex(AnalysisError,"valid CSV time axis"):
            run(self.source,self.args|dict(time_offset=1,offset_origin="manual"),self.cache)

    def test_explicit_missing_intervals_preserve_raw_value_provenance(self):
        rows,_,support=self.import_rows("time,value,id\n0,1,7\n1,2,8\n2,3,9\n",missing_intervals=[[.5,1.5]])
        self.assertEqual(rows[2]["value"],"");self.assertEqual(rows[2]["reason"],"declared_missing_interval")
        self.assertEqual(support[1]["raw_values"]["value"],"2")

    def test_malformed_rows_numbers_and_logical_row_limits(self):
        for text in ["time,value,id\n0,1\n","time,value,id\n0,=2+2,7\n","time,value,id\n0,1e999,7\n","time,value,id\n0,1e-999,7\n","time,value,id\n0,1,9223372036854775808\n","time,value,id\n0,\""+"x"*17000+"\",7\n"]:
            self.path.write_text(text)
            with self.assertRaisesRegex(AnalysisError,"[Ll]ine"):run(self.source,self.args,self.cache)
        self.assertEqual(list(self.cache.root.iterdir()),[])

    def test_blank_line_policy_nonfinite_cells_and_selected_delimiter(self):
        with self.assertRaisesRegex(AnalysisError,"column count"):
            self.import_rows("time,value,id\n\n0,nan,7\n")
        rows,manifest,_=self.import_rows("time;value;id\n\n0;nan;7\n1;+inf;8\n",delimiter=";",blank_lines="skip")
        self.assertEqual(manifest["skipped_blank_lines"],1)
        self.assertEqual(rows[0]["value_status"],"nonfinite");self.assertEqual(rows[2]["value_status"],"nonfinite")

    def test_source_mutation_and_cancel_never_publish_partial_import(self):
        self.path.write_text("time,value,id\n0,1,7\n1,2,8\n")
        with Input(str(self.path),Context()) as source:
            self.path.write_text("time,value,id\n0,9,7\n1,2,8\n")
            with self.assertRaisesRegex(AnalysisError,"changed"):list(source.rows(mapping(self.args)))
        self.path.write_text("time,value,id\n"+"".join(f"{i},1,7\n" for i in range(100)))
        with self.assertRaisesRegex(AnalysisError,"row limit"):run(self.source,self.args|dict(row_limit=10),self.cache)
        self.assertEqual(list(self.cache.root.iterdir()),[])

    def test_period_job_uses_full_diagnostic_rows_and_keeps_window_evidence(self):
        import numpy as np
        from wavez_export.analysis.period_jobs import run as period_job
        from wavez_export.analysis.plot_preview import preview
        times=np.arange(0,8,.02)
        self.path.write_text("time,value,id\n"+"".join(f"{t:.17g},{np.sin(2*np.pi*t):.17g},7\n" for t in times))
        imported=run(self.source,self.args,self.cache)
        selected=dict(selection_key="supplied",channel="value",component="",statistic="supplied_diagnostic",member_key="")
        arguments=dict(result=imported["result"],series=selected,window=[0,6],options=dict(method="autocorrelation",detrend="mean",lag_range=[.5,2],min_separation=.3,prominence=.5,uniform=True))
        output=period_job(self.source,arguments,self.cache)
        rows=list(self.cache.rows(output["result"],Context()))
        candidates=[r for _,r in rows if r["statistic"]=="exploratory_period"]
        self.assertEqual(len(candidates),2)
        for row in candidates:self.assertAlmostEqual(float(row["value"]),1,places=12)
        manifest=self.cache.manifest(output["result"],Context())
        self.assertEqual([r["label"] for r in manifest["period_windows"]],["full_run","selected_window"])
        self.assertTrue(any(r["statistic"]=="observed_peak_interval" for _,r in rows))
        acf=next(r for _,r in rows if r["statistic"]=="autocorrelation")
        spec={k:acf[k] for k in selected}
        plot=preview(self.cache,output["result"],spec,Context());self.assertEqual(plot["axis"],"lag")
        self.path.write_text(self.path.read_text()+"9,0,7\n")
        with self.assertRaisesRegex(AnalysisError,"differs"):period_job(self.source,arguments,self.cache)


if __name__=="__main__":unittest.main()

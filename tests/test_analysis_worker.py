import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from tests.g4.fixtures import scene,HIGH_ID
from wavez_export.analysis.contracts import float_token, parse_float_token
from wavez_export.analysis import SourceSnapshot
from wavez_export.analysis import selectors as S

ROOT=Path(__file__).resolve().parents[1]


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.root=Path(self.tmp.name)
        self.capture=scene(self.root/"capture.ssc")
        self.jobs=self.root/"worker";self.jobs.mkdir()
        self.write("lease.json",{"owner":os.getpid()})
        self.process=None

    def tearDown(self):
        if self.process:
            self.write("close",{})
            try:self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:self.process.kill();self.process.wait()
            self.process.stdout.close();self.process.stderr.close()
        self.tmp.cleanup()

    def write(self,name,value):
        path=self.jobs/name
        temp=path.with_suffix(path.suffix+".new")
        temp.write_text(json.dumps(value));os.replace(temp,path)

    def wait(self,name,predicate=lambda v:True,seconds=5):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            self.write("lease.json",{"owner":os.getpid()})
            try:
                result=json.loads((self.jobs/name).read_text())
                if predicate(result):return result
            except (FileNotFoundError,json.JSONDecodeError):pass
            if self.process.poll() is not None:
                out,err=self.process.communicate()
                self.fail(f'Worker exited: {out}\n{err}')
            time.sleep(.01)
        self.fail(f'Timeout waiting for {name}')

    def start(self,harness=False):
        command=([sys.executable,str(ROOT/"tests/g4/worker_harness.py"),str(self.jobs),str(os.getpid())] if harness else
                 [sys.executable,str(ROOT/"tools/analyze_selection.py"),"--directory",str(self.jobs),"--owner-pid",str(os.getpid())])
        self.process=subprocess.Popen(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        return self.wait("ready.json",lambda r:r.get("pid")==self.process.pid)

    def request(self,id="one",operation="describe",arguments=None):
        request=dict(version=1,id=id,scene_revision=3,selection_revision=4,
                     source={"path":str(self.capture)},operation=operation,arguments=arguments or {})
        self.write("request.json",request)

    def test_runtime_guard_and_native_records(self):
        ready=self.start()
        self.assertLess(ready["memory"]["VmRSS"],256*1024**2)
        if ready["guard"]["enabled"]:
            self.assertLessEqual(ready["guard"]["baseline"]["VmSize"]+1280*1024**2,2*1024**3)
        self.request()
        result=self.wait("result.json",lambda r:r.get("id")=="one")
        self.assertTrue(result["ok"],result)
        self.assertEqual([o["samples"] for o in result["data"]["objects"]],[4,3,4])
        self.assertEqual(result["metrics"]["charged_bytes"],0)
        self.request("two","records",{"object":"p"})
        result=self.wait("result.json",lambda r:r.get("id")=="two")
        self.assertEqual([r["time"]["text"] for r in result["data"]["records"]],["0","0.5","1.5","3"])

    def test_source_value_and_large_id_survive_protocol(self):
        self.start();self.request(operation="sample",arguments={"object":"p","index":0,"channels":["value","particle_id"],"ids":[str(HIGH_ID),"123"]})
        r=self.wait("result.json",lambda r:r.get("id")=="one")
        self.assertTrue(r["ok"],r)
        rows=r["data"]["rows"]
        self.assertEqual(rows[0]["channels"]["particle_id"]["value"],str(HIGH_ID))
        self.assertIn("f64_le_hex",rows[0]["channels"]["value"]["exact"])
        self.assertEqual(rows[1]["status"],"absent_at_sample")

    def test_pinned_reply_and_exact_coordinates_are_reusable(self):
        self.start();self.request()
        first=self.wait("result.json",lambda r:r.get("id")=="one")
        self.write("request.json",dict(version=1,id="exact",scene_revision=3,selection_revision=4,
            source=first["source"],operation="probe",arguments=dict(object="field",
                time=float_token(.75),coordinate=[float_token(v) for v in [10.5,-2,6.5]],channel="value")))
        result=self.wait("result.json",lambda r:r.get("id")=="exact")
        self.assertTrue(result["ok"],result)
        self.assertEqual(parse_float_token(result["data"]["value"]["exact"]),13.75)
        self.assertEqual(result["source"],first["source"])

    def test_cancellation_is_acknowledged_and_worker_reused(self):
        self.start(harness=True)
        self.request("slow","identity_audit",{"object":"p"})
        self.wait("barrier.json")
        began=time.monotonic();self.write("cancel.json",{"id":"slow"})
        result=self.wait("result.json",lambda r:r.get("id")=="slow")
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"],"cancelled")
        self.assertLess(time.monotonic()-began,1.)
        self.request("next")
        self.assertTrue(self.wait("result.json",lambda r:r.get("id")=="next")["ok"])

    def test_superseded_work_cannot_publish_as_new_request(self):
        self.start(harness=True)
        self.request("slow","identity_audit",{"object":"p"})
        self.wait("barrier.json")
        self.request("new","probe",{"object":"field","time":.75,"coordinate":[10.5,-2,6.5],"channel":"value"})
        result=self.wait("result.json",lambda r:r.get("id")=="new")
        self.assertTrue(result["ok"],result)
        self.assertEqual(result["selection_revision"],4)
        self.assertEqual(result["data"]["value"]["value"],13.75)
        self.assertEqual(result["data"]["sampling"]["time"],0.)

    def test_closed_owner_lease_exits_without_orphan(self):
        self.start()
        (self.jobs/"lease.json").unlink()
        self.process.wait(timeout=2)
        self.assertEqual(self.process.returncode,0)
        self.assertTrue((self.jobs/"stopped.json").exists())

    def test_malformed_operation_refused_and_recovery(self):
        self.start();self.request(operation="eval")
        result=self.wait("result.json",lambda r:r.get("id")=="one")
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"],"unsupported_operation")
        self.request("ok")
        self.assertTrue(self.wait("result.json",lambda r:r.get("id")=="ok")["ok"])

    def test_worker_crash_restart_keeps_live_viewer_exact_assets(self):
        self.start();self.request("large","define_selection",dict(object="p",kind="particle_ids",selector=dict(ids=[str(i) for i in range(128)])))
        first=self.wait("result.json",lambda r:r.get("id")=="large")
        self.assertTrue(first["ok"],first);definition=first["data"]
        ref=definition["selector"]["ids_asset"]
        path=self.jobs/"members"/(ref["sha256"]+".i8");before=path.read_bytes()
        self.process.kill();self.process.wait(timeout=2);self.process.stdout.close();self.process.stderr.close()
        self.request("restarted","resolve_selection",dict(selection=definition,time=0,limit=1))
        self.start()
        result=self.wait("result.json",lambda r:r.get("id")=="restarted")
        self.assertTrue(result["ok"],result)
        self.assertEqual(result["data"]["selected"],128);self.assertEqual(result["data"]["present"],1)
        self.assertEqual(path.read_bytes(),before)

    def interval(self):
        with SourceSnapshot(self.capture) as source:
            definition=S.define(source,dict(object="p",kind="particle_ids",selector=dict(ids=[str(HIGH_ID)])))
            ref=source.identity()
        self.write("background_request.json",dict(version=1,id="interval",scene_revision=3,selection_revision=4,analysis_revision=8,
            source=ref,operation="analyze",arguments=dict(selections=[definition],mode="trace",channels=[dict(channel="value")],range=dict(axis="native_time",start=0,end=3)),member_pins=[],result_pins=[]))
        return ref

    def test_cursor_preempts_interval_without_restarting_or_cancelling_it(self):
        self.start(harness=True);ref=self.interval();self.wait("background_barrier.json")
        for i in range(3):
            self.request("cursor"+str(i),"probe",dict(object="field",channel="value",time=.75,coordinate=[10.5,-2,6.5]))
            result=self.wait("result.json",lambda r:r.get("id")=="cursor"+str(i))
            self.assertTrue(result["ok"],result)
            self.assertEqual(result["data"]["value"]["value"],13.75)
            self.assertLessEqual(result["shared_memory"]["peak"],512*1024**2)
        self.assertFalse((self.jobs/"background_result.json").exists())
        self.write("release",{})
        done=self.wait("background_result.json",lambda r:r.get("id")=="interval")
        self.assertTrue(done["ok"],done);self.assertEqual(done["data"]["row_count"],4)
        self.assertEqual(done["analysis_revision"],8);self.assertEqual(done["metrics"]["charged_bytes"],0)
        self.write("request.json",dict(version=1,id="page",scene_revision=3,selection_revision=99,source=ref,operation="result_page",arguments=dict(result=done["data"]["result"])))
        page=self.wait("result.json",lambda r:r.get("id")=="page")
        self.assertTrue(page["ok"],page)
        self.assertEqual([r["time"] for r in page["data"]["rows"]],["0","0.5","1.5","3"])

    def test_interval_cancellation_removes_staging_and_preserves_cursor(self):
        self.start(harness=True);self.interval();self.wait("background_barrier.json")
        started=time.monotonic();self.write("background_cancel.json",dict(id="interval"))
        done=self.wait("background_result.json",lambda r:r.get("id")=="interval")
        self.assertEqual(done["code"],"cancelled");self.assertLess(time.monotonic()-started,1)
        self.assertEqual(done["metrics"]["charged_bytes"],0)
        self.assertEqual(list((self.jobs/"results").iterdir()),[])
        self.request("still-live")
        self.assertTrue(self.wait("result.json",lambda r:r.get("id")=="still-live")["ok"])

    def test_interval_source_mutation_never_publishes_complete_result(self):
        self.start(harness=True);self.interval();self.wait("background_barrier.json")
        with self.capture.open("r+b") as file:file.truncate(self.capture.stat().st_size-1)
        self.write("release",{})
        done=self.wait("background_result.json",lambda r:r.get("id")=="interval")
        self.assertFalse(done["ok"]);self.assertEqual(done["code"],"source_changed")
        self.assertEqual(list((self.jobs/"results").iterdir()),[])

    def test_playback_underflow_pauses_scan_but_services_cursor_and_resumes(self):
        self.start();self.write('playback_pressure.json',dict(underflow=True));self.interval()
        self.wait('background_progress.json',lambda r:r.get('stage')=='paused_for_playback_underflow')
        for i in range(3):
            self.request('pressure-cursor'+str(i),'probe',dict(object='field',channel='value',time=.75,coordinate=[10.5,-2,6.5]))
            result=self.wait('result.json',lambda r:r.get('id')=='pressure-cursor'+str(i))
            self.assertTrue(result['ok'],result);self.assertEqual(result['data']['value']['value'],13.75)
        self.assertFalse((self.jobs/'background_result.json').exists())
        self.write('playback_pressure.json',dict(underflow=False))
        result=self.wait('background_result.json',lambda r:r.get('id')=='interval')
        self.assertTrue(result['ok'],result);self.assertEqual(result['data']['row_count'],4)
        self.assertGreater(result['playback_pressure']['pauses'],0);self.assertGreater(result['playback_pressure']['seconds'],0)
        self.assertEqual(result['metrics']['charged_bytes'],0)

    def test_paused_analysis_keeps_finite_deadline_and_cancellation(self):
        self.start();self.write('playback_pressure.json',dict(underflow=True));self.interval()
        self.wait('background_progress.json',lambda r:r.get('stage')=='paused_for_playback_underflow')
        self.write('background_cancel.json',dict(id='interval'))
        result=self.wait('background_result.json',lambda r:r.get('id')=='interval')
        self.assertFalse(result['ok']);self.assertEqual(result['code'],'cancelled')
        request=json.loads((self.jobs/'background_request.json').read_text());request['id']='deadline';request['budget']=dict(wall_seconds=.2)
        self.write('background_request.json',request)
        result=self.wait('background_result.json',lambda r:r.get('id')=='deadline')
        self.assertFalse(result['ok']);self.assertEqual(result['code'],'deadline')

    def test_csv_and_period_jobs_use_background_transport_and_full_results(self):
        import math
        self.start()
        with SourceSnapshot(self.capture) as source:ref=source.identity()
        path=self.root/"diagnostic.csv"
        path.write_text("t,value\n"+"".join(f"{i*.02:.17g},{math.sin(2*math.pi*i*.02):.17g}\n" for i in range(400)))
        def background(id,operation,arguments):
            self.write("background_request.json",dict(version=1,id=id,scene_revision=3,selection_revision=4,source=ref,operation=operation,arguments=arguments))
            result=self.wait("background_result.json",lambda r:r.get("id")==id)
            self.assertTrue(result["ok"],result);return result["data"]["result"]
        imported=background("diagnostic","import_csv",dict(path=str(path),key="csv",time_column="t",time_units="s",delimiter=",",values=[dict(column="value",dtype="f8",units="u")]))
        period=background("period","estimate_period",dict(result=imported,series=dict(selection_key="csv",channel="value",component="",statistic="supplied_diagnostic",member_key=""),window=[0,6],options=dict(method="peak_spacing",detrend="mean",lag_range=[.5,2],min_separation=.3,prominence=.5)))
        self.write("request.json",dict(version=1,id="period-page",scene_revision=3,selection_revision=4,source=ref,operation="result_page",arguments=dict(result=period)))
        result=self.wait("result.json",lambda r:r.get("id")=="period-page")
        self.assertTrue(result["ok"],result)
        candidates=[r for r in result["data"]["rows"] if r["statistic"]=="exploratory_period"]
        self.assertEqual(len(candidates),2)
        for row in candidates:self.assertAlmostEqual(float(row["value"]),1,places=12)

    def test_full_numerical_export_commits_after_worker_verification(self):
        self.start();source=self.interval()
        result=self.wait("background_result.json",lambda r:r.get("id")=="interval")
        self.assertTrue(result["ok"],result);reference=result["data"]["result"]
        destination=self.root/"published"
        self.write("background_request.json",dict(version=1,id="exported",scene_revision=3,selection_revision=4,source=source,operation="export_analysis",arguments=dict(result=reference,destination=str(destination)),result_pins=[reference]))
        reply=self.wait("background_result.json",lambda r:r.get("id")=="exported")
        self.assertTrue(reply["ok"],reply);self.assertEqual(reply["metrics"]["charged_bytes"],0)
        manifest=json.loads((destination/"analysis.json").read_text())
        self.assertEqual(manifest["row_count"],4);self.assertEqual(manifest["completion"],"complete")
        self.assertFalse(list(self.root.glob(".published.partial-*")))


if __name__ == "__main__":unittest.main()

"""Repository-owned G4 worker. Private bounded job files; no network listener."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import sys
import time

# Only this worker's libraries are configured, never the simulation's environment.
for name in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[name] = "1"
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export.analysis.contracts import AnalysisError, Context, SharedBudget, MAX_CONTROL, MIB
from wavez_export.analysis.jobs import execute, validate_request, BACKGROUND_OPERATIONS, SOURCE_RESULT_OPERATIONS
from wavez_export.analysis.memo import VerificationMemo
from wavez_export.analysis.member_assets import MemberAssets
from wavez_export.analysis.result_store import ResultCache,references_in as result_references
from wavez_export.analysis.spatial_band_sequence import SpectralCache
from wavez_export.analysis.spectral_reconstruction import DenseReconstructionStore
from wavez_export.analysis import native_analysis
from wavez_export.analysis import diagnostics,period_jobs,plot_preview,picking,derived,selection_jobs,comparisons,scheduled_series,linked_plots,space_time,heatmap_preview,input_provenance,atomic_output,export_results,recipes


def memory():
    values = {}
    for line in Path("/proc/self/status").read_text().splitlines():
        if line.startswith(("VmRSS:", "VmHWM:", "VmSize:", "VmPeak:")):
            key, value, _ = line.split()
            values[key[:-1]] = int(value)*1024
    return values


def guard():
    """Validate provisional address-space ceiling against the loaded runtime."""
    before = memory()
    ceiling = 2*1024*MIB
    safe = before["VmSize"] + 1024*MIB + 256*MIB <= ceiling
    if safe:
        soft, hard = resource.getrlimit(resource.RLIMIT_AS)
        limit = min(ceiling, hard) if hard != resource.RLIM_INFINITY else ceiling
        resource.setrlimit(resource.RLIMIT_AS, (limit, hard))
    return dict(enabled=safe, ceiling_bytes=ceiling if safe else None,
                baseline=before, reason="runtime plus 1 GiB workspace and 256 MiB overhead fit" if safe else "runtime does not leave approved workspace headroom")


def read_json(path):
    with path.open("rb") as file:
        data = file.read(MAX_CONTROL+1)
    if len(data) > MAX_CONTROL:
        raise AnalysisError("control_limit", "Worker control message exceeds 1 MiB")
    return json.loads(data)


def write_json(path, value):
    encoded = json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",",":")).encode()
    if len(encoded) > MAX_CONTROL:
        raise AnalysisError("control_limit", "Result exceeds 1 MiB; use a smaller page")
    temporary = path.with_suffix(path.suffix+".tmp")
    with temporary.open("wb") as out:
        out.write(encoded)
    os.replace(temporary, path)


class Worker:
    def __init__(self, directory, owner, lease_seconds=15, assets_root=None):
        self.directory = directory
        self.owner = owner
        self.lease_seconds = lease_seconds
        self.current = None
        self.checked = 0.
        self.superseded = False
        self.exiting = False
        self.guard = guard()
        self.progress_time = 0.
        self.memo = VerificationMemo()
        MemberAssets.reap_abandoned(directory.parent,Context(wall_seconds=10))
        DenseReconstructionStore.reap_abandoned(directory.parent,Context(wall_seconds=10))
        self.assets = MemberAssets(assets_root or directory/"members",registry_root=directory.parent)
        self.assets.set_owner(owner)
        self.results = ResultCache(self.assets.root.parent/"results",registry_root=directory.parent)
        self.spectral_cache = None # A malformed spectral collection cannot block unrelated analysis.
        self.reconstruction_store = None
        self.reconstruction_result_id = None
        self.background_id=None;self.background_request=None;self.background_context=None
        self.background_checked=0.;self.background_superseded=False;self.background_progress_time=0.
        self.interactive_checked=0.;self.pool=None;self.recent_result=None
        self.pressure_pauses=0;self.pressure_seconds=0.
        code=hashlib.sha256()
        for path in sorted(list((ROOT/"wavez_export"/"analysis").glob("*.py"))+list((ROOT/"wavez_export").glob("*.py"))):
            code.update(str(path.relative_to(ROOT)).encode());code.update(path.read_bytes())
        code.update(Path(__file__).read_bytes())
        self.provenance=dict(analysis_code_sha256=code.hexdigest(),worker="tools/analyze_selection.py",policy="private file transport; one computation at a time")

    def owner_alive(self):
        try:
            os.kill(self.owner, 0)
            lease = self.directory/"lease.json"
            return lease.exists() and time.time()-lease.stat().st_mtime < self.lease_seconds
        except (OSError, ValueError):
            return False

    def cancelled(self):
        now = time.monotonic()
        if now-self.checked < .02:
            return self.superseded
        self.checked = now
        if not self.owner_alive() or (self.directory/"close").exists():
            self.exiting = self.superseded = True
            return True
        try:
            request = read_json(self.directory/"request.json")
            self.superseded = request.get("id") != self.current
            cancel = self.directory/"cancel.json"
            if cancel.exists() and read_json(cancel).get("id") == self.current:
                self.superseded = True
        except (OSError, ValueError, AttributeError):
            self.superseded = True
        return self.superseded

    def progress(self, stage, completed, total):
        now = time.monotonic()
        if now-self.progress_time < .1:
            return
        self.progress_time = now
        write_json(self.directory/"progress.json", dict(id=self.current, stage=stage, completed=completed,total=total))

    def background_cancelled(self):
        now=time.monotonic()
        if now-self.background_checked<.02:return self.background_superseded
        self.background_checked=now
        if not self.owner_alive() or (self.directory/"close").exists():
            self.exiting=self.background_superseded=True;return True
        try:
            self.background_superseded=read_json(self.directory/"background_request.json").get("id")!=self.background_id
            cancel=self.directory/"background_cancel.json"
            if cancel.exists() and read_json(cancel).get("id")==self.background_id:self.background_superseded=True
        except (OSError,ValueError,AttributeError):self.background_superseded=True
        return self.background_superseded

    def background_progress(self,stage,completed,total):
        now=time.monotonic()
        if now-self.background_progress_time<.1:return
        self.background_progress_time=now
        write_json(self.directory/"background_progress.json",dict(id=self.background_id,stage=stage,completed=completed,total=total))

    def service_foreground(self):
        """Suspend the current stack at a bounded check; never restart its scan."""
        now=time.monotonic()
        if now-self.interactive_checked<.02:return
        self.interactive_checked=now
        paused_at=None
        try:
            while True:
                request=self.next_request("request.json",self.current)
                if request is not None:
                    started=time.process_time();self.perform(request,False)
                    if self.background_context is not None:self.background_context.cpu_started+=time.process_time()-started
                try:pressure=read_json(self.directory/'playback_pressure.json').get('underflow') is True
                except (OSError,ValueError,AttributeError):pressure=False
                if not pressure or self.background_context is None:return
                if paused_at is None:
                    paused_at=time.monotonic();self.pressure_pauses+=1
                    self.background_progress('paused_for_playback_underflow',0,0)
                # Keep the exact analysis stack and accumulators, service cursor
                # work, and count paused time against the finite wall deadline.
                with self.background_context.defer_checkpoints():self.background_context.check()
                time.sleep(.01)
        finally:
            if paused_at is not None:self.pressure_seconds+=time.monotonic()-paused_at

    def next_request(self,name,previous):
        try:request=read_json(self.directory/name)
        except FileNotFoundError:return None
        except (OSError,ValueError) as exc:
            write_json(self.directory/("background_result.json" if name.startswith("background") else "result.json"),dict(ok=False,id=None,code="invalid_request",error=str(exc)))
            self.exiting=True;return None
        if not isinstance(request,dict):
            self.exiting=True
            write_json(self.directory/("background_result.json" if name.startswith("background") else "result.json"),dict(ok=False,id=None,code="invalid_request",error="Request must be an object"))
            return None
        return request if request.get("id")!=previous else None

    def perform(self,request,background):
        if background:
            self.background_id=request.get("id");self.background_request=request
            self.background_superseded=False;self.background_checked=0.
        else:
            self.current=request.get("id");self.superseded=False;self.checked=0.
        context=None;created=None
        try:
            validate_request(request)
            if request["operation"] == "spectral_band_sequence" and self.spectral_cache is None:
                self.spectral_cache = SpectralCache(self.directory.parent)
            if request["operation"] == "spectral_reconstruct" and self.reconstruction_store is None:
                self.reconstruction_store = DenseReconstructionStore(
                    self.directory.with_name(self.directory.name+"-reconstruction"), registry_root=self.directory.parent)
            if request["operation"] == "spectral_reconstruct":
                self.reconstruction_store.clear()
                self.reconstruction_result_id = None
            if (request["operation"] in BACKGROUND_OPERATIONS)!=background:
                raise AnalysisError("invalid_lane","Fixed analysis uses the background lane; cursor/page work uses the interactive lane")
            if self.background_context is None:self.pool=SharedBudget(request.get("budget",{}).get("memory_bytes",512*MIB))
            context=Context(**request.get("budget",{}),pool=self.pool,
                            cancelled=self.background_cancelled if background else self.cancelled,
                            progress=self.background_progress if background else self.progress,
                            checkpoint=self.service_foreground if background else None)
            pins=list(request.get("result_pins",[]))
            if self.recent_result and self.recent_result not in pins:pins.append(self.recent_result)
            for reference in result_references([request.get("arguments",{}),self.background_request.get("arguments",{}) if self.background_request else {}]):
                if reference not in pins:pins.append(reference)
            if background:
                self.background_context=context
                # Collect between interval jobs; a cursor can never evict the
                # interval's open writer or its just-completed publication.
                self.results.collect(pins,context)
            retained=[self.background_request.get("arguments",{})] if self.background_context is not None and self.background_request else []
            if self.background_context is not None:retained.extend(self.background_context.retained_members)
            retained.extend(self.results.member_references(pins,context))
            result=execute(request,context=context,memo=self.memo,assets=self.assets,results=self.results,spectral_cache=self.spectral_cache,reconstruction_store=self.reconstruction_store,provenance=self.provenance,retained_members=retained,defer_publication=True)
            if request["operation"] in SOURCE_RESULT_OPERATIONS:created=result["data"]["result"]
            if background:self.background_checked=0.
            else:self.checked=0.
            context.check()
            result.update(memory=memory(),guard=self.guard,verification_memo=self.memo.metrics(),member_assets=self.assets.metrics(),shared_memory=dict(used=self.pool.used,peak=self.pool.peak,limit=self.pool.limit),playback_pressure=dict(pauses=self.pressure_pauses,seconds=self.pressure_seconds))
            if context is not None:result["metrics"]=context.metrics()
            context.verify_publication()
            context.commit_publications()
            if request["operation"] == "spectral_reconstruct":self.reconstruction_result_id=request["id"]
            if not self.exiting:write_json(self.directory/("background_result.json" if background else "result.json"),result)
            if created:self.recent_result=created
        except Exception as exc:
            if context is not None:context.abort_publications(exc)
            if request.get("operation") == "spectral_reconstruct" and self.reconstruction_store is not None:
                try:
                    self.reconstruction_store.clear()
                    self.reconstruction_result_id=None
                except Exception:pass # Unknown entries remain quarantined.
            if created:
                try:self.results.discard(created)
                except Exception:pass # Unknown files remain quarantined, never announced.
            result=dict(ok=False,id=request.get("id"),code=getattr(exc,"code","memory_limit" if isinstance(exc,MemoryError) else "analysis_error"),error=str(exc) or type(exc).__name__,
                        scene_revision=request.get("scene_revision"),selection_revision=request.get("selection_revision"),analysis_revision=request.get("analysis_revision",0),memory=memory(),guard=self.guard)
            if context is not None:result["metrics"]=context.metrics()
            if not self.exiting:write_json(self.directory/("background_result.json" if background else "result.json"),result)
        finally:
            if background:self.background_context=None;self.background_request=None

    def run(self):
        write_json(self.directory/"ready.json", dict(version=1, pid=os.getpid(), guard=self.guard, memory=memory()))
        try:
            while self.owner_alive() and not self.exiting:
                if (self.directory/"close").exists():
                    break
                release=self.directory/"reconstruction_release.json"
                if release.exists():
                    try:
                        value=read_json(release)
                        if self.reconstruction_store is not None and isinstance(value,dict):
                            self.reconstruction_store.release(value.get("manifest"))
                        release.unlink()
                    except (OSError,ValueError):pass
                # Cancellation can arrive after atomic publication but before
                # the viewer accepts the reply and learns its manifest path.
                # Retire only that completed request, never a newer result.
                if self.reconstruction_result_id is not None:
                    try:
                        cancel=read_json(self.directory/"background_cancel.json")
                        if isinstance(cancel,dict) and cancel.get("id")==self.reconstruction_result_id:
                            self.reconstruction_store.clear()
                            self.reconstruction_result_id=None
                    except (OSError,ValueError):pass
                request=self.next_request("request.json",self.current)
                if request is not None:self.perform(request,False);continue
                request=self.next_request("background_request.json",self.background_id)
                if request is not None:self.perform(request,True);continue
                time.sleep(.02)
        finally:
            if self.reconstruction_store is not None:self.reconstruction_store.close()
        write_json(self.directory/"stopped.json", dict(pid=os.getpid(),memory=memory()))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--directory",type=Path,required=True)
    p.add_argument("--owner-pid",type=int,required=True)
    p.add_argument("--assets-root",type=Path)
    a=p.parse_args()
    if not a.directory.is_absolute() or not a.directory.is_dir() or a.owner_pid < 1:
        p.error("Existing private job directory and owner PID required")
    if a.assets_root is not None and not a.assets_root.is_absolute():p.error("Member asset root must be absolute")
    Worker(a.directory,a.owner_pid,assets_root=a.assets_root).run()


if __name__ == "__main__":
    main()

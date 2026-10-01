"""Explicit common-schedule evaluations, retaining native support and policies."""
from contextlib import ExitStack,closing
import math
import numpy as np

from .contracts import AnalysisError,MIB,integer,request_float,float_token
from . import selectors as S
from .source import SourceSnapshot
from .sampling import source_bracket,mesh_compatible,world_positions
from .series_input import gap_policy
from .native_analysis import numeric


def schedule(join):
    S.keys(join,["mode","start","step","count"],["mode","start","step","count"])
    start=request_float(join["start"]);step=request_float(join["step"]);count=integer(join["count"],"schedule count",1,1_000_000)
    if step<=0:raise AnalysisError("invalid_schedule","Common schedule step must be positive")
    last=-math.inf
    for i in range(count):
        time=start+i*step
        if not math.isfinite(time) or time<=last:raise AnalysisError("invalid_schedule","Schedule is nonfinite or loses distinct float64 times")
        last=time;yield time


class Evaluation:
    """Two scalar result rows and tiny position endpoints, no full-series load."""
    def __init__(self,parent,description,manifest,cache,stack):
        from .comparisons import observations
        self.description=description;self.manifest=manifest;self.context=parent.context
        ref=description["source"]
        self.source=parent if ref==parent.identity() else stack.enter_context(SourceSnapshot(ref["path"],committed_bytes=ref["committed_bytes"],sha256=ref["sha256"],context=self.context,memo=parent.memo))
        self.rows=stack.enter_context(closing(observations(cache,description,self.context)))
        self.a=None;self.b=next(self.rows,None);self.first=self.b;self.gap,self.intervals=gap_policy(manifest)
        self.endpoints=None;self.endpoint_key=None
        self.definition=next((d for d in manifest.get("request",{}).get("selections",[]) if d["key"]==description["series"]["selection_key"]),None)
        self.obj=self.source.objects[self.definition["object"]] if self.definition else None
        self.position=bool(self.obj and self.obj["kind"] in ("particles","mesh") and manifest["request"]["mode"]=="trace" and description["series"]["channel"]=="position")
        self.channel=next((c for c in manifest.get("channels",{}).get(description["series"]["selection_key"],[]) if c["channel"]=="position" and str(c["component"])==description["series"]["component"]),None)
        if "mapping" not in manifest and not self.definition:raise AnalysisError("unsupported_schedule","Common schedules require original native analyses or supplied CSV, not interval/period/comparison outputs")
        if self.definition and manifest["request"]["mode"]=="interval_velocity":raise AnalysisError("unsupported_schedule","Interval velocity has interval support; use exact matching")

    def at(self,time):
        while self.b is not None and self.b["time"]<=time:
            self.a=self.b;self.b=next(self.rows,None)
        raw=(time+request_float(self.description["time"]["offset"]))/request_float(self.description["time"]["scale"])
        if not math.isfinite(raw):raise AnalysisError("invalid_schedule","Inverse time mapping overflow")
        basis=self.a or self.b
        if basis is None:return None
        row=dict(basis["row"]);result=dict(basis,row=row,time=time,observed_row=basis["row"])
        result["evaluation"]=dict(requested_native_time=float_token(raw),policy="explicit common schedule; scalar hold / source position interpolation",native_results=[self._support(v) for v in (self.a,self.b)])
        static=bool(self.obj and self.obj["static"])
        if static and self.a is None:self.a=self.b;self.b=next(self.rows,None);row=dict(self.a["row"]);result.update(self.a,row=row,time=time,observed_row=self.a["row"])
        reason=None
        if self.a is None:reason="before_input_range"
        elif self.b is None and time>self.a["time"] and not static:reason="after_input_range"
        elif any(a<=raw<=b for a,b in self.intervals):reason="declared_missing_interval"
        elif self.b is not None and time!=self.a["time"] and self.gap is not None and float(self.b["row"]["time"])-float(self.a["row"]["time"])>self.gap:reason="declared_gap"
        if reason:
            row.update(numeric(None,reason=reason),time_status="derived_evaluation");return result
        exact=time==self.a["time"]
        row["time_status"]="static" if static else "exact" if exact else "held"
        if self.definition:
            bracket=source_bracket(self.source,self.definition["object"],raw);result["evaluation"]["source_bracket"]=bracket
            if bracket.get("a")!=int(self.a["row"]["sample_index"]):
                row.update(numeric(None,reason="missing_native_support"));return result
            if self.position and not exact and not static and row["value_status"] not in ("unavailable","nonfinite") and row["value"]:
                value,status=self.position_value(bracket,self.a["row"])
                row.update(numeric(value,"derived" if status=="interpolated_by_id" else "held",None if value is not None else "nonfinite_support"),position_status=status)
        if not exact and row["value_status"] not in ("unavailable","nonfinite","derived"):
            row["value_status"]="held"
        return result

    @staticmethod
    def _support(value):
        if value is None:return None
        row=value["row"]
        return dict(result_row=str(value["result_row"]),sample_index=row["sample_index"],native_time=dict(text=row["time"],f64_le_hex=row["time_f64_le_hex"]),support_key=row["support_key"],value_status=row["value_status"])

    def position_value(self,bracket,row):
        key=(bracket["a"],bracket["b"],row["source_row"])
        if key!=self.endpoint_key:
            self.endpoints=self._position_endpoints(bracket,row);self.endpoint_key=key
        a,b,status=self.endpoints
        value=a if b is None else a+(b-a)*bracket["alpha"]
        if self.channel["coordinates"]=="viewer_world":value=world_positions(self.obj,value[None,:])[0]
        if not np.isfinite(value).all():return None,status
        component=self.channel["component"]
        return float(np.hypot.reduce(value)) if component=="magnitude" else float(value[component]),status

    def _position_endpoints(self,bracket,row):
        oid=self.definition["object"];index=int(row["source_row"]);kind=self.definition["kind"]
        with ExitStack() as stack:
            # Endpoint copies and comparison masks are charged before decoding.
            count=max(S._count(self.source.samples[oid][bracket[key]],"particle" if self.obj["kind"]=="particles" else "vertex") for key in ('a','b'))
            stack.enter_context(self.context.allocation(count*64+MIB))
            a=stack.enter_context(self.source.read_sample(oid,bracket["a"],["position"]))
            b=stack.enter_context(self.source.read_sample(oid,bracket["b"],["position"]))
            if kind=="mesh_point":
                bary=S.vector(self.definition["selector"]["barycentric"])
                av=np.asarray(a.arrays["position"][a.arrays["triangles"][index]],dtype=np.float64)
                pa=np.sum(av*bary[:,None],axis=0)
                if not np.isfinite(av).all():pa[:]=np.nan
            else:pa=np.asarray(a.arrays["position"][index],dtype=np.float64).copy()
            pb=None;status="held_unmatched"
            if self.obj["kind"]=="particles" and self.obj.get("identity")=="persistent_i8":
                identity=int(row["entity_id"])
                if int(a.arrays["particle_id"][index])!=identity:raise AnalysisError("source_changed","Stored position address no longer matches exact source ID")
                found=np.flatnonzero(b.arrays["particle_id"]==identity)
                if len(found):pb=np.asarray(b.arrays["position"][found[0]],dtype=np.float64).copy();status="interpolated_by_id"
            elif mesh_compatible(self.obj,a.arrays,b.arrays):
                if kind=="mesh_point":
                    bv=np.asarray(b.arrays["position"][b.arrays["triangles"][index]],dtype=np.float64);pb=np.sum(bv*bary[:,None],axis=0)
                    if not np.isfinite(bv).all():pb[:]=np.nan
                else:pb=np.asarray(b.arrays["position"][index],dtype=np.float64).copy()
                status="interpolated_by_id"
            return pa,pb,status

"""Explicit pairwise scalar correspondence, units and exact clock joins."""
from contextlib import ExitStack,closing
import hashlib
import math
import re

from .contracts import AnalysisError,MIB,float_token,request_float
from .source import SourceSnapshot
from .native_analysis import numeric
from .result_store import encoded,DEFAULT_RESULT_BYTES
from .series_input import selected_rows,validate_selector,semantic
from .period_jobs import verify_diagnostic
from .channel_semantics import unit
from . import selectors as S

POLICY="g4-explicit-two-series-1"


def mapping(value,*,time):
    S.keys(value,["units","reference","scale","offset","origin"],["units","reference"])
    reference=value["reference"]
    if not isinstance(reference,str) or not 1<=len(reference)<=256:raise AnalysisError("invalid_comparison","Declare a common time/value reference")
    scale=request_float(value.get("scale",1));offset=request_float(value.get("offset",0))
    if time and scale<=0 or not time and scale==0:raise AnalysisError("invalid_comparison","Time scales must be positive and value scales nonzero")
    origin=value.get("origin","declared native reference")
    if not isinstance(origin,str) or len(origin)>256:raise AnalysisError("invalid_comparison","Mapping origin must be descriptive text")
    return dict(units=unit(value["units"]),reference=reference,scale=float_token(scale),offset=float_token(offset),origin=origin,
                policy="aligned_time = raw_time*scale - offset" if time else "mapped_value = source_value*scale + offset")


def binding(cache,value,context,*,arithmetic=True):
    S.keys(value,["source","result","series","time","value"],["source","result","series","time","value"])
    validate_selector(value["series"])
    manifest=cache.manifest(value["result"],context)
    if value["source"]!=manifest.get("source"):raise AnalysisError("source_changed","Comparison result differs from the explicitly chosen source binding")
    restricted=semantic(manifest,value["series"]) in ("phase","categorical","identifier")
    if restricted and arithmetic:raise AnalysisError("unsupported_semantics","Differences/ratios require numeric continuous/signed quantities, not phase/categories/identity")
    description=dict(source=value["source"],result=value["result"],series=value["series"],time=mapping(value["time"],time=True),value=mapping(value["value"],time=False))
    if restricted and (request_float(description["value"]["scale"])!=1 or request_float(description["value"]["offset"])!=0):raise AnalysisError("unsupported_semantics","Phase/category/ID displays retain raw values without affine arithmetic")
    with closing(selected_rows(cache,value["result"],value["series"],context)) as rows:
        first=next(rows,None)
        if first is None:raise AnalysisError("unknown_series","Explicit comparison series has no observations")
        row=first[1]
        original={"time":manifest.get("clocks",{}).get(row["clock"],{}).get("time_units","unknown"),"value":row["units"]}
        for part in ("time","value"):
            if original[part]!=description[part]["units"] and "scale" not in value[part]:raise AnalysisError("incompatible_units","Changing or declaring unknown units requires an explicit scale mapping")
    return description,manifest


def verify_binding(parent,description,manifest):
    ref=description["source"]
    if ref==parent.identity():parent.verify()
    else:
        with SourceSnapshot(ref["path"],committed_bytes=ref.get("committed_bytes"),sha256=ref.get("sha256"),context=parent.context,memo=parent.memo) as source:
            if source.identity()!=ref:raise AnalysisError("source_changed","Comparison source binding changed")
    verify_diagnostic(manifest,parent.context)


def observations(cache,description,context):
    prior=-math.inf;clock=units=None
    scale=request_float(description["time"]["scale"]);offset=request_float(description["time"]["offset"])
    with closing(selected_rows(cache,description["result"],description["series"],context)) as rows:
        for index,row in rows:
            if row["time_status"] in ("index_only","derived_lag"):raise AnalysisError("index_only","A common physical clock requires native times, not record index or lag")
            time=float(row["time"])*scale-offset
            if not math.isfinite(time) or time<=prior:raise AnalysisError("invalid_comparison","Mapped times are nonfinite or collapse native ordering; no sorting or rounding join")
            prior=time
            if clock is not None and (clock!=row["clock"] or units!=row["units"]):raise AnalysisError("incompatible_series","An input series mixes source clocks or units")
            clock,units=row["clock"],row["units"]
            yield dict(row=row,result_row=index,time=time)


def mapped_value(observation,description):
    if observation is None:return None,"unmatched_time"
    row=observation["row"]
    if not row["value"] or row["value_status"] in ("unavailable","nonfinite"):return None,row["reason"] or "unavailable_input"
    raw=int(row["value"]) if not row["value_f64_le_hex"] and re.fullmatch(r"-?[0-9]+",row["value"]) else float(row["value"])
    scale=request_float(description["value"]["scale"]);offset=request_float(description["value"]["offset"])
    if scale==1 and offset==0:return raw,None
    value=float(raw)*scale+offset
    return (value,None) if math.isfinite(value) else (None,"arithmetic_overflow")


def input_support(value,description):
    if value is None:return dict(status="unmatched_time",source=description["source"],result=description["result"])
    row=value["row"];observed=value.get("observed_row",row)
    return dict(source=description["source"],result=description["result"],result_row=str(value["result_row"]),source_row=row["source_row"],sample_index=row["sample_index"],sequence=row["sequence"],evaluation=value.get("evaluation"),
                native_time=dict(text=row["time"],f64_le_hex=row["time_f64_le_hex"]),aligned_time=float_token(value["time"]),source_value=observed["value"],source_value_f64_le_hex=observed["value_f64_le_hex"],evaluation_value=row["value"],evaluation_value_f64_le_hex=row["value_f64_le_hex"],
                source_units=row["units"],time_status=row["time_status"],position_status=row["position_status"],value_status=row["value_status"],reason=row["reason"],source_support_key=row["support_key"])


def run(source,arguments,cache,*,provenance=None):
    with source.context.allocation(32*MIB):return _run(source,arguments,cache,provenance=provenance)


def _run(source,arguments,cache,*,provenance=None):
    S.keys(arguments,["left","right","operation","join","result_bytes"],["left","right","operation","join"])
    operation=arguments["operation"]
    if operation not in ("difference","ratio"):raise AnalysisError("invalid_comparison","Choose explicit left-minus-right or left-over-right")
    from .scheduled_series import schedule,Evaluation
    join=arguments["join"];scheduled=join.get("mode")=="schedule"
    if scheduled:
        count=sum(1 for _ in schedule(join))
    else:
        S.keys(join,["mode"],["mode"])
        if join["mode"]!="exact":raise AnalysisError("unsupported_join","Choose exact or an explicit common schedule")
    context=source.context;left,lm=binding(cache,arguments["left"],context);right,rm=binding(cache,arguments["right"],context)
    if source.identity() not in (left["source"],right["source"]):raise AnalysisError("invalid_comparison","Primary opened source must be one of the explicit comparison bindings")
    for part in ("time","value"):
        if any(left[part][k]!=right[part][k] for k in ("units","reference")):raise AnalysisError("incompatible_units","Declare the same target units and reference on both comparison inputs")
    from .input_provenance import verify_inputs
    verify_inputs(source,cache,[left["result"],right["result"]])
    if not scheduled:
        count=0
        for description in (left,right):
            for _ in observations(cache,description,context):count+=1
    manifest=dict(algorithm=POLICY,source=source.identity(),inputs=[left,right],operation=operation,join=arguments["join"],provenance=provenance or {},clocks={},
                  identity_policy="explicit source/selection correspondence only; identical ID text across runs establishes no automatic match",precision="exact integer identity mappings/differences within signed128; explicit conversions and ratios float64",
                  input_algorithms=[lm.get("algorithm"),rm.get("algorithm")],input_precision=[lm.get("precision"),rm.get("precision")])
    semantic_input=[dict(d,result=dict(manifest_sha256=d["result"]["manifest_sha256"])) for d in (left,right)]
    result_key=hashlib.sha256(encoded(dict(policy=POLICY,inputs=semantic_input,operation=operation,join=arguments["join"],provenance=provenance or {}))).hexdigest()
    clock="comparison:"+result_key;manifest["clocks"][clock]=dict(axis="native_time",time_units=left["time"]["units"],reference=left["time"]["reference"])
    with cache.begin(manifest,expected_rows=count,expected_support=count,byte_limit=arguments.get("result_bytes",DEFAULT_RESULT_BYTES),context=context) as writer,ExitStack() as stack:
        if scheduled:
            a=Evaluation(source,left,lm,cache,stack);b=Evaluation(source,right,rm,cache,stack)
            pairs=((time,a.at(time),b.at(time)) for time in schedule(join))
        else:pairs=exact_pairs(cache,left,right,context)
        pairs=stack.enter_context(closing(pairs));index=0
        for time,av,bv in pairs:
            context.check();context.progress("scheduled_comparison" if scheduled else "exact_comparison",index,count)
            x,xreason=mapped_value(av,left);y,yreason=mapped_value(bv,right);value=None
            reason="left:"+xreason if xreason else "right:"+yreason if yreason else None
            if reason is None:
                if operation=="ratio" and y==0:reason="zero_denominator"
                else:
                    value=x-y if operation=="difference" else x/y
                    if isinstance(value,int) and not -(2**127)<=value<2**127 or isinstance(value,float) and not math.isfinite(value):value=None;reason="arithmetic_overflow"
            key="s"+str(index);token=float_token(time)
            writer.append(dict(key=key,left=input_support(av,left),right=input_support(bv,right),time_mapping=[left["time"],right["time"]],value_mapping=[left["value"],right["value"]]),kind="support")
            writer.append(dict(result_id=result_key,selection_key="comparison",selection_revision="1",source_key=source.sha256,object="comparison",association="paired_series",member_key="",clock=clock,sample_index=str(index),sequence=str(index),
                               time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],channel=operation,component="",statistic=operation,source_dtype="i128" if isinstance(value,int) else "f8",units=left["value"]["units"] if operation=="difference" else "1",
                               time_status="derived_evaluation" if scheduled else "exact_join",position_status="not_applicable",support_key=key)|numeric(value,"derived",reason))
            index+=1
        verify_inputs(source,cache,[left["result"],right["result"]])
        reference=writer.finish()
    return dict(result=reference,row_count=index,support_count=index,algorithm=POLICY)


def exact_pairs(cache,left,right,context):
    with closing(observations(cache,left,context)) as a,closing(observations(cache,right,context)) as b:
        aa=next(a,None);bb=next(b,None)
        while aa is not None or bb is not None:
            time=min(aa["time"] if aa else math.inf,bb["time"] if bb else math.inf)
            av=aa if aa is not None and aa["time"]==time else None;bv=bb if bb is not None and bb["time"]==time else None
            yield time,av,bv
            if av is not None:aa=next(a,None)
            if bv is not None:bb=next(b,None)

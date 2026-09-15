"""Stream exploratory period evidence from immutable full scientific rows."""
from contextlib import ExitStack
import hashlib
import math
import numpy as np

from .contracts import AnalysisError,MIB,float_token,request_float
from .result_store import encoded,DEFAULT_RESULT_BYTES
from .native_analysis import numeric,sample_range,POLICY as NATIVE_POLICY
from .series_input import load,selected_rows
from .periods import analyze,parameters,POLICY
from .diagnostics import Input
from . import selectors as S


def verify_diagnostic(manifest,context):
    if "diagnostic_source" not in manifest:return
    ref=manifest["diagnostic_source"]
    with Input(ref["path"],context) as source:
        if source.sha256!=ref["sha256"] or str(source.stamp[2])!=ref["bytes"]:raise AnalysisError("source_changed","Diagnostic source differs from the stored input result")


def run(source,arguments,cache,*,provenance=None):
    S.keys(arguments,["result","series","window","options","result_bytes"],["result","series","window","options"])
    window=arguments["window"]
    if not isinstance(window,list) or len(window)!=2 or request_float(window[0])>request_float(window[1]):raise AnalysisError("invalid_period","Choose an explicit [start,end] native window")
    options=parameters(arguments["options"]);context=source.context
    input_manifest=cache.manifest(arguments["result"],context)
    if input_manifest.get("source")!=source.identity():raise AnalysisError("source_changed","Period input belongs to another explicitly opened source binding")
    from .input_provenance import verify_inputs
    verify_inputs(source,cache,[arguments["result"]])
    full_label="full_run" if "mapping" in input_manifest and "diagnostic_source" in input_manifest else "full_input_range"
    if input_manifest.get("algorithm")==NATIVE_POLICY:
        definition=next((d for d in input_manifest["request"]["selections"] if d["key"]==arguments["series"]["selection_key"]),None)
        if definition:
            records=source.samples[definition["object"]]
            if sample_range(records,input_manifest["request"]["range"])==range(len(records)):full_label="full_run"
    full_count=0;first=last=None
    for _,row in selected_rows(cache,arguments["result"],arguments["series"],context):
        if row["time_status"] in ("index_only","derived_lag"):raise AnalysisError("index_only","Period input requires a physical native time axis, not record index or lag")
        full_count+=1
        if full_count>1_000_000:raise AnalysisError("memory_limit","Full-run period comparison exceeds one million observations")
        time=float(row["time"])
        if first is None:first=time
        last=time
    manifest=dict(algorithm=POLICY,source=source.identity(),inputs=[dict(result=arguments["result"],series=arguments["series"])],request=arguments,
                  provenance=provenance or {},clocks={},period_windows=[],interpretation="exploratory descriptive estimates; no physical events or automatic bookmarks",precision="float64 diagnostic arithmetic; exact source rows remain in the input result")
    if "diagnostic_source" in input_manifest:manifest["diagnostic_source"]=input_manifest["diagnostic_source"]
    result_key=hashlib.sha256(encoded(manifest)).hexdigest()
    # Full-run and selected-window evidence are separate, never pooled. A
    # conservative row estimate can refuse before FFTs or exact peak work.
    resampled=full_count
    if full_count and options["hold_cadence"]:
        resampled=max(full_count,min(1_000_001,int((last-first)/options["hold_cadence"])+1))
        if resampled>1_000_000:raise AnalysisError("memory_limit","Resampled period output exceeds one million observations")
    expected=full_count*4+resampled*2+2048
    with cache.begin(manifest,expected_rows=expected,expected_support=full_count+resampled*2+2048,byte_limit=arguments.get("result_bytes",DEFAULT_RESULT_BYTES),context=context) as writer:
        for label,bounds in ((full_label,None),("selected_window",window)):
            with load(cache,arguments["result"],arguments["series"],context,window=bounds) as data,ExitStack() as stack:
                count=len(data["times"]);resampled=count
                if count and options["hold_cadence"]:
                    resampled=max(count,min(1_000_001,int((data["times"][-1]-data["times"][0])/options["hold_cadence"])+1))
                if resampled>1_000_000:raise AnalysisError("memory_limit","Resampled period workspace exceeds one million observations")
                stack.enter_context(context.allocation(max(0,resampled-count)*64+MIB))
                result=analyze(data["times"],data["values"],data["valid"],data["breaks"],arguments=arguments["options"],context=context)
                clock=str(data["clock"])+":period:"+label
                manifest["clocks"][clock]=dict(axis="native_time",time_units=data["time_units"],input_clock=data["clock"])
                manifest["clocks"][clock+":lag"]=dict(axis="lag",time_units=data["time_units"],input_clock=data["clock"])
                manifest["period_windows"].append(dict(label=label,range=bounds,finite_count=result["finite_count"],missing_count=result["missing_count"],segments=len(result["segments"]),status="evaluated" if result["segments"] else "empty_support"))
                for segment_index,segment in enumerate(result["segments"]):
                    key=f"{label}-segment-{segment_index}";start=segment["start_index"];end=segment["end_index"]
                    detail={k:v for k,v in segment.items() if not isinstance(v,np.ndarray)}
                    writer.append(dict(key=key,window=label,**detail,input_result=arguments["result"],input_series=arguments["series"],source_first_row=str(int(data["offsets"][start])),source_last_row=str(int(data["offsets"][end]))),kind="support")
                    time=data["times"][start]+(data["times"][end]-data["times"][start])/2;token=float_token(time)
                    base=dict(result_id=result_key,selection_key=arguments["series"]["selection_key"]+"-"+label,selection_revision="1",source_key=source.sha256,object="period_diagnostic",association="diagnostic_segment",clock=clock,
                              sample_index=str(segment_index),sequence=str(segment_index),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],channel=arguments["series"]["channel"],component=arguments["series"]["component"],
                              units=data["time_units"],source_dtype="f8",time_status="derived_window",position_status="not_applicable",support_key=key)
                    writer.append(base|dict(statistic="exploratory_period")|numeric(segment["candidate"],segment["status"],segment["reason"]))
                    for i,(peak,prominence) in enumerate(zip(segment["peak_indices"],segment["peak_prominence"])):
                        native=start+int(peak);token=float_token(data["times"][native]);source_row=int(data["offsets"][native])
                        writer.append(base|dict(member_key=key,statistic="observed_peak_prominence",sample_index=str(i),source_row=str(source_row),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],units=data["units"],time_status="observed_peak")|numeric(prominence,"derived"))
                        if i:
                            earlier=start+int(segment["peak_indices"][i-1]);interval_key=key+"-interval-"+str(i)
                            writer.append(dict(key=interval_key,input_result=arguments["result"],source_rows=[str(int(data["offsets"][earlier])),str(source_row)],source_times=[float_token(data["times"][earlier]),token],policy="interval between consecutive observed peaks inside one finite segment"),kind="support")
                            writer.append(base|dict(member_key=key,statistic="observed_peak_interval",sample_index=str(i-1),source_row=str(source_row),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],time_status="derived_interval",support_key=interval_key)|numeric(data["times"][native]-data["times"][earlier],"derived"))
                    for i,(lag,value) in enumerate(zip(segment["lag_times"],segment["acf"])):
                        token=float_token(lag)
                        writer.append(base|dict(member_key=key,statistic="autocorrelation",sample_index=str(i),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],units="1",time_status="derived_lag",clock=clock+":lag")|numeric(value,"derived"))
                    if "resampled_rows" in segment:
                        for time,row in zip(segment["resampled_times"],segment["resampled_rows"]):
                            native=start+int(row)
                            writer.append(dict(key=key+"-hold",input_result=arguments["result"],source_row=str(int(data["offsets"][native])),source_time=float_token(data["times"][native]),evaluation_time=float_token(time),status="exact" if time==data["times"][native] else "held"),kind="support")
        verify_inputs(source,cache,[arguments["result"]]);source.verify()
        reference=writer.finish()
    return dict(result=reference,row_count=writer.counts["rows"],support_count=writer.counts["support"],algorithm=POLICY)

"""Bounded scalar scientific series for diagnostics, never plot envelopes."""
from contextlib import closing,contextmanager
import math
import numpy as np

from .contracts import AnalysisError,MIB,request_float
from .plot_preview import KEYS
from . import selectors as S


def validate_selector(selector):
    S.keys(selector,KEYS,KEYS)
    if any(not isinstance(v,str) or len(v)>256 for v in selector.values()):raise AnalysisError("invalid_series","Malformed scalar-series selector")


def selected_rows(cache,reference,selector,context):
    validate_selector(selector)
    with closing(cache.rows(reference,context)) as rows:
        for offset,row in rows:
            if all(row[k]==selector[k] for k in KEYS):yield offset,row


def semantic(manifest,selector):
    if "mapping" in manifest:
        for column in manifest["mapping"]["values"]:
            if column["column"]==selector["channel"]:return column["semantic"]
    for channel in manifest.get("channels",{}).get(selector["selection_key"],[]):
        if channel["channel"]==selector["channel"]:return channel["semantic"]
    return "continuous"


def gap_policy(manifest):
    mapping=manifest.get("mapping",manifest.get("request",{}))
    gap=request_float(mapping["max_gap"]) if mapping.get("max_gap") is not None else None
    intervals=[[request_float(a),request_float(b)] for a,b in mapping.get("missing_intervals",[])]
    return gap,intervals


@contextmanager
def load(cache,reference,selector,context,*,window=None):
    validate_selector(selector);manifest=cache.manifest(reference,context)
    if semantic(manifest,selector) in ("phase","categorical","identifier"):
        raise AnalysisError("unsupported_semantics","Period arithmetic requires a continuous/signed series, not phase/categories/identity")
    lower,upper=(-math.inf,math.inf) if window is None else (request_float(window[0]),request_float(window[1]))
    if upper<lower:raise AnalysisError("invalid_range","Analysis window is reversed")
    count=0;units=clock=None;previous=-math.inf
    for _,row in selected_rows(cache,reference,selector,context):
        if row["time_status"]=="index_only":raise AnalysisError("index_only","Temporal arithmetic requires an increasing finite native time axis")
        time=float(row["time"])
        if not math.isfinite(time) or time<=previous:raise AnalysisError("index_only","Series axis is not increasing and finite; no sorting")
        previous=time
        if not lower<=time<=upper:continue
        if units is not None and (units!=row["units"] or clock!=row["clock"]):raise AnalysisError("incompatible_series","One scalar series cannot mix clocks or units")
        units,clock=row["units"],row["clock"];count+=1
        if count>1_000_000:raise AnalysisError("memory_limit","Exploratory scalar workspace is limited to one million observations; choose a smaller explicit window")
    with context.allocation(count*96+MIB):
        times=np.empty(count);values=np.empty(count);valid=np.zeros(count,dtype=bool);offsets=np.empty(count,dtype=np.int64);breaks=np.zeros(count,dtype=bool)
        gap,intervals=gap_policy(manifest);i=0;previous_index=None
        for offset,row in selected_rows(cache,reference,selector,context):
            time=float(row["time"])
            if not lower<=time<=upper:continue
            times[i]=time;offsets[i]=offset
            values[i]=float(row["value"]) if row["value"] else np.nan
            valid[i]=math.isfinite(values[i]) and row["value_status"] not in ("unavailable","nonfinite")
            native_index=int(row["sample_index"])
            if i:
                breaks[i]=not valid[i-1] or not valid[i] or (previous_index is not None and native_index!=previous_index+1) or (gap is not None and time-times[i-1]>gap) or any(times[i-1]<=b and time>=a for a,b in intervals)
            previous_index=native_index;i+=1
        yield dict(times=times,values=values,valid=valid,breaks=breaks,offsets=offsets,manifest=manifest,units=units or "unknown",clock=clock,
                   time_units=manifest.get("clocks",{}).get(clock,{}).get("time_units","unknown"),precision="float64 diagnostic arithmetic; integer conversions may round above 2^53")

"""Bounded native scatter/min-max previews. Scientific exports use full rows."""
from contextlib import closing
from decimal import Decimal,localcontext,InvalidOperation
import math

from .contracts import AnalysisError,MIB,MAX_CONTROL,integer
from .result_store import encoded
from . import selectors as S

KEYS=("selection_key","channel","component","statistic","member_key")


def descriptor(row):return {k:row[k] for k in KEYS}


def series(cache,reference,context):
    seen=set();items=[];more=False
    with closing(cache.rows(reference,context)) as rows:
        for _,row in rows:
            key=tuple(row[k] for k in KEYS)
            if key in seen:continue
            if len(items)==16:more=True;break
            seen.add(key);items.append(dict(series=descriptor(row),units=row["units"],clock=row["clock"],source_dtype=row["source_dtype"]))
    return dict(series=items,more=more,limit=16,policy="first 16 series in result traversal; use an explicit member address for others")


def preview(cache,reference,selection,context,*,bins=512):
    S.keys(selection,KEYS,KEYS)
    if any(not isinstance(selection[k],str) or len(selection[k])>256 for k in KEYS):raise AnalysisError("invalid_series","Malformed series selector")
    bins=integer(bins,"plot bins",1,2048)
    with context.allocation(8*MIB),localcontext() as decimal_context:
        # Decimal coordinates preserve integer differences above 2^53 and avoid
        # overflow on large finite f64 axis spans. Full row strings stay exact.
        decimal_context.prec=50
        minimum=maximum=xlow=xhigh=None;count=finite=missing=0;units=clock=axis=None
        for pass_index in range(2):
            if pass_index:envelope=[None]*bins
            with closing(cache.rows(reference,context)) as rows:
                for offset,row in rows:
                    if any(row[k]!=selection[k] for k in KEYS):continue
                    context.progress("plot_preview",offset,0)
                    row_axis="record_index" if row["time_status"]=="index_only" else "lag" if row["time_status"]=="derived_lag" else "native_time"
                    if units is not None and (row["units"]!=units or row["clock"]!=clock or row_axis!=axis):
                        raise AnalysisError("incompatible_series","A plot series cannot silently mix clocks, units or time axes")
                    units,clock,axis=row["units"],row["clock"],row_axis
                    try:
                        x=Decimal(row["sample_index"] if axis=="record_index" else row["time"])
                        y=Decimal(row["value"]) if row["value"] else None
                    except InvalidOperation as exc:raise AnalysisError("invalid_result","Malformed scientific number in result") from exc
                    if not x.is_finite():raise AnalysisError("index_only","Invalid native axis requires explicit index-only rows")
                    valid=y is not None and y.is_finite() and row["value_status"] not in ("unavailable","nonfinite")
                    if not pass_index:
                        count+=1;finite+=int(valid);missing+=int(not valid)
                        xlow=x if xlow is None else min(xlow,x);xhigh=x if xhigh is None else max(xhigh,x)
                        if valid:minimum=y if minimum is None else min(minimum,y);maximum=y if maximum is None else max(maximum,y)
                        continue
                    index=min(bins-1,int((x-xlow)/(xhigh-xlow)*bins)) if xhigh>xlow else 0
                    if envelope[index] is None:envelope[index]=dict(bin=index,finite=0,missing=0)
                    cell=envelope[index]
                    if not valid:cell["missing"]+=1;continue
                    point=[str(x),row["value"],str(offset)]
                    cell["finite"]+=1
                    if "first" not in cell:cell.update(first=point,min=point,max=point)
                    cell["last"]=point
                    if y<Decimal(cell["min"][1]):cell["min"]=point
                    if y>Decimal(cell["max"][1]):cell["max"]=point
            if not pass_index and not count:raise AnalysisError("unknown_series","Requested series has no result rows")
        result=dict(series=selection,units=units,clock=clock,axis=axis,count=count,finite=finite,missing=missing,
                    bin_count=bins,time_units=cache.manifest(reference,context).get("clocks",{}).get(clock,{}).get("time_units","unknown"),
                    x_range=[str(xlow),str(xhigh)],y_range=[str(minimum),str(maximum)] if minimum is not None else None,
                    bins=[v for v in envelope if v is not None],policy="display-only native scatter/min-max bins; no temporal connecting lines or gap filling",full_result=reference)
        # Coordinates sent to the canvas are normalized after exact subtraction.
        for cell in result["bins"]:
            for key in ("first","last","min","max"):
                if key in cell:
                    point=cell[key][:3];cell[key]=point;x,y=Decimal(point[0]),Decimal(point[1])
                    point.extend([float((x-xlow)/(xhigh-xlow)) if xhigh>xlow else .5,float((y-minimum)/(maximum-minimum)) if maximum>minimum else .5])
        if len(encoded(result))>MAX_CONTROL-16384:raise AnalysisError("control_limit","Plot envelope exceeds the control budget; request fewer bins")
        return result

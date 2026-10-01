"""Bounded space-time extrema raster, never the full scientific output."""
from decimal import Decimal,localcontext
import math,re
import numpy as np

from .contracts import AnalysisError,MIB,MAX_CONTROL,integer,float_token
from .result_store import encoded
from .space_time import POLICY
from . import selectors as S

DTYPE=np.dtype([('low','<f4'),('high','<f4'),('finite','<u4'),('missing','<u4')])


def preview(cache,arguments,context):
    S.keys(arguments,['result','width','height'],['result'])
    width=integer(arguments.get('width',128),'heatmap width',1,1024);height=integer(arguments.get('height',64),'heatmap height',1,512)
    if width*height>16384:raise AnalysisError('preview_limit','Inline heatmap is limited to 16384 display pixels within 1024 by 512; reduce display dimensions')
    with context.allocation(24*MIB),localcontext() as dc:
        dc.prec=50;manifest=cache.manifest(arguments['result'],context)
        if manifest.get('algorithm')!=POLICY:raise AnalysisError('invalid_result','Heatmap requires a full native space-time result')
        bins=manifest['spatial']['bins'];width=min(width,bins);tlow=thigh=vlow=vhigh=None;axis=next(iter(manifest['clocks'].values()))['axis'];count=0
        for _,row in cache.rows(arguments['result'],context):
            time=Decimal(row['sample_index'] if axis=='record_index' else row['time'])
            if not time.is_finite():raise AnalysisError('invalid_result','Nonfinite space-time axis')
            tlow=time if tlow is None else min(tlow,time);thigh=time if thigh is None else max(thigh,time)
            value=Decimal(row['value']) if row['value'] else None
            if value is not None and value.is_finite() and row['value_status'] not in ('unavailable','nonfinite'):
                vlow=value if vlow is None else min(vlow,value);vhigh=value if vhigh is None else max(vhigh,value)
            count+=1
        if not count:raise AnalysisError('unknown_series','Space-time result has no native observations')
        raster=np.zeros((height,width),dtype=DTYPE);raster['low']=1;time_rows={}
        # Each source bin contributes exactly once. Extrema are normalized only
        # after Decimal subtraction; validity/counts are separate typed lanes.
        for _,row in cache.rows(arguments['result'],context):
            context.check();match=re.fullmatch(r'bin:([0-9]+)',row['member_key'])
            if match is None or int(match[1])>=bins:raise AnalysisError('invalid_result','Malformed spatial-bin address')
            column=min(width-1,int((int(match[1])+.5)/bins*width))
            time=Decimal(row['sample_index'] if axis=='record_index' else row['time'])
            y=min(height-1,int((time-tlow)/(thigh-tlow)*height)) if thigh>tlow else 0
            details=time_rows.setdefault(y,dict(row=y,first_time=str(time),last_time=str(time),first_index=row['sample_index'],last_index=row['sample_index'],native_records=0))
            if details['native_records']==0 or details['last_index']!=row['sample_index']:details['native_records']+=1
            details['last_time']=str(time);details['last_index']=row['sample_index']
            value=Decimal(row['value']) if row['value'] else None
            valid=value is not None and value.is_finite() and row['value_status'] not in ('unavailable','nonfinite')
            cell=raster[y,column]
            if valid:
                value=float((value-vlow)/(vhigh-vlow)) if vhigh>vlow else .5
                cell['low']=min(float(cell['low']),value);cell['high']=max(float(cell['high']),value);cell['finite']+=1
            else:cell['missing']+=1
        for row in time_rows.values():
            row['normalized_first']=float((Decimal(row['first_time'])-tlow)/(thigh-tlow)) if thigh>tlow else .5
            row['normalized_last']=float((Decimal(row['last_time'])-tlow)/(thigh-tlow)) if thigh>tlow else .5
        result=dict(result=arguments['result'],width=width,height=height,pixels=raster.tobytes().hex(),pixel_schema='little-endian f4 min/max normalized; u4 finite/missing count (16 bytes)',
                    value_range=[str(vlow),str(vhigh)] if vlow is not None else None,time_range=[str(tlow),str(thigh)],axis=axis,time_units=next(iter(manifest['clocks'].values()))['time_units'],units=manifest['units'],spatial=manifest['spatial'],
                    native_rows=list(time_rows.values()),full_bin_values=count,value_origin=manifest['value_origin'],gap_policy=manifest['gap_policy'],
                    policy='display-only source extrema and missing counts; native times map to actual coordinates; coalesced rows span only their occupied pixel, no temporal interpolation/held extension; full bins remain in result')
        if len(encoded(result))>MAX_CONTROL-16384:raise AnalysisError('control_limit','Heatmap metadata exceeds control budget; reduce display dimensions')
        return result

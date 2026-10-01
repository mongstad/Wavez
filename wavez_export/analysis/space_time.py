"""Native-clock line probes, whole-cell slab quadrature and tracer histograms."""
from contextlib import ExitStack
import hashlib,math
import numpy as np

from .contracts import AnalysisError,MIB,MAX_CONTROL,float_token,integer,request_float
from . import selectors as S,channel_semantics as U
from .sampling import valid_axis,probe_array,world_positions
from .quadrature import cell_batches,grid_geometry,POLICY as QUADRATURE
from .native_analysis import numeric,sample_range,component_values,association_of
from .reductions import Neumaier,statistics
from .result_store import encoded,DEFAULT_RESULT_BYTES

POLICY="g4-native-space-time-1"


def spatial(spec):
    S.keys(spec,["start","end","bins","space","units","slab"],["start","end","bins","space","units"])
    start,end=S.vector(spec["start"]),S.vector(spec["end"]);bins=integer(spec["bins"],"spatial bins",1,16384)
    delta=end-start;length=float(np.hypot.reduce(delta))
    if not math.isfinite(length) or length<=0:raise AnalysisError("invalid_spatial","Spatial axis requires finite distinct endpoints")
    if spec["space"] not in ("data_local","viewer_world"):raise AnalysisError("invalid_spatial","Declare local or viewer-world coordinates")
    slab=S.region(spec["slab"]) if "slab" in spec else None
    if slab and slab["shape"]!="slab":raise AnalysisError("invalid_spatial","Spatial slab must be a finite rectangular slab")
    edges=np.linspace(0,length,bins+1)
    if np.any(edges[1:]<=edges[:-1]):raise AnalysisError("invalid_spatial","Spatial bins lose float64 separation")
    description=dict(start=S.tokens(start),end=S.tokens(end),bins=bins,space=spec["space"],units=U.unit(spec["units"]),slab=slab,
                     bin_edges=dict(policy="float64 linspace from zero to axis length; exact evaluated lower/upper edges saved per support row",length=float_token(length),count=bins+1),
                     boundary="lower inclusive, upper exclusive, final upper inclusive; projections outside [start,end] excluded")
    return description,start,delta/length,edges


def addresses(positions,start,direction,edges):
    with np.errstate(over="ignore",invalid="ignore"):distance=(positions-start)@direction
    valid=np.isfinite(positions).all(axis=1)&np.isfinite(distance)&(distance>=edges[0])&(distance<=edges[-1])
    indices=np.searchsorted(edges,np.where(valid,distance,0),side="right")-1
    indices=np.minimum(indices,len(edges)-2)
    return indices,valid


def line_values(source,sample,obj,channel,description,start,direction,edges):
    for i in range(len(edges)-1):
        source.context.check();coordinate=start+direction*(edges[i]/2+edges[i+1]/2)
        world=world_positions(obj,coordinate[None,:])[0] if description["space"]=="data_local" else coordinate
        value=probe_array(sample.arrays[channel["channel"]],sample.record["descriptor"]["geometry"],obj["data_to_world"],world)
        yield value["value"],value["status"],value.get("reason"),dict(sample_coordinate=S.tokens(coordinate),source_world_coordinate=S.tokens(world),selected_support=1,finite_support=int(value["value"] is not None),source_interpolation="G3 trilinear; any invalid corner invalidates support")


def slab_values(source,sample,obj,channel,description,start,direction,edges,reducer):
    bins=len(edges)-1;context=source.context;values=sample.arrays[channel["channel"]];geometry=sample.record["descriptor"]["geometry"]
    _,measure=grid_geometry(values,geometry,obj)
    with context.allocation(bins*512+MIB):
        counts=np.zeros(bins,dtype=np.int64);finite=counts.copy();totals=[Neumaier() for _ in range(bins)]
        for positions,cell_values,valid,_,_ in cell_batches(values,geometry,obj,description["space"],context):
            assigned,inside=addresses(positions,start,direction,edges);inside &= S.inside(positions,description["slab"])
            for j in np.flatnonzero(inside):
                i=int(assigned[j]);counts[i]+=1
                if valid[j]:finite[i]+=1;totals[i].add(cell_values[j])
        for i in range(bins):
            context.check();reason="empty_support" if counts[i]==0 else "nonfinite_support" if finite[i]!=counts[i] else None
            if not math.isfinite(int(counts[i])*measure):raise AnalysisError("arithmetic_overflow","Selected spatial-bin volume is not representable")
            value=None if reason else totals[i].value()*measure if reducer=="integral" else totals[i].value()/int(counts[i])
            if value is not None and not math.isfinite(value):value=None;reason="arithmetic_overflow"
            yield value,"derived",reason,dict(selected_support=int(counts[i]),finite_support=int(finite[i]),invalid_support=int(counts[i]-finite[i]),world_cell_volume=float_token(measure),selected_volume=float_token(int(counts[i])*measure),valid_volume=float_token(int(finite[i])*measure),quadrature=QUADRATURE,centering=geometry["centering"],boundary="whole original cells selected by center; no fractional clipping")


def tracer_values(source,sample,index,obj,channel,description,start,direction,edges,reducer,selection,weight):
    context=source.context;count=len(sample.arrays["position"]);bins=len(edges)-1
    with context.allocation(count*192+bins*64+MIB):
        positions=sample.arrays["position"]
        if description["space"]=="viewer_world":positions=world_positions(obj,positions)
        indices,valid=addresses(positions,start,direction,edges)
        if description["slab"]:valid &= S.inside(positions,description["slab"])
        membership_support={}
        if selection:
            membership=S.resolve(source,selection,index,sample)
            membership_support=dict(cohort_selected=membership.selected,cohort_present=membership.present,predicate_unknown=membership.unknown,membership_status=membership.status,membership_reason=membership.reason)
            eligible=np.zeros(count,dtype=bool);eligible[membership.rows]=True;valid &= eligible
        selected=np.flatnonzero(valid);order=np.argsort(indices[selected],kind="stable");rows=selected[order];ordered_bins=indices[rows]
        values=component_values(sample,obj,channel) if channel else None;weights=component_values(sample,obj,weight) if weight else None
        invalid_positions=int(np.count_nonzero(~np.isfinite(positions).all(axis=1)))
        for i in range(bins):
            context.check();begin,end=np.searchsorted(ordered_bins,[i,i+1]);members=rows[begin:end];support=dict(selected_support=len(members),invalid_positions=invalid_positions)|membership_support
            if reducer=="count":yield int(len(members)),"derived",None,support|dict(finite_support=len(members));continue
            if values is None:yield None,"unavailable","missing_channel",support|dict(finite_support=0);continue
            metric="mean" if reducer=="sample_mean" else "weighted_sum"
            if reducer=="weighted_estimate" and weights is None:yield None,"unavailable","missing_weight",support|dict(finite_support=0);continue
            result=statistics(values[members],weights=weights[members] if weights is not None else None,metrics=[metric],semantic=channel["semantic"],context=context)
            value=result["statistics"][metric];support.update(result["support"]);support["finite_support"]=result["support"]["finite_count"]
            if reducer=="weighted_estimate" and (support["invalid_count"] or support["invalid_weight_count"]):value=dict(value=None,status="unavailable",reason="incomplete_weighted_support")
            yield value["value"],value["status"],value["reason"],support


def run(source,arguments,cache,*,provenance=None,validate_only=False):
    S.keys(arguments,["object","mode","channel","range","spatial","reducer","selection","weight","sampling_population","max_gap","result_bytes"],["object","mode","range","spatial"])
    oid=arguments["object"];mode=arguments["mode"]
    if oid not in source.objects or mode not in ("grid_line","grid_slab","tracer_bins"):raise AnalysisError("invalid_spatial","Choose a source object and supported spatial operation")
    obj=source.objects[oid];context=source.context;records=source.samples[oid];indices=sample_range(records,arguments["range"]);physical_axis=valid_axis(records)
    if (mode.startswith("grid") and obj["kind"]!="volume") or (mode=="tracer_bins" and obj["kind"]!="particles"):raise AnalysisError("association","Direct-grid and tracer inputs are different scientific populations")
    description,start,direction,edges=spatial(arguments["spatial"]);bins=len(edges)-1
    reducer=arguments.get("reducer","probe" if mode=="grid_line" else "mean" if mode=="grid_slab" else "count")
    if reducer not in dict(grid_line=("probe",),grid_slab=("mean","integral"),tracer_bins=("count","sample_mean","weighted_estimate"))[mode]:raise AnalysisError("invalid_reducer","Reducer differs from the spatial input type")
    if mode=="grid_slab" and description["slab"] is None:raise AnalysisError("invalid_spatial","Grid slab requires explicitly bounded slab geometry")
    if mode=="grid_line" and description["slab"] is not None:raise AnalysisError("invalid_spatial","Line probes do not use slab geometry")
    channel=U.declaration(source,oid,arguments["channel"]) if "channel" in arguments else None
    if reducer!="count" and channel is None:raise AnalysisError("invalid_channel","Choose one source value channel")
    if reducer=="count" and channel is not None:raise AnalysisError("invalid_channel","Tracer counts use source positions; omit the value channel")
    if mode.startswith("grid") and channel["component"] is not None:raise AnalysisError("association","Grid space-time requires one scalar channel")
    if channel and channel["semantic"] in ("phase","categorical","identifier"):raise AnalysisError("unsupported_semantics","Spatial interpolation/means/estimates require a continuous or signed channel")
    selection=S.validate(source,arguments["selection"]) if "selection" in arguments else None
    if selection and (mode!="tracer_bins" or selection["object"]!=oid or selection["association"]!="vertex"):raise AnalysisError("association","Tracer restriction requires a same-object particle selection")
    if selection and selection["time_policy"]=="sample_local" and any(i!=selection["selector"]["index"] for i in indices):raise AnalysisError("anonymous","Anonymous sample-local cohorts do not define a temporal population")
    weight=U.declaration(source,oid,arguments["weight"]) if "weight" in arguments else None
    if reducer=="weighted_estimate":
        population=arguments.get("sampling_population")
        if weight is None or weight["semantic"] in ("phase","categorical","identifier") or weight["quantity"]!="sampling_weight" or not isinstance(population,str) or not 1<=len(population)<=512:raise AnalysisError("invalid_weight","Tracer estimates need declared numeric sampling weights and an explicit population/weight interpretation")
    elif weight is not None or "sampling_population" in arguments:raise AnalysisError("invalid_weight","Sampling weights belong only to declared tracer estimates")
    gap=request_float(arguments["max_gap"]) if "max_gap" in arguments else None
    if gap is not None and (gap<=0 or not physical_axis):raise AnalysisError("invalid_range","Physical gap threshold requires a valid native axis and positive limit")
    if validate_only:return dict(validated=True)
    units="1" if reducer=="count" else channel["units"]
    if reducer=="integral":units=U.product_unit(units,"unknown" if description["units"]=="unknown" else f"({description['units']})^3")
    if reducer=="weighted_estimate":units=U.product_unit(units,weight["units"])
    label="direct source grid; trilinear line probes" if mode=="grid_line" else "direct source grid; discrete whole-cell slab quadrature" if mode=="grid_slab" else "tracer samples/estimate; not direct field density"
    clock=source.sha256+":"+oid
    manifest=dict(algorithm=POLICY,source=source.identity(),request=arguments,spatial=description,value_origin=label,precision="original typed values; source-space float64 numerical operations",provenance=provenance or {},
                  clocks={clock:dict(axis="native_time" if physical_axis else "record_index",time_units=U.time_unit(source),static=obj["static"])},object=obj,channel=channel,weight=weight,units=units,
                  temporal_display="native observations at actual coordinates; no time interpolation or hold-cell extension",gap_policy=dict(max_gap=float_token(gap) if gap else None))
    if len(encoded(manifest))>MAX_CONTROL-16384:raise AnalysisError("control_limit","Spatial manifest exceeds control budget")
    key=hashlib.sha256(encoded(manifest)).hexdigest();count=len(indices)*bins
    with cache.begin(manifest,expected_rows=count,expected_support=count,byte_limit=arguments.get("result_bytes",DEFAULT_RESULT_BYTES),context=context) as writer:
        if selection and indices and any(name in selection["selector"] for name in ("ids","ids_asset")):manifest["identity_audit"]=source.audit_identity(oid,indices.stop-1)
        for index in indices:
            context.check();context.progress("space_time",index-indices.start,len(indices));record=records[index]
            descriptors={a["name"]:a for a in record["descriptor"]["arrays"]};wanted={c["channel"] for c in (channel,weight) if c}
            if mode=="tracer_bins":wanted.add("position")
            if selection:wanted |= S.needed_channels(selection)
            with source.read_sample(oid,index,wanted&descriptors.keys()) as sample:
                if channel and channel["channel"] not in sample.arrays:outputs=((None,"unavailable","missing_channel",dict(selected_support=None,finite_support=0)) for _ in range(bins))
                elif mode=="grid_line":outputs=line_values(source,sample,obj,channel,description,start,direction,edges)
                elif mode=="grid_slab":outputs=slab_values(source,sample,obj,channel,description,start,direction,edges,reducer)
                else:outputs=tracer_values(source,sample,index,obj,channel,description,start,direction,edges,reducer,selection,weight)
                from contextlib import closing
                with closing(outputs):
                    for i,(value,status,reason,support) in enumerate(outputs):
                        token=float_token(record["time"]) if record["time"] is not None else dict(text="",f64_le_hex="");support_key="s"+str(writer.counts["rows"])
                        support.update(key=support_key,bin=i,lower_edge=float_token(edges[i]),upper_edge=float_token(edges[i+1]),source_index=index,source_sequence=record["sequence"],native_time=token,gap_from_previous=bool(gap and index>indices.start and record["time"]-records[index-1]["time"]>gap))
                        writer.append(support,kind="support")
                        writer.append(dict(result_id=key,selection_key=selection["key"] if selection else "space-time",selection_revision=str(selection["revision"]) if selection else "1",source_key=source.sha256,object=oid,association="spatial_bin",member_key="bin:"+str(i),clock=clock,sample_index=str(index),sequence=str(record["sequence"]),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],channel=channel["channel"] if channel else "position",component=str(channel["component"]) if channel and channel["component"] is not None else "",statistic=reducer,source_dtype=descriptors[channel["channel"]]["dtype"] if channel and channel["channel"] in descriptors else "i8" if reducer=="count" else "unavailable",units=units,time_status="static" if obj["static"] else "exact" if physical_axis else "index_only",position_status="source",support_key=support_key)|numeric(value,status,reason))
        source.verify();source.verify_members();reference=writer.finish()
    return dict(result=reference,row_count=count,support_count=count,algorithm=POLICY)

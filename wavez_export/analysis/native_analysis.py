"""Explicit native-clock jobs. Full typed observations stream to private results.

Context checkpoints may service a cursor request while this Python stack is
suspended. Source arrays, accumulators and the writer retain their shared leases;
no completed record is decoded/reduced again and no second computation runs.
"""
from bisect import bisect_left,bisect_right
from contextlib import ExitStack
import hashlib
import math
import platform

import numpy as np

from .contracts import AnalysisError,MIB,float_token,integer,request_float
from . import selectors as S
from . import channel_semantics as U
from .sampling import valid_axis,match_rows,world_positions,probe_array
from .reductions import statistics,compensated,POLICY as REDUCTION
from .quadrature import volume_integral,face_areas,POLICY as QUADRATURE
from .result_store import encoded,DEFAULT_RESULT_BYTES

POLICY="g4-native-observations-1"
MODES={"trace","statistics","population","integral","interval_velocity","centroid","area"}


def sample_range(rows,request):
    S.keys(request,["axis","start","end"],["axis","start","end"])
    axis=request["axis"]
    if axis=="record_index":
        start=integer(request["start"],"first index",0,len(rows))
        end=integer(request["end"],"last index",-1,len(rows)-1)
        if end<start-1:raise AnalysisError("invalid_range","Range is reversed")
        return range(start,end+1)
    if axis!="native_time":raise AnalysisError("invalid_range","Choose native_time or record_index")
    if not valid_axis(rows):raise AnalysisError("index_only","Physical analysis requires an increasing finite native clock; no sorting")
    start,end=request_float(request["start"]),request_float(request["end"])
    if end<start:raise AnalysisError("invalid_range","Range is reversed")
    return range(bisect_left(rows,start,key=lambda r:r["time"]),bisect_right(rows,end,key=lambda r:r["time"]))


def selected_count(definition):
    selector=definition["selector"]
    for name in ("ids","rows","xyz"):
        if name in selector or name+"_asset" in selector:return S.member_count(selector,name)
    if definition["kind"] in ("probe","mesh_point"):return 1
    raise AnalysisError("ambiguous_trace","Object/ROI populations require statistics or an explicitly frozen set for member traces")


def numeric(value,status="source",reason=None):
    result=dict(value="",value_f64_le_hex="",value_status=status,reason=reason or "")
    if value is None:return result|dict(value_status="unavailable")
    if isinstance(value,(int,np.integer)):
        result["value"]=str(int(value));return result
    value=float(value)
    token=float_token(value)
    result.update(value=token["text"],value_f64_le_hex=token["f64_le_hex"])
    if not math.isfinite(value):
        if status=="source":result.update(value_status="nonfinite",reason="nonfinite_source")
        else:result.update(value="",value_f64_le_hex="",value_status="unavailable",reason="arithmetic_overflow")
    return result


def association_of(sample,name):
    association=sample.descriptors[name]["association"]
    return "grid" if association=="sample" else association


def component_values(sample,obj,channel):
    name=channel["channel"]
    if name not in sample.arrays:return None
    values=sample.arrays[name]
    if name=="position" and obj["kind"] in ("particles","mesh") and channel["coordinates"]=="viewer_world":values=world_positions(obj,values)
    if sample.descriptors[name]["association"]=="sample":values=values.reshape(-1)
    component=channel["component"]
    if values.ndim==1:
        if component is not None:raise AnalysisError("association","Scalar channel has no vector component")
        return values
    if values.ndim!=2 or component is None:raise AnalysisError("association","Choose an explicit vector component or magnitude")
    if component=="magnitude":return np.hypot.reduce(values.astype(np.float64),axis=1)
    if component>=values.shape[1]:raise AnalysisError("association","Vector component is unavailable")
    return values[:,component]


def member_addresses(source,definition,sample,membership):
    """One row per requested address, including absence; never infer identity."""
    selector=definition["selector"];kind=definition["kind"]
    if "ids" in selector or "ids_asset" in selector:
        wanted=S.members(source,selector,"ids")
        name="particle_id" if kind=="particle_ids" else "vertex_id"
        found=match_rows(wanted,sample.arrays[name])
        eligible=np.isin(found,membership.rows)
        for i,(identity,row) in enumerate(zip(wanted,found)):
            if i%128==0:source.context.check()
            yield str(int(identity)),"id:"+str(int(identity)),int(row) if row>=0 and eligible[i] else None,("absent_at_sample" if row<0 else "predicate_excluded_or_unknown")
    elif kind=="grid_samples":
        xyz=S.members(source,selector,"xyz")
        rows=np.ravel_multi_index(tuple(xyz[:,::-1].T),sample.record["descriptor"]["geometry"]["shape"]) if membership.present else np.full(len(xyz),-1,dtype=np.int64)
        eligible=np.isin(rows,membership.rows)
        for i,address in enumerate(xyz):
            if i%128==0:source.context.check()
            yield "","xyz:"+",".join(str(int(v)) for v in address),int(rows[i]) if eligible[i] else None,membership.reason or "predicate_excluded_or_unknown"
    elif kind in ("mesh_point","probe"):
        yield "",kind,(int(selector["face"]) if kind=="mesh_point" else 0) if membership.present else None,membership.reason
    else:
        rows=S.members(source,selector,"rows");eligible=np.isin(rows,membership.rows)
        for i,row in enumerate(rows):
            if i%128==0:source.context.check()
            yield "",("face:" if definition["association"]=="face" else "row:")+str(int(row)),int(row) if eligible[i] else None,membership.reason or "predicate_excluded_or_unknown"


def trace_value(source,definition,sample,channel,values,row):
    kind=definition["kind"];obj=source.objects[definition["object"]]
    if kind=="probe":
        if channel["semantic"] in ("phase","categorical","identifier"):raise AnalysisError("unsupported_semantics","Trilinear probes cannot blend categories/phase/IDs")
        coordinate=S.vector(definition["selector"]["coordinate"])
        if definition["coordinates"]["space"]=="data_local":coordinate=world_positions(obj,coordinate[None,:])[0]
        result=probe_array(sample.arrays[channel["channel"]],sample.record["descriptor"]["geometry"],obj["data_to_world"],coordinate)
        return numeric(result["value"],result["status"],result.get("reason"))
    association=association_of(sample,channel["channel"])
    if kind=="mesh_point" and association=="vertex":
        if channel["semantic"] in ("phase","categorical","identifier"):raise AnalysisError("unsupported_semantics","Barycentric probes cannot blend categories/phase/IDs")
        if channel["component"]=="magnitude":
            vectors=sample.arrays[channel["channel"]][sample.arrays["triangles"][row]].astype(np.float64)
            if channel["channel"]=="position" and channel["coordinates"]=="viewer_world":vectors=world_positions(obj,vectors)
            if not np.isfinite(vectors).all():return numeric(None,reason="nonfinite_support")
            bary=S.vector(definition["selector"]["barycentric"])
            value=[compensated(vectors[:,i]*bary,source.context) for i in range(vectors.shape[1])]
            return numeric(np.hypot.reduce(value),"spatially_interpolated")
        corners=values[sample.arrays["triangles"][row]]
        if not np.isfinite(corners).all():return numeric(None,reason="nonfinite_support")
        return numeric(compensated(corners.astype(np.float64)*S.vector(definition["selector"]["barycentric"]),source.context),"spatially_interpolated")
    if association!=definition["association"]:raise AnalysisError("association","Source channel and selected member association differ")
    return numeric(values[row])


def run(source,arguments,cache,*,provenance=None,validate_only=False):
    S.keys(arguments,["selections","channels","mode","range","metrics","weight","max_gap","result_bytes","finite_subtotal","physical_mass","time_units","position_units"],
           ["selections","mode","range"])
    mode=arguments["mode"]
    if mode not in MODES:raise AnalysisError("unsupported_operation","Unsupported native analysis mode")
    if "weight" in arguments and mode not in ("statistics","centroid"):raise AnalysisError("invalid_request","Weights apply to selected-channel statistics or centroid")
    if "metrics" in arguments and mode!="statistics":raise AnalysisError("invalid_request","Metrics belong to selected-channel statistics")
    if arguments.get("finite_subtotal") and mode!="integral":raise AnalysisError("invalid_request","Finite-support subtotal belongs to grid quadrature")
    definitions=arguments["selections"]
    if not isinstance(definitions,list) or not 1<=len(definitions)<=16:raise AnalysisError("analysis_limit","Choose 1–16 selections")
    definitions=[S.validate(source,d) for d in definitions]
    if len({d["key"] for d in definitions})!=len(definitions):raise AnalysisError("invalid_selection","Analysis selection keys must be unique")
    if any(d["kind"]=="derived_surface" for d in definitions):raise AnalysisError("approximate_artifact_only","Convert an artifact pick explicitly to an original-source probe before temporal analysis")
    requests=arguments.get("channels",[])
    if not isinstance(requests,list) or len(requests)>16:raise AnalysisError("analysis_limit","Choose at most 16 channels")
    if mode in ("trace","statistics","integral") and not requests:raise AnalysisError("invalid_channel","Choose source channels")
    if mode in ("population","centroid","area","interval_velocity") and requests:raise AnalysisError("invalid_channel","This operation defines its own source channel; omit channels")
    metrics=arguments.get("metrics",["count","min","max","mean","stddev"])
    if not isinstance(metrics,list) or not 1<=len(metrics)<=32:raise AnalysisError("invalid_statistic","Choose 1–32 statistics")
    gap=request_float(arguments["max_gap"]) if "max_gap" in arguments else None
    if gap is not None and gap<=0:raise AnalysisError("invalid_range","Maximum connected interval must be positive")
    for name in ("physical_mass","finite_subtotal"):
        if type(arguments.get(name,False)) is not bool:raise AnalysisError("invalid_request",name+" must be boolean")
    if arguments.get("physical_mass") and mode not in ("integral","statistics"):raise AnalysisError("invalid_request","Physical mass is an explicit particle sum or grid integral")
    plans=[];expected=support_count=0
    for definition in definitions:
        oid=definition["object"];obj=source.objects[oid];rows=source.samples[oid]
        indices=sample_range(rows,arguments["range"])
        if gap is not None and not valid_axis(rows):raise AnalysisError("index_only","A physical gap threshold requires a valid native time axis")
        if mode=="trace" and definition["time_policy"]=="sample_local" and any(i!=definition["selector"]["index"] for i in indices):
            raise AnalysisError("anonymous","Anonymous source rows permit only their pinned sample; no identity time trace")
        if definition["kind"] in ("probe","mesh_point") and definition["predicate"]:
            raise AnalysisError("association","Location probes do not define a discrete predicate population")
        if definition["kind"] in ("probe","mesh_point") and mode!="trace":
            raise AnalysisError("association","Use source value traces for location probes; set reductions require discrete members")
        channels=[U.declaration(source,oid,c) for c in requests]
        if mode=="interval_velocity":
            if definition["kind"] not in ("particle_ids","mesh_vertices") or not any(k in definition["selector"] for k in ("ids","ids_asset")):
                raise AnalysisError("anonymous","Interval velocity requires explicit persistent vertex/particle IDs")
            if not valid_axis(rows):raise AnalysisError("index_only","Interval velocity requires physical native times")
            indices=range(indices.start+1,indices.stop) if indices else range(0)
        if mode in ("trace","interval_velocity"):per=selected_count(definition)*(len(channels) if mode=="trace" else 3)
        elif mode=="statistics":per=len(channels)*len(metrics)
        elif mode in ("centroid",):per=3
        elif mode=="population":per=4
        else:per=max(1,len(channels))*(2 if arguments.get("finite_subtotal") else 1)
        if mode=="integral" and (obj["kind"]!="volume" or definition["kind"]!="roi" or definition["predicate"]):
            raise AnalysisError("association","Full-cell quadrature requires a geometric original-grid ROI without a node predicate")
        if mode=="area" and (obj["kind"]!="mesh" or definition["association"]!="face"):raise AnalysisError("association","Area requires source mesh faces")
        expected+=len(indices)*per;support_count+=len(indices)*max(1,len(channels))
        plans.append((definition,indices,channels))
    if validate_only:return dict(validated=True)
    # Reserve output before history scans or result-producing work.
    manifest=dict(algorithm=POLICY,request=arguments,source=source.identity(),provenance=provenance or {},
                  runtime=dict(python=platform.python_version(),numpy=np.__version__),clocks={},channels={},objects={},
                  precision=dict(source="typed original arrays; integer text exact",reduction=REDUCTION,quadrature=QUADRATURE),
                  missing_policy="explicit unavailable rows; no fill or repeated union-clock holds",gap_policy=dict(max_gap=float_token(gap) if gap else None,connection="native observations only"))
    result_key=hashlib.sha256(encoded(dict(policy=POLICY,source=source.identity(),request=arguments,provenance=provenance or {}))).hexdigest()
    context=source.context
    with cache.begin(manifest,expected_rows=expected,expected_support=support_count,byte_limit=arguments.get("result_bytes",DEFAULT_RESULT_BYTES),context=context) as writer:
        for definition,indices,channels in plans:
            oid=definition["object"];obj=source.objects[oid];rows=source.samples[oid]
            physical_axis=valid_axis(rows)
            time_units=U.time_unit(source,arguments.get("time_units"));position_units=U.position_unit(source,oid,arguments.get("position_units"))
            clock=source.sha256+":"+oid
            manifest["clocks"][clock]=dict(object=oid,time_units=time_units,axis="native_time" if physical_axis else "record_index",static=obj["static"],range=arguments["range"])
            manifest["channels"][definition["key"]]=channels
            manifest["objects"][oid]=obj
            audit=None
            if indices and any(k in definition["selector"] for k in ("ids","ids_asset")):
                audit=source.audit_identity(oid,indices.stop-1)
            weight_request=arguments.get("weight")
            weight=U.declaration(source,oid,weight_request) if weight_request and weight_request!={"geometric":"face_area"} else None
            if weight_request is not None and not weight_request:raise AnalysisError("invalid_request","Weight must name a source channel or geometric measure")
            if weight and weight["semantic"] in ("phase","categorical","identifier"):raise AnalysisError("unsupported_semantics","Weights require numeric source values, not phase/categories/identity")
            if weight_request=={"geometric":"face_area"} and (obj["kind"]!="mesh" or definition["association"]!="face"):
                raise AnalysisError("association","Geometric face-area weights require mesh face association")
            for index in indices:
                context.check();context.progress("native_analysis",index-indices.start,len(indices))
                record=rows[index];specs={a["name"]:a for a in record["descriptor"]["arrays"]}
                wanted=S.needed_channels(definition)|{c["channel"] for c in channels}
                if mode in ("interval_velocity","centroid","area") or weight_request=={"geometric":"face_area"}:wanted.add("position")
                if weight:wanted.add(weight["channel"])
                # Membership / component transforms / ID maps are admitted before
                # allocating. Grid quadrature uses its own bounded cell batches.
                population=0 if mode=="integral" else S._count(record,"grid" if obj["kind"]=="volume" else definition["association"])
                retained=selected_count(definition) if mode in ("trace","interval_velocity") else 0
                with ExitStack() as stack:
                    stack.enter_context(context.allocation((population+retained)*160+MIB))
                    sample=stack.enter_context(source.read_sample(oid,index,wanted&specs.keys()))
                    membership=S.resolve(source,definition,index,sample) if mode!="integral" else None
                    time=record["time"];token=float_token(time) if time is not None else {"text":"","f64_le_hex":""}
                    base=dict(result_id=result_key,selection_key=definition["key"],selection_revision=str(definition["revision"]),source_key=source.sha256,object=oid,association=definition["association"],
                              clock=clock,sample_index=str(index),sequence=str(record["sequence"]),time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],
                              time_status="static" if obj["static"] else "exact" if physical_axis else "index_only",position_status="source")
                    support=dict(source_sample_index=index,source_sequence=record["sequence"],source_time=token,identity_audit=audit,
                                 selected=membership.selected if membership else None,present=membership.present if membership else None,
                                 matched=len(membership.rows) if membership else None,predicate_unknown=membership.unknown if membership else None,
                                 membership_status=membership.status if membership else None,membership_reason=membership.reason if membership else None)
                    if index>indices.start:
                        support["previous_native_index"]=index-1
                        support["gap_from_previous"]=bool(gap is not None and time-rows[index-1]["time"]>gap)
                    key=f"s{writer.counts['support']}";base["support_key"]=key
                    if mode=="interval_velocity":
                        _velocity(source,definition,index,sample,membership,base,support,writer,gap,position_units,time_units,stack)
                    elif mode in ("population","centroid","area"):
                        _geometry(source,definition,sample,membership,mode,base,support,writer,weight,weight_request,position_units)
                    else:
                        for channel in channels:
                            key=f"s{writer.counts['support']}";channel_base=base|dict(support_key=key,channel=channel["channel"],component=str(channel["component"]) if channel["component"] is not None else "",units=channel["units"],source_dtype=specs.get(channel["channel"],{}).get("dtype","unavailable"))
                            details=dict(support)
                            _channel(source,definition,sample,membership,channel,mode,channel_base,details,writer,arguments,weight,weight_request,position_units)
                            writer.append(dict(key=key,**details),kind="support")
                        continue
                    writer.append(dict(key=key,**support),kind="support")
        source.verify();source.verify_members()
        result=writer.finish()
    return dict(result=result,row_count=writer.counts["rows"],support_count=writer.counts["support"],algorithm=POLICY)


def _weights(source,definition,sample,rows,weight,request):
    if request=={"geometric":"face_area"}:return face_areas(source.objects[definition["object"]],sample,rows,source.context),"world triangle area"
    if weight:
        values=component_values(sample,source.objects[definition["object"]],weight)
        if values is None:return None,"missing_weight"
        if association_of(sample,weight["channel"])!=definition["association"]:raise AnalysisError("association","Weight and value associations differ")
        return values[rows],weight
    return None,None


def _channel(source,definition,sample,membership,channel,mode,base,support,writer,args,weight,weight_request,position_units):
    obj=source.objects[definition["object"]];name=channel["channel"]
    values=component_values(sample,obj,channel)
    if mode=="trace":
        for identity,address,row,reason in member_addresses(source,definition,sample,membership):
            value=numeric(None,reason="missing_channel") if values is None else numeric(None,reason=reason) if row is None else trace_value(source,definition,sample,channel,values,row)
            writer.append(base|dict(entity_id=identity,member_key=address,source_row=str(row) if row is not None else "",statistic="value")|value)
        return
    if mode=="integral":
        if channel["semantic"] in ("phase","categorical","identifier"):raise AnalysisError("unsupported_semantics","Field integrals require numeric continuous/signed values")
        result=volume_integral(sample.arrays[name],sample.record["descriptor"]["geometry"],obj,definition["selector"],space=definition["coordinates"]["space"],finite_subtotal=args.get("finite_subtotal",False),context=source.context) if values is not None else dict(value=None,status="unavailable",reason="missing_channel",support={})
        support.update(result["support"]);units=U.product_unit(channel["units"],"unknown" if position_units=="unknown" else f"({position_units})^3");scale=1
        if args.get("physical_mass"):
            policy=U.physical_mass_policy(channel,"volume",position_units);units=policy["units"];scale=policy["scale"];support["physical_mass"]=policy
        for metric,value in [("physical_mass" if args.get("physical_mass") else "discrete_integral",result)]+([("finite_subtotal",result.get("finite_subtotal",dict(value=None,status="unavailable",reason="missing_channel"))) ] if args.get("finite_subtotal") else []):
            writer.append(base|dict(statistic=metric,units=units)|numeric(value["value"]*scale if value["value"] is not None else None,value["status"],value.get("reason")))
        return
    metrics=args.get("metrics",["count","min","max","mean","stddev"])
    if values is None:
        support["finite_count"]=None
        for metric in metrics:writer.append(base|dict(statistic=metric)|numeric(None,reason="missing_channel"))
        return
    if association_of(sample,name)!=definition["association"]:raise AnalysisError("association","Statistics require the selected source association")
    weights,weight_evidence=_weights(source,definition,sample,membership.rows,weight,weight_request)
    support["weight"]=weight_evidence
    if weight_evidence=="missing_weight":
        for metric in metrics:writer.append(base|dict(statistic=metric)|numeric(None,reason="missing_weight"))
        return
    result=statistics(values[membership.rows],metrics=metrics,weights=weights,semantic=channel["semantic"],context=source.context)
    support.update(result["support"])
    physical=None
    if args.get("physical_mass"):
        if metrics!=["sum"]:raise AnalysisError("invalid_request","Physical particle mass uses explicit unweighted sum only")
        physical=U.physical_mass_policy(channel,obj["kind"],position_units);support["physical_mass"]=physical
    for metric,value in result["statistics"].items():
        units="1" if metric=="count" else base["units"]
        if metric=="sum_weights":units=weight["units"] if weight else f"({position_units})^2" if position_units!="unknown" else "unknown"
        elif metric in ("weighted_sum","algebraic_weighted_sum"):units=U.product_unit(units,weight["units"] if weight else f"({position_units})^2" if position_units!="unknown" else "unknown")
        if physical:units=physical["units"];value=value|dict(value=value["value"]*physical["scale"] if value["value"] is not None else None)
        writer.append(base|dict(statistic="physical_mass" if physical else metric,units=units)|numeric(value["value"],value["status"],value.get("reason")))


def _geometry(source,definition,sample,membership,mode,base,support,writer,weight,weight_request,position_units):
    if mode=="population":
        for metric,value in [("selected",membership.selected),("present",membership.present),("matched",len(membership.rows)),("predicate_unknown",membership.unknown)]:
            writer.append(base|dict(statistic=metric,units="1")|numeric(value,"derived"))
        return
    rows=membership.rows;obj=source.objects[definition["object"]]
    if mode=="area":
        values=face_areas(obj,sample,rows,source.context);result=statistics(values,metrics=["sum"],context=source.context)
        support.update(result["support"]);value=result["statistics"]["sum"]
        if support["invalid_count"]:value=dict(value=None,status="unavailable",reason="nonfinite_support")
        writer.append(base|dict(statistic="world_triangle_area",units=f"({position_units})^2" if position_units!="unknown" else "unknown")|numeric(value["value"],value["status"],value.get("reason")))
        return
    positions=S.member_positions(obj,sample,rows,definition["association"],space=definition["coordinates"]["space"])
    weights,evidence=_weights(source,definition,sample,rows,weight,weight_request);support["weight"]=evidence
    # A position is valid as a vector; do not form x/y/z from different subsets.
    valid=np.isfinite(positions).all(axis=1);support["invalid_positions"]=int(np.count_nonzero(~valid))
    for axis in range(3):
        metric="weighted_mean" if weight_request else "mean"
        value=dict(value=None,status="unavailable",reason="missing_weight") if evidence=="missing_weight" else statistics(positions[valid,axis],weights=weights[valid] if weights is not None else None,metrics=[metric],context=source.context)["statistics"][metric]
        writer.append(base|dict(channel="position",component=str(axis),statistic="centroid",units=position_units)|numeric(value["value"],value["status"],value.get("reason")))


def _velocity(source,definition,index,sample,membership,base,support,writer,gap,position_units,time_units,stack):
    oid=definition["object"];obj=source.objects[oid];previous=stack.enter_context(source.read_sample(oid,index-1,["position"]))
    name="particle_id" if obj["kind"]=="particles" else "vertex_id"
    dt=sample.record["time"]-previous.record["time"]
    support.update(derivation="consecutive native endpoints; no endpoint padding",endpoint_indices=[index-1,index],endpoint_times=[float_token(previous.record["time"]),float_token(sample.record["time"])],dt=float_token(dt),basis=definition["coordinates"]["space"])
    midpoint=previous.record["time"]+dt/2;token=float_token(midpoint)
    base=base|dict(time=token["text"],time_f64_le_hex=token["f64_le_hex"],aligned_time=token["text"],time_status="derived_interval",channel="position",statistic="interval_velocity",units=U.quotient_unit(position_units,time_units),position_status="derived_interval")
    wanted=S.members(source,definition["selector"],"ids");old=match_rows(wanted,previous.arrays[name]);new=match_rows(wanted,sample.arrays[name]);eligible=np.isin(new,membership.rows)
    for i,identity in enumerate(wanted):
        if i%128==0:source.context.check()
        reason="gap_exceeds_limit" if gap is not None and dt>gap else "absent_endpoint" if old[i]<0 or new[i]<0 else "predicate_excluded_or_unknown" if not eligible[i] else None
        vector=None
        if reason is None:
            with np.errstate(over="ignore",invalid="ignore",divide="ignore"):
                vector=(sample.arrays["position"][new[i]].astype(np.float64)-previous.arrays["position"][old[i]].astype(np.float64))/dt
                if definition["coordinates"]["space"]=="viewer_world":vector=np.asarray(obj["data_to_world"]).reshape(3,4)[:,:3]@vector
        for axis in range(3):writer.append(base|dict(entity_id=str(int(identity)),member_key="id:"+str(int(identity)),source_row=str(int(new[i])) if new[i]>=0 else "",component=str(axis))|numeric(vector[axis] if vector is not None else None,"derived_interval",reason))

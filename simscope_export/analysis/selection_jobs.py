"""Bounded selection queries. Preview limits never change stored membership."""

from contextlib import ExitStack
import numpy as np

from .contracts import AnalysisError, float_token, integer, request_float
from .sampling import interpolated_positions, source_bracket, world_positions, mesh_compatible
from . import selectors as S


def workspace(source, definition):
    records=source.samples[definition["object"]]
    # Includes source-index membership masks, predicate temporaries, positions,
    # ID sorting and projection. Source leases are charged separately.
    count=max((S._count(r,"grid" if source.objects[definition["object"]]["kind"]=="volume" else "vertex") for r in records),default=0)
    faces=max((S._count(r,"face") for r in records),default=0) if source.objects[definition["object"]]["kind"]=="mesh" else 0
    return source.context.allocation(max(count,faces)*512+1048576)


def dispatch(source, operation, arguments):
    if operation=="resolve_selections":
        S.keys(arguments,["selections","time","index","limit","visual"],["selections"])
        definitions=arguments["selections"]
        if not isinstance(definitions,list) or not 1<=len(definitions)<=256:
            raise AnalysisError("selection_limit","Resolve 1–256 selections")
        limit=integer(arguments.get("limit",256),"combined preview limit",1,512)
        if limit<len(definitions):raise AnalysisError("selection_limit","Preview budget below number of visible selections")
        results=[]
        for definition in definitions:
            source.context.check()
            query=dict(selection=definition,limit=max(1,limit//len(definitions)))
            query["style"]=arguments.get("visual",{}).get(definition["object"],{})
            query["index" if "index" in arguments else "time"]=arguments.get("index",arguments.get("time"))
            result=dispatch(source,"resolve_selection",query)
            result.pop("selection")
            result.update(key=definition["key"],revision=definition["revision"],object=definition["object"])
            results.append(result)
        return dict(results=results,preview_limit=limit)
    if operation=="edit_selection":
        S.keys(arguments,["selection","incoming","mode"],["selection","incoming","mode"])
        a,b=S.validate(source,arguments["selection"]),S.validate(source,arguments["incoming"])
        mode=arguments["mode"]
        if mode not in ("replace","add","subtract","toggle"):raise AnalysisError("invalid_selection","Unknown set edit")
        if mode=="replace":result=b
        else:
            if any(a[k]!=b[k] for k in ("source","object","association","kind","predicate","time_policy")):
                raise AnalysisError("incompatible_selection","Set edits require the same source/kind/association/predicate")
            member="ids" if "ids" in a["selector"] or "ids_asset" in a["selector"] else "rows"
            fields=(member,member+"_asset")
            if not any(k in a["selector"] for k in fields) or not any(k in b["selector"] for k in fields) or {k:v for k,v in a["selector"].items() if k not in fields}!={k:v for k,v in b["selector"].items() if k not in fields}:
                raise AnalysisError("incompatible_selection","Set edits require explicit members in the same sample/epoch")
            aa,bb=S.members(source,a["selector"],member),S.members(source,b["selector"],member)
            with source.context.allocation((aa.nbytes+bb.nbytes)*16+1048576):
                combined=np.union1d(aa,bb) if mode=="add" else np.setdiff1d(aa,bb,assume_unique=True) if mode=="subtract" else np.setxor1d(aa,bb,assume_unique=True)
                values=[str(int(v)) for v in combined] if member=="ids" else combined.tolist()
                result=dict(a);result["selector"]={k:v for k,v in a["selector"].items() if k not in fields}
                result["selector"][member]=values
        result.update(key=a["key"],name=a["name"],revision=a["revision"]+1)
        return S.validate(source,result)
    if operation=="define_selection":
        # Input JSON is already bounded; definition output must fit control size.
        return S.define(source,arguments)
    S.keys(arguments,["selection","time","index","limit","operation","other","key","name","style"],["selection"])
    definition=S.validate(source,arguments["selection"])
    definitions=[definition]
    if operation=="combine_selections":
        other=arguments.get("other")
        if not isinstance(other,list) or len(other)>255:raise AnalysisError("invalid_selection","Bounded group definitions required")
        definitions += [S.validate(source,d) for d in other]
    oid=definition["object"];obj=source.objects[oid];records=source.samples[oid]
    limit=integer(arguments.get("limit",2048),"overlay preview limit",1,2048)
    if "index" in arguments:
        index=integer(arguments["index"],"sample index",0,len(records)-1)
        point=dict(a=index,b=index,alpha=0.,status="source",time=records[index]["time"],source_times=[float_token(records[index]["time"])])
    else:point=source_bracket(source,oid,request_float(arguments.get("time"),"time"))
    if point["status"]=="unavailable":
        selector=definition["selector"]
        selected=max(S.member_count(selector,k) for k in ("ids","rows","xyz"))
        return dict(selection=definition,sampling=point,selected=selected,present=0,preview=[],status="unavailable",reason=point["reason"])
    index=point["a"]
    if definition["kind"] in ("probe","derived_surface"):
        if operation!="resolve_selection":raise AnalysisError("unsupported_operation","Locations/artifacts cannot be frozen into discrete members")
        preview=[]
        status="location";reason=None
        if definition["kind"]=="probe":
            location=S.vector(definition["selector"]["coordinate"])
            if definition["coordinates"]["space"]=="data_local":location=world_positions(obj,location[None,:])[0]
            preview=[dict(position=S.tokens(location),position_status="fixed_location")]
        else:
            from .derived import preview as artifact_preview
            preview,status,reason=artifact_preview(source,definition,index,limit)
        return dict(selection=definition,sampling=point,selected=1,present=1 if preview else 0,preview=preview,
                    status=status,reason=reason)
    with workspace(source,definition),ExitStack() as stack:
        available={a["name"] for a in records[index]["descriptor"]["arrays"]}
        needed=S.needed_channels(definition)
        for d in definitions[1:]:needed |= S.needed_channels(d)
        style=arguments.get("style",{})
        if style:
            needed |= {"opacity","particle_type","visual_color","velocity",style.get("color","fixed"),style.get("size","fixed"),style.get("brightness","fixed")}
        if obj["kind"]!="volume":needed.add("position")
        sample=stack.enter_context(source.read_sample(oid,index,needed & available))
        membership=S.resolve(source,definition,index,sample)
        rows=membership.rows
        if operation=="combine_selections":
            rows=S.combine(source,definitions,index,sample,arguments.get("operation"))
            membership=S.Membership(rows,len(rows),len(rows))
        if operation in ("freeze_selection","combine_selections"):
            if membership.status=="unavailable":raise AnalysisError(membership.reason,"Selection unavailable at this source sample")
            if obj["kind"]=="particles":
                if obj.get("identity")=="persistent_i8":kind="particle_ids";selector=dict(ids=[str(int(i)) for i in sample.arrays["particle_id"][rows]])
                else:kind="sample_rows";selector=dict(index=index,rows=rows.tolist())
            elif obj["kind"]=="mesh":
                if definition["association"]=="face":kind="mesh_faces";selector=dict(index=index,rows=rows.tolist())
                elif obj.get("identity")=="stable_topology":kind="mesh_vertices";selector=dict(ids=[str(int(i)) for i in sample.arrays["vertex_id"][rows]])
                else:kind="mesh_vertices";selector=dict(index=index,rows=rows.tolist())
            else:
                kind="grid_samples";zyx=np.unravel_index(rows,sample.record["descriptor"]["geometry"]["shape"])
                selector=dict(index=index,xyz=np.column_stack(zyx)[:,::-1].tolist())
            frozen=S.define(source,dict(key=arguments.get("key",definition["key"]+"-frozen"),name=arguments.get("name",definition["name"]+" (fixed)"),object=oid,kind=kind,selector=selector,association=definition["association"],creation=dict(from_selection=definition["key"],revision=definition["revision"],sampling=point)))
            return dict(selection=frozen,selected=len(rows),present=len(rows),sampling=point)
        if operation!="resolve_selection":raise AnalysisError("unsupported_operation","Unknown selection query")
        # Display eligibility affects only the preview, never scientific membership.
        display_rows=rows
        if obj["kind"]=="particles" and style:
            from .picking import marker_mask
            mask=marker_mask(sample,style,S._count(sample.record,"vertex"))
            display_rows=rows[mask[rows]]
        # Deterministic preview by source row; complete definition retains every ID.
        step=max(1,int(np.ceil(len(display_rows)/limit)));preview_rows=display_rows[::step]
        positions=np.empty((0,3),dtype=np.float64);statuses=[]
        start_positions=positions;end_positions=positions
        if definition["kind"]=="mesh_point" and membership.present:
            face=definition["selector"]["face"];bary=S.vector(definition["selector"]["barycentric"])
            later=sample if point["b"]==index else stack.enter_context(source.read_sample(oid,point["b"],["position"]))
            all_positions,_=interpolated_positions(obj,sample.arrays,later.arrays,point["alpha"])
            positions=(all_positions[sample.arrays["triangles"][face]]*bary[:,None]).sum(axis=0)[None,:]
            pa,_=interpolated_positions(obj,sample.arrays,later.arrays,0.)
            pb,_=interpolated_positions(obj,sample.arrays,later.arrays,1.)
            start_positions=(pa[sample.arrays["triangles"][face]]*bary[:,None]).sum(axis=0)[None,:]
            end_positions=(pb[sample.arrays["triangles"][face]]*bary[:,None]).sum(axis=0)[None,:]
            preview_rows=np.array([face]);statuses=["spatially_interpolated"]
        elif len(preview_rows):
            if obj["kind"]!="volume":
                later=sample if point["b"]==index else stack.enter_context(source.read_sample(oid,point["b"],["position"]))
                all_positions,all_status=interpolated_positions(obj,sample.arrays,later.arrays,point["alpha"])
                pa,_=interpolated_positions(obj,sample.arrays,later.arrays,0.)
                pb,_=interpolated_positions(obj,sample.arrays,later.arrays,1.)
                if definition["association"]=="face":
                    positions=np.mean(all_positions[sample.arrays["triangles"][preview_rows]],axis=1)
                    start_positions=np.mean(pa[sample.arrays["triangles"][preview_rows]],axis=1)
                    end_positions=np.mean(pb[sample.arrays["triangles"][preview_rows]],axis=1)
                    status="interpolated_by_id" if point["alpha"] and mesh_compatible(obj,sample.arrays,later.arrays) else ("topology_held" if point["alpha"] else "source")
                    statuses=[status]*len(preview_rows)
                else:
                    positions=all_positions[preview_rows];statuses=all_status[preview_rows].tolist()
                    start_positions=pa[preview_rows];end_positions=pb[preview_rows]
                if point["alpha"]==0:statuses=["source"]*len(preview_rows)
            else:
                positions=S.member_positions(obj,sample,preview_rows,"grid");statuses=["source"]*len(preview_rows)
                start_positions=end_positions=positions
        key="particle_id" if obj["kind"]=="particles" else "vertex_id"
        ids=sample.arrays.get(key) if definition["association"]=="vertex" else None
        preview=[dict(row=int(row),id=str(int(ids[row])) if ids is not None else None,
                      position=S.tokens(position),position_a=S.tokens(pa),position_b=S.tokens(pb),position_status=status)
                 for row,position,pa,pb,status in zip(preview_rows,positions,start_positions,end_positions,statuses)]
        return dict(selection=definition,sampling=point,selected=membership.selected,present=membership.present,
                    matched=len(rows),unknown=membership.unknown,status=membership.status,reason=membership.reason,
                    preview=preview,display_eligible=len(display_rows),preview_policy=dict(maximum=limit,stride=step,thinned=len(preview)<len(display_rows)),
                    identity_status="declared_not_audited" if obj.get("identity") in ("persistent_i8","stable_topology") else "anonymous")

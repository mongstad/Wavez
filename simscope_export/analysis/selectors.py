"""Source-scoped definitions and sample membership, independent of display state."""

from dataclasses import dataclass
import re

import numpy as np

from .contracts import AnalysisError, exact_id, float_token, integer, request_float, request_vector
from .sampling import epoch, world_positions

MAX_MEMBERS = 10_000_000
MAX_IDENTITIES = 1_000_000
INLINE_MEMBERS = 64
KINDS = {"particle_ids", "sample_rows", "mesh_object", "mesh_vertices", "mesh_faces",
         "mesh_point", "grid_samples", "probe", "roi", "derived_surface"}


def keys(value, allowed, required=()):
    if not isinstance(value, dict) or set(value)-set(allowed) or not set(required)<=set(value):
        raise AnalysisError("invalid_selection", "Unknown or missing selection fields")


def vector(value):
    return np.asarray(request_vector(value), dtype=np.float64)


def tokens(value):
    return [float_token(x) for x in value]


def addresses(values, *, ids=False, maximum=MAX_MEMBERS-1):
    if not isinstance(values, list) or len(values)>(MAX_IDENTITIES if ids else MAX_MEMBERS):
        raise AnalysisError("selection_limit", "Member list exceeds selection budget")
    parsed = [exact_id(v) if ids else integer(v,"source row",0,maximum) for v in values]
    return sorted(set(parsed))


def member_count(selector,field):
    if field in selector:return len(selector[field])
    return int(selector.get(field+"_asset",{}).get("shape",[0])[0])


def members(source,selector,field):
    if field+"_asset" in selector:return source.member_array(selector[field+"_asset"])
    values=selector.get(field,[])
    if field=="ids":values=[exact_id(v) for v in values]
    return np.asarray(values,dtype=np.int64).reshape(-1,3) if field=="xyz" else np.asarray(values,dtype=np.int64)


def packed_members(source,selector,field,*,maximum=MAX_MEMBERS-1):
    if (field in selector)==(field+"_asset" in selector):
        raise AnalysisError("invalid_selection","Use exactly one inline or asset member list")
    if field+"_asset" in selector:
        values=source.member_array(selector[field+"_asset"])
        if len(values)>(MAX_IDENTITIES if field=="ids" else MAX_MEMBERS):raise AnalysisError("selection_limit","Materialized member count exceeds its association limit")
        if values.ndim!=1 or np.any(values<0) or np.any(values>maximum) or np.any(values[1:]<=values[:-1]):
            raise AnalysisError("invalid_asset","Member asset must be sorted, unique and within the declared source range")
        return {field+"_asset":selector[field+"_asset"]}
    values=addresses(selector[field],ids=field=="ids",maximum=maximum)
    if len(values)>INLINE_MEMBERS:
        if source.assets is None:raise AnalysisError("selection_limit","Large member sets require the owned worker asset store")
        return {field+"_asset":source.assets.put(np.asarray(values,dtype="<i8"),source.context)}
    return {field:[str(v) for v in values] if field=="ids" else values}


def region(value,*,canonical=False):
    """Canonical finite geometry. Slabs are finite oriented rectangular prisms."""
    if not isinstance(value,dict):raise AnalysisError("invalid_selection","Region geometry required")
    shape=value.get("shape")
    if shape=="box":
        keys(value,["shape","lower","upper"],["lower","upper"])
        low,high=vector(value["lower"]),vector(value["upper"])
        if np.any(high<=low):raise AnalysisError("invalid_selection","Box needs positive extents")
        return dict(shape=shape,lower=tokens(low),upper=tokens(high))
    if shape=="sphere":
        keys(value,["shape","center","radius"],["center","radius"])
        radius=request_float(value["radius"])
        if radius<=0:raise AnalysisError("invalid_selection","Radius must be positive")
        return dict(shape=shape,center=tokens(vector(value["center"])),radius=float_token(radius))
    if shape=="cylinder":
        keys(value,["shape","start","end","radius"],["start","end","radius"])
        start,end=vector(value["start"]),vector(value["end"])
        radius=request_float(value["radius"])
        length=float(np.linalg.norm(end-start))
        if not np.isfinite(length) or length<=0 or radius<=0:
            raise AnalysisError("invalid_selection","Cylinder needs a finite nonzero axis and positive radius")
        return dict(shape=shape,start=tokens(start),end=tokens(end),radius=float_token(radius))
    if shape=="slab":
        keys(value,["shape","center","normal","tangent","width","height","thickness"],
             ["center","normal","tangent","width","height","thickness"])
        normal,tangent=vector(value["normal"]),vector(value["tangent"])
        nn,tn=float(np.linalg.norm(normal)),float(np.linalg.norm(tangent))
        if not np.isfinite(nn+tn) or nn==0 or tn==0 or abs(float(normal@tangent)/(nn*tn))>1e-10:
            raise AnalysisError("invalid_selection","Slab normal and tangent must be finite, nonzero and perpendicular")
        extents={k:request_float(value[k]) for k in ("width","height","thickness")}
        if min(extents.values())<=0:raise AnalysisError("invalid_selection","Slab extents must be positive")
        if canonical and (abs(nn-1)>1e-12 or abs(tn-1)>1e-12):
            raise AnalysisError("invalid_selection","Saved slab basis must be normalized")
        return dict(shape=shape,center=tokens(vector(value["center"])),normal=tokens(normal if canonical else normal/nn),
                    tangent=tokens(tangent if canonical else tangent/tn),**{k:float_token(v) for k,v in extents.items()})
    raise AnalysisError("invalid_selection","Supported regions: box, sphere, cylinder, finite slab")


def inside(points, definition):
    p=np.asarray(points,dtype=np.float64)
    valid=np.isfinite(p).all(axis=1)
    shape=definition["shape"]
    with np.errstate(over="ignore",invalid="ignore"):
        if shape=="box":
            return valid & np.all(p>=vector(definition["lower"]),axis=1) & np.all(p<=vector(definition["upper"]),axis=1)
        if shape=="sphere":
            delta=p-vector(definition["center"])
            return valid & (np.hypot(np.hypot(delta[:,0],delta[:,1]),delta[:,2])<=request_float(definition["radius"]))
        if shape=="cylinder":
            delta=p-vector(definition["start"]);axis=vector(definition["end"])-vector(definition["start"])
            length=np.linalg.norm(axis);axis/=length;along=delta@axis
            radial=delta-along[:,None]*axis
            return valid & (along>=0) & (along<=length) & (np.linalg.norm(radial,axis=1)<=request_float(definition["radius"]))
        normal,tangent=vector(definition["normal"]),vector(definition["tangent"])
        delta=p-vector(definition["center"])
        return valid & (np.abs(delta@normal)<=request_float(definition["thickness"])/2) & (np.abs(delta@tangent)<=request_float(definition["width"])/2) & (np.abs(delta@np.cross(normal,tangent))<=request_float(definition["height"])/2)


def predicate(value):
    if not isinstance(value,list) or len(value)>32:
        raise AnalysisError("invalid_selection","Predicate needs at most 32 typed clauses")
    result=[]
    for clause in value:
        keys(clause,["channel","component","op","values","lower","upper","include_lower","include_upper"],["channel","op"])
        if not isinstance(clause["channel"],str) or not re.fullmatch(r"[a-z][a-z0-9_]*",clause["channel"]):
            raise AnalysisError("invalid_selection","Source channel name required")
        op=clause["op"]
        if op not in ("in","not_in","finite","range"):
            raise AnalysisError("invalid_selection","Unsupported predicate operation")
        row=dict(channel=clause["channel"],component=clause.get("component"),op=op)
        if row["component"] is not None:row["component"]=integer(row["component"],"component",0,3)
        if op in ("in","not_in"):
            values=clause.get("values")
            if not isinstance(values,list) or len(values)>MAX_MEMBERS or not all(isinstance(v,str) for v in values):
                raise AnalysisError("invalid_selection","Integer membership values must be decimal strings")
            row["values"]=[str(v) for v in sorted({_signed_integer(v) for v in values})]
        if op=="range":
            for bound in ("lower","upper"):
                v=clause.get(bound)
                # Strings remain integer thresholds; float tokens retain source precision.
                row[bound]=str(_signed_integer(v)) if isinstance(v,str) else float_token(request_float(v))
                flag=clause.get("include_"+bound,True)
                if type(flag) is not bool:raise AnalysisError("invalid_selection","Range inclusivity must be boolean")
                row["include_"+bound]=flag
            if _threshold(row["lower"])>_threshold(row["upper"]):
                raise AnalysisError("invalid_selection","Range lower bound exceeds upper")
        result.append(row)
    return result


def _signed_integer(value):
    if not re.fullmatch(r"0|-?[1-9][0-9]{0,18}",value) or not -(2**63)<=int(value)<2**63:
        raise AnalysisError("invalid_selection","Integer threshold outside int64")
    return int(value)


def _threshold(value):
    return _signed_integer(value) if isinstance(value,str) else request_float(value)


def channel_values(sample, name, component=None):
    if name not in sample.arrays:return None
    values=sample.arrays[name]
    if sample.descriptors[name]["association"]=="sample":values=values.reshape(-1)
    if values.ndim==1:
        if component is not None:raise AnalysisError("association","Scalar channel has no component")
    elif values.ndim==2 and component is not None and component<values.shape[1]:values=values[:,component]
    else:raise AnalysisError("association","Select a source vector component explicitly")
    return values


def apply_predicate(sample, rows, clauses, association):
    keep=np.ones(len(rows),dtype=bool);unknown=np.zeros(len(rows),dtype=bool)
    for clause in clauses:
        name=clause["channel"]
        values=channel_values(sample,name,clause["component"])
        if values is None:
            unknown[:]=True;continue
        source_association=sample.descriptors[name]["association"]
        if ("grid" if source_association=="sample" else source_association)!=association:
            raise AnalysisError("association","Predicate and selection association differ")
        values=values[rows];valid=np.isfinite(values);unknown|=~valid
        if clause["op"]=="finite":continue
        if clause["op"] in ("in","not_in"):
            if values.dtype.kind not in "iu":raise AnalysisError("association","Membership predicates require integer source channels")
            wanted=np.asarray([_signed_integer(v) for v in clause["values"]],dtype=np.int64)
            matched=np.isin(values,wanted)
            keep &= matched if clause["op"]=="in" else ~matched
        else:
            lower,upper=_threshold(clause["lower"]),_threshold(clause["upper"])
            if values.dtype.kind in "iu" and (not isinstance(lower,int) or not isinstance(upper,int)):
                raise AnalysisError("invalid_selection","Integer channels require decimal-string range bounds")
            keep &= (values>=lower if clause["include_lower"] else values>lower)
            keep &= (values<=upper if clause["include_upper"] else values<upper)
    return rows[keep & ~unknown],int(np.count_nonzero(unknown))


def _source_matches(source, ref):
    expected=source.identity()
    if not isinstance(ref,dict) or any(ref.get(k)!=expected[k] for k in ("format","uuid","committed_bytes","sha256")):
        raise AnalysisError("source_changed","Selection belongs to a different committed source")


def define(source, arguments,*,canonical=False):
    keys(arguments,["key","revision","name","object","kind","association","selector","coordinates","predicate","creation","display"],
         ["object","kind","selector"])
    oid=arguments["object"];kind=arguments["kind"]
    if oid not in source.objects or kind not in KINDS:
        raise AnalysisError("invalid_selection","Unknown selection object/kind")
    obj=source.objects[oid];samples=source.samples[oid]
    selector=dict(arguments["selector"])
    association=arguments.get("association","grid" if obj["kind"]=="volume" else "vertex")
    allowed={"particles":{"vertex"},"mesh":{"vertex","face"},"volume":{"grid","location"}}
    if association not in allowed[obj["kind"]]:raise AnalysisError("association","Association does not belong to the object")
    coords=arguments.get("coordinates",{"space":"viewer_world","units":source.metadata.get("position_unit",obj.get("units","unknown"))})
    keys(coords,["space","units"],["space","units"])
    if coords["space"] not in ("viewer_world","data_local") or not isinstance(coords["units"],str):
        raise AnalysisError("invalid_selection","Coordinate space and units required")
    policy="fixed_cohort"
    if kind=="particle_ids" or kind=="mesh_vertices" and ("ids" in selector or "ids_asset" in selector):
        key="particle_id" if kind=="particle_ids" else "vertex_id"
        expected="particles" if kind=="particle_ids" else "mesh"
        if obj["kind"]!=expected or obj.get("identity") not in ("persistent_i8","stable_topology"):
            raise AnalysisError("anonymous","Persistent selection requires declared source IDs")
        if association!="vertex":raise AnalysisError("association","IDs identify vertices/particles")
        keys(selector,["ids","ids_asset"])
        selector=packed_members(source,selector,"ids",maximum=2**63-1)
    elif kind in ("sample_rows","mesh_vertices"):
        if obj["kind"]!=("particles" if kind=="sample_rows" else "mesh") or association!="vertex":
            raise AnalysisError("association","Sample rows require particle/mesh vertices")
        keys(selector,["index","rows","rows_asset"],["index"])
        index=integer(selector["index"],"sample index",0,len(samples)-1)
        count=_count(samples[index],"vertex")
        selector=dict(index=index,**packed_members(source,selector,"rows",maximum=count-1))
        policy="static" if obj["static"] else "sample_local"
    elif kind=="mesh_object":
        keys(selector,[])
        if obj["kind"]!="mesh":raise AnalysisError("association","Mesh object requires a mesh")
        policy="static" if obj["static"] else "spatial_each_sample"
    elif kind in ("mesh_faces","mesh_point","grid_samples"):
        is_grid=kind=="grid_samples"
        if obj["kind"]!=("volume" if is_grid else "mesh"):
            raise AnalysisError("association","Address kind differs from source object")
        association="grid" if is_grid else "face"
        keys(selector,["index","rows","rows_asset","xyz","xyz_asset","face","barycentric","epoch"],["index"])
        index=integer(selector["index"],"sample index",0,len(samples)-1)
        current_epoch=epoch(source,oid,index)
        if "epoch" in selector and selector["epoch"]!=current_epoch:
            raise AnalysisError("topology_changed","Saved epoch differs from source history")
        if is_grid:
            shape=samples[index]["descriptor"]["geometry"]["shape"]
            if "xyz_asset" in selector:
                values=source.member_array(selector["xyz_asset"])
                if "xyz" in selector or values.ndim!=2 or values.shape[1]!=3 or np.any(values<0) or np.any(values>=np.asarray(shape[::-1])) or not np.array_equal(values,np.unique(values,axis=0)):
                    raise AnalysisError("invalid_asset","Grid asset must contain sorted unique xyz addresses in this geometry")
                selector=dict(index=index,xyz_asset=selector["xyz_asset"],epoch=current_epoch)
                policy="static" if obj["static"] else "topology_epoch"
            else:
                xyz=selector.get("xyz")
                if not isinstance(xyz,list) or len(xyz)>MAX_MEMBERS:raise AnalysisError("selection_limit","Grid addresses exceed budget")
                points=set()
                for p in xyz:
                    if not isinstance(p,list) or len(p)!=3:raise AnalysisError("invalid_selection","Grid address is xyz")
                    points.add(tuple(integer(v,"grid index",0,shape[2-j]-1) for j,v in enumerate(p)))
                points=[list(p) for p in sorted(points)]
                if len(points)>INLINE_MEMBERS:
                    if source.assets is None:raise AnalysisError("selection_limit","Large grid sets require the owned worker asset store")
                    selector=dict(index=index,xyz_asset=source.assets.put(np.asarray(points,dtype="<i8"),source.context),epoch=current_epoch)
                else:selector=dict(index=index,xyz=points,epoch=current_epoch)
        elif kind=="mesh_faces":
            selector=dict(index=index,epoch=current_epoch,**packed_members(source,selector,"rows",maximum=_count(samples[index],"face")-1))
        else:
            face=integer(selector.get("face"),"face",0,_count(samples[index],"face")-1)
            bary=vector(selector.get("barycentric"))
            if np.any(bary<0) or np.any(bary>1) or abs(float(np.sum(bary))-1)>1e-12:
                raise AnalysisError("invalid_selection","Barycentric coordinates must be nonnegative and sum to one")
            selector=dict(index=index,face=face,barycentric=tokens(bary),epoch=current_epoch)
        policy="static" if obj["static"] else "topology_epoch"
    elif kind=="probe":
        if obj["kind"]!="volume":raise AnalysisError("association","A source probe requires a grid")
        keys(selector,["coordinate"],["coordinate"])
        selector=dict(coordinate=tokens(vector(selector["coordinate"])));association="location";policy="fixed_location"
    elif kind=="roi":
        selector=region(selector,canonical=canonical);policy="spatial_each_sample"
    elif kind=="derived_surface":
        keys(selector,["index","artifact_sha256","threshold","algorithm","face","barycentric","artifact","channel"],
             ["index","artifact_sha256","threshold","algorithm"])
        if obj["kind"]!="volume" or not re.fullmatch(r"[a-f0-9]{64}",selector["artifact_sha256"]):
            raise AnalysisError("invalid_selection","Derived selection requires a source grid and exact artifact hash")
        selector["index"]=integer(selector["index"],"source sample",0,len(samples)-1)
        if not isinstance(selector["algorithm"],str) or len(selector["algorithm"])>256:raise AnalysisError("invalid_selection","Derived algorithm provenance required")
        selector["threshold"]=float_token(request_float(selector["threshold"]))
        if "artifact" in selector:
            keys(selector["artifact"],["path","sha256","signature"],["path","sha256","signature"])
            if selector["artifact"]["sha256"]!=selector["artifact_sha256"] or not isinstance(selector.get("channel"),str):
                raise AnalysisError("invalid_selection","Artifact reference and channel must match")
        if "barycentric" in selector and "face" not in selector:raise AnalysisError("invalid_selection","Artifact barycentric address requires a face")
        if "face" in selector:selector["face"]=integer(selector["face"],"artifact face",0,10_000_000)
        if "barycentric" in selector:
            bary=vector(selector["barycentric"])
            if np.any(bary<0) or abs(float(bary.sum())-1)>1e-12:raise AnalysisError("invalid_selection","Invalid artifact barycentric address")
            selector["barycentric"]=tokens(bary)
        policy="sample_local";association="location"
    key=arguments.get("key","selection")
    if not isinstance(key,str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}",key):raise AnalysisError("invalid_selection","Invalid selection key")
    name=arguments.get("name",kind.replace("_"," "))
    if not isinstance(name,str) or len(name)>128:raise AnalysisError("invalid_selection","Name exceeds 128 characters")
    display=arguments.get("display",dict(visible=True,color=[1.,.7,.1,1.]))
    keys(display,["visible","color"],["visible","color"])
    color=request_vector(display["color"],"color",4)
    if type(display["visible"]) is not bool or not all(0<=v<=1 for v in color):raise AnalysisError("invalid_selection","Invalid highlight color/visibility")
    creation=arguments.get("creation",{})
    if not isinstance(creation,dict):raise AnalysisError("invalid_selection","Creation evidence must be an object")
    return dict(key=key,revision=integer(arguments.get("revision",1),"revision",1,2**31-1),name=name,
                source=source.identity(),object=oid,kind=kind,association=association,time_policy=policy,
                selector=selector,coordinates=dict(coords),predicate=predicate(arguments.get("predicate",[])),
                creation=dict(creation),missing_policy="unavailable",display=dict(visible=display["visible"],color=color))


def validate(source, definition):
    keys(definition,["key","revision","name","source","object","kind","association","time_policy","selector", "coordinates","predicate","creation","missing_policy","display"],
         ["key","revision","name","source","object","kind","association","time_policy","selector","coordinates","predicate","creation","missing_policy","display"])
    _source_matches(source,definition["source"])
    candidate=define(source,{k:v for k,v in definition.items() if k not in ("source","time_policy","missing_policy")},canonical=True)
    if candidate["time_policy"]!=definition["time_policy"] or definition["missing_policy"]!="unavailable":
        raise AnalysisError("invalid_selection","Selection time/missing policy differs from its identity contract")
    return candidate


def _count(record, association):
    if association=="face":
        return next(a["shape"][0] for a in record["descriptor"]["arrays"] if a["name"]=="triangles")
    if association=="grid":return int(np.prod(record["descriptor"]["geometry"]["shape"]))
    return next(a["shape"][0] for a in record["descriptor"]["arrays"] if a["name"]=="position")


def needed_channels(definition):
    names={c["channel"] for c in definition["predicate"]}
    if definition["kind"]=="roi" and definition["association"] in ("vertex","face"):names.add("position")
    return names


def grid_positions(geometry, rows):
    z,y,x=np.unravel_index(rows,geometry["shape"])
    return np.column_stack((x,y,z))*np.asarray(geometry["spacing"])+np.asarray(geometry["origin"])


def member_positions(obj, sample, rows, association, *, space="viewer_world"):
    if association=="grid":positions=grid_positions(sample.record["descriptor"]["geometry"],rows)
    elif association=="face":positions=np.mean(sample.arrays["position"][sample.arrays["triangles"][rows]],axis=1,dtype=np.float64)
    else:positions=sample.arrays["position"][rows]
    return world_positions(obj,positions) if space=="viewer_world" else np.asarray(positions,dtype=np.float64)


@dataclass
class Membership:
    rows: np.ndarray
    selected: int
    present: int
    unknown: int=0
    status: str="source"
    reason: str|None=None


def resolve(source, definition, index, sample):
    """Definition must be validated once before the interval. Never cache last rows."""
    oid=definition["object"];obj=source.objects[oid];sel=definition["selector"];kind=definition["kind"]
    integer(index,"sample index",0,len(source.samples[oid])-1)
    empty=lambda selected,reason:Membership(np.empty(0,dtype=np.int64),selected,0,status="unavailable",reason=reason)
    association=definition["association"]
    if kind in ("probe","derived_surface","mesh_point"):
        if kind=="derived_surface":return empty(1,"approximate_artifact_only")
        if kind=="mesh_point" and epoch(source,oid,index)!=sel["epoch"]:return empty(1,"topology_changed")
        return Membership(np.array([sel["face"]],dtype=np.int64) if kind=="mesh_point" else np.empty(0,dtype=np.int64),1,1)
    if definition["time_policy"]=="sample_local" and index!=sel["index"]:
        return empty(member_count(sel,"rows"),"sample_local")
    if kind in ("particle_ids","mesh_vertices") and ("ids" in sel or "ids_asset" in sel):
        name="particle_id" if kind=="particle_ids" else "vertex_id"
        wanted=members(source,sel,"ids")
        rows=np.flatnonzero(np.isin(sample.arrays[name],wanted));selected=len(wanted)
    elif kind in ("sample_rows","mesh_vertices","mesh_faces"):
        selected=member_count(sel,"rows")
        if "epoch" in sel and epoch(source,oid,index)!=sel["epoch"]:return empty(selected,"topology_changed")
        rows=members(source,sel,"rows")
    elif kind=="grid_samples":
        selected=member_count(sel,"xyz")
        if epoch(source,oid,index)!=sel["epoch"]:return empty(selected,"geometry_changed")
        xyz=members(source,sel,"xyz")
        rows=np.sort(np.ravel_multi_index(tuple(xyz[:,::-1].T),sample.record["descriptor"]["geometry"]["shape"]))
    else:
        count=_count(sample.record,association);rows=np.arange(count,dtype=np.int64)
        if kind=="roi":
            positions=member_positions(obj,sample,rows,association,space=definition["coordinates"]["space"])
            rows=rows[inside(positions,sel)]
        selected=len(rows)
    present=len(rows)
    if present==0 and selected>0:return empty(selected,"absent_at_sample")
    rows,unknown=apply_predicate(sample,rows,definition["predicate"],association)
    return Membership(rows,selected,present,unknown)


def combine(source, definitions, index, sample, operation):
    if not definitions or len(definitions)>256 or operation not in ("union","intersection"):
        raise AnalysisError("invalid_selection","Group reduction needs explicit union/intersection")
    first=definitions[0]
    for definition in definitions:
        if any(definition[k]!=first[k] for k in ("source","object","association")):
            raise AnalysisError("incompatible_group","Mixed sources/objects/associations require separate series")
        if definition["kind"] in ("probe","mesh_point","derived_surface"):
            raise AnalysisError("incompatible_group","Location/approximate selections are not discrete member sets")
    rows=resolve(source,first,index,sample).rows
    for d in definitions[1:]:
        other=resolve(source,d,index,sample).rows
        rows=np.union1d(rows,other) if operation=="union" else np.intersect1d(rows,other)
    return rows

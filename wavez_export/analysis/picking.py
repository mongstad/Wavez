"""Deterministic source-geometry screen queries on the analysis worker."""

from contextlib import ExitStack
import math
import numpy as np

from .contracts import AnalysisError,integer,request_float,request_vector,float_token
from .sampling import interpolated_positions,source_bracket,world_positions,probe_array,valid_axis
from .selection_jobs import workspace
from . import selectors as S

PICK_POLICY="g4-source-pick-1"


def matrix(value,rows,columns):
    return np.asarray(request_vector(value,"camera matrix",rows*columns),dtype=np.float64).reshape(rows,columns)


def project(positions,camera):
    view=matrix(camera["view"],3,4);projection=matrix(camera["projection"],4,4)
    size=np.asarray(request_vector(camera["viewport"],"viewport",2))
    if np.any(size<=0) or np.any(size>16384):raise AnalysisError("invalid_pick","Invalid viewport size")
    local=positions@view[:,:3].T+view[:,3]
    clip=np.column_stack((local,np.ones(len(local))))@projection.T
    with np.errstate(divide="ignore",invalid="ignore"):
        ndc=clip[:,:3]/clip[:,3,None]
    eligible=np.isfinite(ndc).all(axis=1)&(-local[:,2]>=request_float(camera["near"]))&(-local[:,2]<=request_float(camera["far"]))
    pixels=np.column_stack(((ndc[:,0]+1)*size[0]/2,(1-ndc[:,1])*size[1]/2))
    return pixels,-local[:,2],eligible


def polygon_mask(points,polygon):
    if not isinstance(polygon,list) or not 3<=len(polygon)<=256:raise AnalysisError("invalid_pick","Polygon requires 3–256 screen vertices")
    poly=np.array([request_vector(v,"screen point",2) for v in polygon])
    result=np.zeros(len(points),dtype=bool);boundary=result.copy()
    x,y=points[:,0],points[:,1]
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        dx,dy=b-a
        cross=(x-a[0])*dy-(y-a[1])*dx
        tolerance=1e-9*max(1.,abs(dx)+abs(dy))
        boundary|=(np.abs(cross)<=tolerance)&(x>=min(a[0],b[0])-1e-9)&(x<=max(a[0],b[0])+1e-9)&(y>=min(a[1],b[1])-1e-9)&(y<=max(a[1],b[1])+1e-9)
        if dy!=0:result^=((a[1]>y)!=(b[1]>y)) & (x<(b[0]-a[0])*(y-a[1])/dy+a[0])
    return result|boundary


def triangle_hit(origin,direction,positions,triangles,*,backface="both",orientation=1.,context=None,minimum=0.,maximum=math.inf,face_mask=None):
    if backface not in ("front","both"):raise AnalysisError("invalid_pick","Backface policy must be front or both")
    winner=None
    # Chunked exact ray tests preserve source face rows, before GPU expansion.
    for start in range(0,len(triangles),4096):
        if context:context.check()
        tri=positions[triangles[start:start+4096]]
        e1,e2=tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]
        p=np.cross(np.broadcast_to(direction,e2.shape),e2);det=np.sum(e1*p,axis=1)
        scale=np.linalg.norm(e1,axis=1)*np.linalg.norm(e2,axis=1)*np.linalg.norm(direction)
        valid=(det*orientation>1e-12*scale) if backface=="front" else (np.abs(det)>1e-12*scale)
        with np.errstate(divide="ignore",invalid="ignore"):
            delta=origin-tri[:,0];u=np.sum(delta*p,axis=1)/det
            q=np.cross(delta,e1);v=np.sum(direction*q,axis=1)/det;t=np.sum(e2*q,axis=1)/det
        valid &= np.isfinite(t)&(u>=0)&(v>=0)&(u+v<=1)&(t>minimum)&(t<maximum)
        if face_mask is not None:valid &= face_mask[start:start+len(tri)]
        for i in np.flatnonzero(valid):
            candidate=(float(t[i]),start+int(i),[float(1-u[i]-v[i]),float(u[i]),float(v[i])])
            if winner is None or candidate[:2]<winner[:2]:winner=candidate;maximum=candidate[0]
    return winner


def ray_interval(origin,direction,camera):
    view=matrix(camera["view"],3,4)
    start=-float(view[2,:3]@origin+view[2,3]);rate=-float(view[2,:3]@direction)
    near,far=request_float(camera["near"]),request_float(camera["far"])
    if not 0<near<far or rate<=0:raise AnalysisError("invalid_pick","Ray must face a valid camera depth interval")
    return max(0.,(near-start)/rate),(far-start)/rate


def _style_channel(sample,name):
    if name=="fixed":return None
    if name in sample.arrays:return sample.arrays[name]
    if name=="velocity_magnitude" and "velocity" in sample.arrays:
        # G3's display helper uses Vector3/float32. This is eligibility only;
        # numerical analysis never calls this helper for velocity measurements.
        with np.errstate(over="ignore",invalid="ignore"):
            return np.linalg.norm(sample.arrays["velocity"].astype(np.float32),axis=1)
    return None


def _display32(values):
    with np.errstate(over="ignore",invalid="ignore",under="ignore"):return np.asarray(values,dtype=np.float32)


def _display_normalized(values):
    finite=values[np.isfinite(values)]
    if not len(finite):return np.full(len(values),-1.)
    low,high=_display32([finite.min(),finite.max()]).astype(np.float64)
    if not np.isfinite([low,high]).all():return np.full(len(values),-1.)
    with np.errstate(over="ignore",invalid="ignore"):
        return np.full(len(values),.5) if high==low else np.clip((values-low)/(high-low),0,1)


def marker_mask(sample,style,count):
    """Only copied display eligibility; it never supplies scientific values."""
    keep=np.ones(count,dtype=bool)
    alpha=np.ones(count,dtype=np.float64);rgb=None;brightness=np.ones(count,dtype=np.float32)
    if not style.get("visible",True):return ~keep
    if "opacity" in sample.arrays:
        values=sample.arrays["opacity"];alpha*=np.clip(values,0,1);keep &= np.isfinite(values)
    hidden=style.get("hidden_types",[])
    if hidden and "particle_type" in sample.arrays:
        keep &= ~np.isin(sample.arrays["particle_type"],np.array([S._signed_integer(v) for v in hidden],dtype=np.int64))
    color=style.get("color","fixed")
    values=_style_channel(sample,color)
    if values is None:color="fixed" # G3 falls back when a per-sample channel is absent.
    if color=="visual_color" and values is not None:
        values=_display32(values)
        keep &= np.isfinite(values).all(axis=1)
        if values.shape[1]==4:alpha*=np.clip(values[:,3],0,1)
        rgb=values[:,:3]
        keep &= np.any(values[:,:3]>0,axis=1)
    elif color not in ("fixed","visual_color"):
        if values is None:keep[:]=False
        else:
            keep &= np.isfinite(values)
            if style.get("log",False):keep &= values>0
            bounds=style.get("color_bounds")
            if bounds is None:keep[:]=False
            else:
                low,high=request_vector(bounds,"color range",2)
                if high<low or style.get("log",False) and low<=0 or style.get("cyclic",False) and (high<=low or style.get("log",False)):keep[:]=False
                elif not style.get("clamp",True) and not style.get("cyclic",False):keep &= (values>=low)&(values<=high)
    for role,direct in (("size","visual_size"),("brightness","visual_brightness")):
        name=style.get(role,"fixed");values=_style_channel(sample,name)
        if values is None:continue
        keep &= np.isfinite(values)
        mapped=np.maximum(values,0) if name==direct else _display_normalized(values)
        if name!=direct and role=="size":mapped=.07+.48*mapped
        mapped=_display32(mapped);keep &= np.isfinite(mapped)&(mapped>0)
        if role=='brightness':brightness=mapped
    keep &= _display32(alpha)>0
    if rgb is not None:
        with np.errstate(over='ignore',invalid='ignore',under='ignore'):
            displayed=rgb*brightness[:,None]
        keep &= np.isfinite(displayed).all(axis=1)&np.any(displayed>0,axis=1)
    return keep


def dispatch(source,arguments):
    S.keys(arguments,["object","time","index","mode","camera","point","polygon","radius","style","predicate","clip","occlusion","occluders","backface","ray","plane","key","name"],
           ["object","mode","camera"])
    oid=arguments["object"]
    if oid not in source.objects:raise AnalysisError("unknown_object","Pick target object unavailable")
    obj=source.objects[oid];mode=arguments["mode"]
    if mode not in ("click","polygon","mesh_face","mesh_point","mesh_vertex","probe"):
        raise AnalysisError("invalid_pick","Unsupported screen tool")
    if "index" in arguments:
        index=integer(arguments["index"],"committed sample",0,len(source.samples[oid])-1)
        time=source.samples[oid][index]["time"]
        point=dict(a=index,b=index,alpha=0.,status="source" if valid_axis(source.samples[oid]) else "index_only",time=time,source_times=[float_token(time)])
        if arguments.get("occluders") and not valid_axis(source.samples[oid]):
            raise AnalysisError("invalid_axis","Cannot align independent occluders to an index-only clock")
    else:
        time=request_float(arguments.get("time"),"committed time")
        point=source_bracket(source,oid,time)
    if point["status"]=="unavailable":raise AnalysisError("unavailable","Pick target has no committed sample")
    index=point["a"];camera=arguments["camera"]
    S.keys(camera,["view","projection","viewport","near","far","origin","orthographic"],["view","projection","viewport","near","far","origin"])
    origin=S.vector(camera["origin"])
    style=arguments.get("style",{})
    if not style.get("visible",True):raise AnalysisError("hidden","Screen picking requires a visible target layer")
    pred=S.predicate(arguments.get("predicate",[]))
    occlusion=arguments.get("occlusion","through")
    if occlusion not in ("through","opaque"):raise AnalysisError("invalid_pick","Choose through or opaque geometry selection")
    temporary=dict(object=oid)
    with workspace(source,temporary),ExitStack() as stack:
        specs={a["name"]:a for a in source.samples[oid][index]["descriptor"]["arrays"]}
        needed={"position","opacity","particle_type","visual_color",style.get("color","fixed"),style.get("size","fixed"),style.get("brightness","fixed")}|{c["channel"] for c in pred}
        if "velocity_magnitude" in needed:needed.add("velocity")
        if mode=="probe":needed={arguments.get("plane",{}).get("channel","")}
        sample=stack.enter_context(source.read_sample(oid,index,needed & specs.keys()))
        later=sample
        if obj["kind"]!="volume" and point["b"]!=index:later=stack.enter_context(source.read_sample(oid,point["b"],["position"]))
        positions,statuses=interpolated_positions(obj,sample.arrays,later.arrays,point["alpha"]) if obj["kind"]!="volume" else (None,None)
        selector={};kind="";association="vertex";unknown=0
        if mode in ("mesh_face","mesh_point","probe"):
            ray=arguments.get("ray",{});S.keys(ray,["origin","direction"],["origin","direction"])
            ro,rd=S.vector(ray["origin"]),S.vector(ray["direction"])
            length=np.linalg.norm(rd)
            if not np.isfinite(length) or length==0:raise AnalysisError("invalid_pick","Nonzero finite ray required")
            rd/=length
            minimum,maximum=ray_interval(ro,rd,camera)
            if mode=="probe":
                if obj["kind"]!="volume":raise AnalysisError("invalid_pick","Probe placement requires a volume slice or plane")
                plane=arguments.get("plane",{});S.keys(plane,["normal","distance","channel"],["normal","distance","channel"])
                normal=S.vector(plane["normal"]);norm=float(np.linalg.norm(normal))
                if not np.isfinite(norm) or norm==0:raise AnalysisError("invalid_pick","Slice normal must be finite and nonzero")
                normal/=norm;den=float(normal@rd)
                if abs(den)<1e-14:raise AnalysisError("no_hit","Ray parallel to probe plane")
                t=(request_float(plane["distance"])-float(normal@ro))/den
                if not minimum<t<maximum:raise AnalysisError("no_hit","Probe plane outside camera depth bounds")
                location=ro+t*rd;channel=plane["channel"]
                if channel not in sample.arrays:raise AnalysisError("missing_channel","Plane probe source channel unavailable")
                hit=probe_array(sample.arrays[channel],sample.record["descriptor"]["geometry"],obj["data_to_world"],location)
                if hit["status"]=="unavailable":raise AnalysisError("no_hit",hit["reason"])
                selector=dict(coordinate=S.tokens(location));kind="probe";association="location"
            else:
                if obj["kind"]!="mesh":raise AnalysisError("invalid_pick","Mesh face tool requires a mesh")
                orientation=float(np.sign(np.linalg.det(np.asarray(obj["data_to_world"]).reshape(3,4)[:,:3])))
                faces=sample.arrays["triangles"]
                allowed,unknown=S.apply_predicate(sample,np.arange(len(faces)),pred,"face")
                mask=np.zeros(len(faces),dtype=bool);mask[allowed]=True
                hit=triangle_hit(ro,rd,positions,faces,backface=arguments.get("backface","front"),orientation=orientation,context=source.context,minimum=minimum,maximum=maximum,face_mask=mask)
                if hit is None:raise AnalysisError("no_hit","No source triangle under this ray")
                _,face,bary=hit;association="face"
                location=ro+hit[0]*rd
                kind="mesh_faces" if mode=="mesh_face" else "mesh_point"
                selector=dict(index=index,rows=[face]) if mode=="mesh_face" else dict(index=index,face=face,barycentric=bary)
            if occlusion=="opaque" and not len(_unoccluded(source,arguments,stack,location[None,:],np.array([0]),origin,camera,time)):
                raise AnalysisError("no_hit","Source hit is behind visible opaque geometry")
        else:
            if obj["kind"]=="volume":raise AnalysisError("ambiguous_depth","A volume click requires a plane/depth or typed coordinate")
            pixels,depth,eligible=project(positions,camera)
            if obj["kind"]=="particles":eligible &= marker_mask(sample,style,len(positions))
            if "clip" in arguments:
                clip=arguments["clip"];normal=S.vector(clip["normal"]);distance=request_float(clip["distance"]);width=request_float(clip["half_width"])
                if width<0:raise AnalysisError("invalid_pick","Clip width must be nonnegative")
                eligible &= np.abs(positions@normal-distance)<=width
            rows=np.flatnonzero(eligible);rows,unknown=S.apply_predicate(sample,rows,pred,"vertex")
            if mode=="polygon":rows=rows[polygon_mask(pixels[rows],arguments.get("polygon"))]
            else:
                clicked=np.asarray(request_vector(arguments.get("point"),"click pixel",2));radius=request_float(arguments.get("radius",8))
                if not 0<radius<=128:raise AnalysisError("invalid_pick","Pixel tolerance must be in (0,128]")
                distance=np.linalg.norm(pixels-clicked,axis=1);rows=rows[distance[rows]<=radius]
            if occlusion=="opaque" and len(rows):rows=_unoccluded(source,arguments,stack,positions,rows,origin,camera,time)
            id_name="particle_id" if obj["kind"]=="particles" else "vertex_id"
            ids=sample.arrays.get(id_name)
            if mode!="polygon" and len(rows):
                order=np.lexsort((rows if ids is None else ids[rows],depth[rows],distance[rows]));rows=rows[order[:1]]
            if not len(rows):raise AnalysisError("no_hit","No eligible source center in the screen query")
            kind="particle_ids" if obj["kind"]=="particles" and ids is not None else ("sample_rows" if obj["kind"]=="particles" else "mesh_vertices")
            selector=dict(ids=[str(int(i)) for i in ids[rows]]) if ids is not None else dict(index=index,rows=rows.tolist())
        creation=dict(policy=PICK_POLICY,sampling=point,camera=camera,mode=mode,occlusion=occlusion,
                      query={k:v for k,v in arguments.items() if k not in ("key","name","object","camera")},
                      placement_precision="source float64; captured camera/ray may originate as float32",unknown_excluded=unknown)
        definition=S.define(source,dict(key=arguments.get("key","picked"),name=arguments.get("name","Screen selection"),object=oid,kind=kind,association=association,selector=selector,creation=creation))
        return dict(selection=definition,sampling=point,policy=PICK_POLICY)


def _unoccluded(source,arguments,stack,positions,rows,origin,camera,time):
    occluders=arguments.get("occluders",[])
    if not isinstance(occluders,list) or len(occluders)>16:raise AnalysisError("invalid_pick","At most 16 explicitly visible opaque layers")
    meshes=[];planes=[];face_count=0
    for entry in occluders:
        source.context.check()
        oid=entry["object"];obj=source.objects[oid]
        if not entry.get("visible",False):continue
        point=source_bracket(source,oid,time)
        if point["status"]=="unavailable":continue
        if obj["kind"]=="mesh" and not entry.get("wireframe",False):
            stack.enter_context(workspace(source,dict(object=oid)))
            a=stack.enter_context(source.read_sample(oid,point["a"],["position"]))
            b=a if point["a"]==point["b"] else stack.enter_context(source.read_sample(oid,point["b"],["position"]))
            p,_=interpolated_positions(obj,a.arrays,b.arrays,point["alpha"])
            orientation=float(np.sign(np.linalg.det(np.asarray(obj["data_to_world"]).reshape(3,4)[:,:3])))
            meshes.append((p,a.arrays["triangles"],orientation));face_count+=len(a.arrays["triangles"])
        elif obj["kind"]=="volume" and entry.get("slice",False) and request_float(entry.get("opacity",0))>=1:
            sample=stack.enter_context(source.read_sample(oid,point["a"],[entry["channel"]]))
            planes.append((entry,obj,sample))
    if len(rows)*face_count>5_000_000:
        raise AnalysisError("work_limit","Opaque pick exceeds 5 million exact ray/face tests; use a smaller query or through mode")
    view=matrix(camera["view"],3,4);rotation_inverse=np.linalg.inv(view[:,:3])
    kept=[]
    for row in rows:
        source.context.check();ro=origin
        if camera.get("orthographic",False):
            local=positions[row]@view[:,:3].T+view[:,3];local[2]=0
            ro=(local-view[:,3])@rotation_inverse.T
        delta=positions[row]-ro;length=np.linalg.norm(delta)
        if not np.isfinite(length) or length==0:continue
        direction=delta/length;minimum,_=ray_interval(ro,direction,camera)
        blocked=any(triangle_hit(ro,direction,p,t,backface="front",orientation=orientation,context=source.context,minimum=minimum,maximum=length*(1-1e-12)) is not None for p,t,orientation in meshes)
        if blocked:continue
        for entry,obj,sample in planes:
            normal=S.vector(entry["normal"]);norm=float(np.linalg.norm(normal))
            if not np.isfinite(norm) or norm==0:raise AnalysisError("invalid_pick","Slice normal must be finite and nonzero")
            normal/=norm;den=float(normal@direction)
            if abs(den)<1e-14:continue
            distance=(request_float(entry["distance"])-float(normal@ro))/den
            if not minimum<distance<length*(1-1e-12):continue
            location=ro+distance*direction
            if entry.get("clip",False) and float(location@S.vector(entry["clip_normal"]))>request_float(entry["clip_distance"]):continue
            result=probe_array(sample.arrays[entry["channel"]],sample.record["descriptor"]["geometry"],obj["data_to_world"],location)
            if result["status"]!="unavailable":blocked=True;break
        if not blocked:kept.append(row)
    return np.asarray(kept,dtype=np.int64)

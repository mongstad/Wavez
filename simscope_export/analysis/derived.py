"""Inspection of an exact G3 artifact; never a persistent material identity."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path

import numpy as np

from .contracts import AnalysisError,integer,request_float
from .source import SourceSnapshot
from .sampling import world_positions
from . import selectors as S


@contextmanager
def artifact(source,oid,index,reference):
    S.keys(reference,["path","sha256","signature"],["path","sha256","signature"])
    if not isinstance(reference["path"],str) or not Path(reference["path"]).is_absolute():
        raise AnalysisError("invalid_artifact","An explicit absolute artifact path is required")
    if oid not in source.objects or source.objects[oid]["kind"]!="volume":
        raise AnalysisError("invalid_artifact","Derived artifact requires an original source grid")
    index=integer(index,"artifact source sample",0,len(source.samples[oid])-1)
    extent=str(Path(reference["path"]).stat().st_size)
    with SourceSnapshot(reference["path"],committed_bytes=extent,sha256=reference["sha256"],context=source.context) as derived:
        provenance=derived.metadata.get("provenance",{})
        signature=hashlib.sha256(json.dumps(provenance,sort_keys=True,separators=(",",":")).encode()).hexdigest()
        expected=dict(source_sha256=source.sha256,committed_bytes=str(source.committed_end),object=oid,
                      source_time=source.samples[oid][index]["time"],geometry=source.samples[oid][index]["descriptor"]["geometry"],
                      data_to_world=source.objects[oid]["data_to_world"])
        if signature!=reference["signature"] or any(provenance.get(k)!=v for k,v in expected.items()):
            raise AnalysisError("invalid_artifact","Artifact provenance differs from the pinned source/sample")
        if provenance.get("algorithm")!="skimage-lewiner-0.26/source-f32/no-smoothing/no-decimation/v2" or provenance.get("smoothing") is not False or provenance.get("decimation") is not False:
            raise AnalysisError("invalid_artifact","Unsupported derived algorithm provenance")
        if set(derived.objects)!={"isosurface"} or derived.objects["isosurface"].get("identity")!="none" or len(derived.samples["isosurface"])!=1:
            raise AnalysisError("invalid_artifact","Expected one anonymous derived mesh")
        if derived.objects["isosurface"]["data_to_world"]!=expected["data_to_world"]:
            raise AnalysisError("invalid_artifact","Artifact transform differs from original grid")
        from .selection_jobs import workspace
        with workspace(derived,dict(object="isosurface")),derived.read_sample("isosurface",0,["position"]) as sample:
            points=world_positions(derived.objects["isosurface"],sample.arrays["position"])
            yield points,sample.arrays["triangles"],provenance
            derived.verify();source.verify()


def dispatch(source,arguments):
    S.keys(arguments,["object","index","artifact","mode","ray","camera","backface","key","name","occlusion","occluders"],
           ["object","index","artifact","mode"])
    oid=arguments["object"];index=arguments["index"];mode=arguments["mode"]
    if mode not in ("object","face","point","source_probe"):raise AnalysisError("invalid_artifact","Choose artifact object/face/point or explicit source probe")
    with artifact(source,oid,index,arguments["artifact"]) as (points,triangles,provenance):
        selector=dict(index=index,artifact_sha256=arguments["artifact"]["sha256"],artifact=arguments["artifact"],
                      threshold=provenance["threshold"],algorithm=provenance["algorithm"],channel=provenance["channel"])
        creation=dict(approximate=True,provenance=provenance,placement_precision="float32 extracted geometry transformed in float64",physical_identity="none")
        if mode!="object":
            from .picking import triangle_hit,ray_interval,_unoccluded
            from contextlib import ExitStack
            ray=arguments.get("ray",{});S.keys(ray,["origin","direction"],["origin","direction"])
            origin,direction=S.vector(ray["origin"]),S.vector(ray["direction"])
            norm=float(np.linalg.norm(direction))
            if not np.isfinite(norm) or norm==0:raise AnalysisError("invalid_pick","Finite nonzero ray required")
            direction/=norm
            minimum,maximum=ray_interval(origin,direction,arguments["camera"])
            orientation=float(np.sign(np.linalg.det(np.asarray(provenance["data_to_world"]).reshape(3,4)[:,:3])))
            hit=triangle_hit(origin,direction,points,triangles,backface=arguments.get("backface","front"),orientation=orientation,minimum=minimum,maximum=maximum,context=source.context)
            if hit is None:raise AnalysisError("no_hit","No triangle in this exact derived artifact")
            location=origin+hit[0]*direction
            occlusion=arguments.get("occlusion","through")
            if occlusion not in ("through","opaque"):raise AnalysisError("invalid_pick","Unknown artifact occlusion policy")
            with ExitStack() as stack:
                if occlusion=="opaque" and not len(_unoccluded(source,arguments,stack,location[None,:],np.array([0]),S.vector(arguments["camera"]["origin"]),arguments["camera"],source.samples[oid][index]["time"])):
                    raise AnalysisError("no_hit","Artifact hit is behind visible opaque geometry")
            selector.update(face=hit[1])
            if mode in ("point","source_probe"):selector["barycentric"]=S.tokens(hit[2])
            creation.update(camera=arguments["camera"],ray=ray,occlusion=occlusion,backface=arguments.get("backface","front"),artifact=selector.copy())
        kind="derived_surface"
        if mode=="source_probe":
            kind="probe";selector=dict(coordinate=S.tokens(location))
            creation["explicit_conversion"]="fixed source-grid probe at approximate artifact placement"
        definition=S.define(source,dict(object=oid,kind=kind,selector=selector,key=arguments.get("key","artifact"),name=arguments.get("name","Approximate derived surface"),creation=creation))
        return dict(selection=definition,approximate_geometry=True,physical_identity="none")


def preview(source,definition,index,limit):
    selector=definition["selector"]
    if index!=selector["index"]:return [],"unavailable","artifact_sample_changed"
    if "artifact" not in selector:return [],"unavailable","artifact_reference_missing"
    with artifact(source,definition["object"],index,selector["artifact"]) as (points,triangles,provenance):
        if request_float(selector["threshold"])!=provenance["threshold"] or selector["algorithm"]!=provenance["algorithm"] or selector.get("channel")!=provenance["channel"]:
            raise AnalysisError("invalid_artifact","Saved derived settings differ from verified artifact")
        if "face" in selector:
            face=integer(selector["face"],"artifact face",0,len(triangles)-1)
            points=np.array([S.vector(selector.get("barycentric",[1/3,1/3,1/3]))@points[triangles[face]]])
        step=max(1,int(np.ceil(len(points)/limit)))
        return [dict(position=S.tokens(v),position_status="approximate_artifact") for v in points[::step]],"approximate_artifact",None

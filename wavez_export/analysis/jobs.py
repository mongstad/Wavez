"""Validated internal worker requests. No code evaluation, shell or network API."""

import math
from pathlib import Path
import re
import time

import numpy as np

from .contracts import AnalysisError, Context, exact_id, finite, float_token, integer, request_float, request_vector
from .sampling import epoch, probe_array, source_bracket, valid_axis
from .source import SourceSnapshot

SELECTION_OPERATIONS = {"define_selection", "resolve_selection", "resolve_selections", "freeze_selection", "combine_selections", "edit_selection"}
SOURCE_RESULT_OPERATIONS={"analyze","import_csv","estimate_period","compare_series","space_time"}
SOURCE_OUTPUT_OPERATIONS={"export_analysis","save_recipe","load_recipe","prepare_matched_render"}
BACKGROUND_OPERATIONS=SOURCE_RESULT_OPERATIONS|SOURCE_OUTPUT_OPERATIONS|{"result_series","result_plot","result_overlay","result_heatmap","spatial_spectrum","spectral_band_map"}
OPERATIONS = {"describe", "records", "sample", "probe", "identity_audit", "epoch", "pick", "inspect_derived", "result_page", "result_manifest"} | SELECTION_OPERATIONS | BACKGROUND_OPERATIONS


def validate_request(request):
    if not isinstance(request, dict) or set(request)-{
        "version", "id", "scene_revision", "selection_revision", "analysis_revision", "source", "operation", "arguments", "budget", "member_pins", "result_pins"
    }:
        raise AnalysisError("invalid_request", "Unknown request fields")
    if request.get("version") != 1 or not isinstance(request.get("id"), str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", request["id"]):
        raise AnalysisError("invalid_request", "Unsupported request version or ID")
    integer(request["version"],"request version",1,1)
    for key in ("scene_revision", "selection_revision"):
        integer(request.get(key), key, 0, 2**31-1)
    integer(request.get("analysis_revision",0),"analysis_revision",0,2**31-1)
    source = request.get("source")
    if not isinstance(source, dict) or set(source)-{"path", "committed_bytes", "sha256", "uuid", "format", "complete_records"}:
        raise AnalysisError("invalid_request", "Invalid source reference")
    if not isinstance(source.get("path"), str) or len(source["path"]) > 4096 or not Path(source["path"]).is_absolute():
        raise AnalysisError("invalid_request", "An explicitly opened absolute source path is required")
    if request.get("operation") not in OPERATIONS:
        raise AnalysisError("unsupported_operation", "Unknown analysis operation")
    if not isinstance(request.get("arguments", {}), dict) or not isinstance(request.get("budget", {}), dict):
        raise AnalysisError("invalid_request", "Arguments/budget must be objects")
    budget = request.get("budget", {})
    if set(budget)-{"memory_bytes", "wall_seconds", "cpu_seconds"}:
        raise AnalysisError("invalid_request", "Unknown analysis budget")
    if "member_pins" in request and (not isinstance(request["member_pins"],list) or len(request["member_pins"])>512):
        raise AnalysisError("invalid_request","Member pins must be a bounded list")
    if "result_pins" in request and (not isinstance(request["result_pins"],list) or len(request["result_pins"])>64):
        raise AnalysisError("invalid_request","Result pins must be a bounded list")
    if request["operation"] in SOURCE_RESULT_OPERATIONS|SOURCE_OUTPUT_OPERATIONS and not {"sha256","committed_bytes","uuid","format","complete_records"}<=source.keys():
        raise AnalysisError("source_extent","Interval analysis requires a fully pinned source reference")
    return request


def number(value, dtype):
    """Every scientific number retains a dtype/text identity across JSON parsers."""
    if dtype in ("i8", "u4"):
        return {"value": str(int(value)), "dtype": dtype, "status": "source"}
    value = float(value)
    if not math.isfinite(value):
        return {"value": None, "dtype": dtype, "status": "nonfinite", "raw": "nan" if math.isnan(value) else ("+inf" if value > 0 else "-inf")}
    return {"value": value, "dtype": dtype, "status": "source", "exact": float_token(value)}


def _keys(arguments, allowed):
    if set(arguments)-set(allowed):
        raise AnalysisError("invalid_request", "Unknown operation arguments")


def _object(source, arguments):
    obj = arguments.get("object")
    if not isinstance(obj, str) or obj not in source.objects:
        raise AnalysisError("unknown_object", "Select a source object")
    return obj


def execute(request, *, context=None, memo=None, assets=None, results=None, provenance=None, retained_members=(),defer_publication=False):
    request = validate_request(request)
    context = context or Context(**request.get("budget", {}))
    ref = request["source"]
    if request["operation"]=="result_heatmap":
        if results is None:raise AnalysisError("invalid_result","Result store unavailable")
        from .heatmap_preview import preview
        data=preview(results,request.get("arguments",{}),context)
        if results.manifest(request["arguments"]["result"],context).get("source")!=ref:raise AnalysisError("source_changed","Heatmap source differs from its bound result")
        return dict(version=1,id=request["id"],scene_revision=request["scene_revision"],selection_revision=request["selection_revision"],analysis_revision=request.get("analysis_revision",0),ok=True,source=ref,data=data,metrics=context.metrics())
    if request["operation"]=="result_overlay":
        if results is None:raise AnalysisError("invalid_result","Result store unavailable")
        from .linked_plots import run
        data=run(results,request.get("arguments",{}),context)
        if not any(p["mapping"]["source"]==ref for p in data["plots"]):raise AnalysisError("source_changed","Plot source must be one of the explicit bindings")
        return dict(version=1,id=request["id"],scene_revision=request["scene_revision"],selection_revision=request["selection_revision"],analysis_revision=request.get("analysis_revision",0),ok=True,source=ref,data=data,metrics=context.metrics())
    if request["operation"] in ("result_page","result_manifest","result_series","result_plot"):
        if results is None:raise AnalysisError("invalid_result","Result store unavailable")
        arguments=request.get("arguments",{});_keys(arguments,["result","offset","limit","kind"] if request["operation"]=="result_page" else ["result","series","bins"] if request["operation"]=="result_plot" else ["result"])
        with context.allocation(8*1024*1024):
            manifest=results.manifest(arguments.get("result"),context)
            if manifest.get("source")!=ref:raise AnalysisError("source_changed","Cached result belongs to another pinned source")
            data=results.page(arguments["result"],offset=arguments.get("offset",0),limit=arguments.get("limit",128),kind=arguments.get("kind","rows"),context=context) if request["operation"]=="result_page" else dict(manifest=manifest,source_verification="historical immutable result; no new capture evaluation")
            if request["operation"] in ("result_series","result_plot"):
                from .plot_preview import series,preview
                data=series(results,arguments["result"],context) if request["operation"]=="result_series" else preview(results,arguments["result"],arguments.get("series"),context,bins=arguments.get("bins",512))
        return dict(version=1,id=request["id"],scene_revision=request["scene_revision"],selection_revision=request["selection_revision"],analysis_revision=request.get("analysis_revision",0),ok=True,source=ref,data=data,metrics=context.metrics())
    source_started = time.perf_counter()
    with SourceSnapshot(ref["path"], committed_bytes=ref.get("committed_bytes"),
                        sha256=ref.get("sha256"), context=context, memo=memo, assets=assets) as source:
        source_open_seconds = time.perf_counter()-source_started
        if ref.get("uuid", source.uuid) != source.uuid or ref.get("format", source.format) != source.format:
            raise AnalysisError("source_changed", "Source namespace/format differs from request")
        if ref.get("complete_records", source.record_count) != source.record_count:
            raise AnalysisError("source_changed", "Pinned source record count differs from request")
        if assets is not None and "member_pins" in request:
            from .member_assets import references_in
            for reference in request["member_pins"]:assets.path(reference)
            assets.collect(references_in([request["member_pins"],request.get("arguments",{}),list(retained_members)]),context)
        if request["operation"] in SOURCE_RESULT_OPERATIONS|SOURCE_OUTPUT_OPERATIONS:
            if results is None:raise AnalysisError("invalid_result","Result store unavailable")
            if request["operation"]=="analyze":from .native_analysis import run
            elif request["operation"]=="import_csv":from .diagnostics import run
            elif request["operation"]=="estimate_period":from .period_jobs import run
            elif request["operation"]=="space_time":from .space_time import run
            elif request["operation"]=="export_analysis":from .export_results import run
            elif request["operation"]=="save_recipe":from .recipes import save as run
            elif request["operation"]=="load_recipe":from .recipes import load as run
            elif request["operation"]=="prepare_matched_render":from .matched_render import run
            else:from .comparisons import run
            data=run(source,request.get("arguments",{}),results,provenance=provenance)
        else:data = dispatch(source, request["operation"], request.get("arguments", {}))
        if request["operation"] in ("spatial_spectrum", "spectral_band_map"):
            data["timings"]["verification_open_seconds"] = source_open_seconds
            if provenance is not None:data["provenance"]["worker"] = provenance
        try:
            source.verify()
            source.verify_members()
            context.verify_publication()
            if not defer_publication:context.commit_publications()
        except Exception as exc:
            context.abort_publications(exc)
            if request["operation"] in SOURCE_RESULT_OPERATIONS:results.discard(data["result"])
            raise
        identity = source.identity()
    return dict(version=1, id=request["id"], scene_revision=request["scene_revision"],
                selection_revision=request["selection_revision"], analysis_revision=request.get("analysis_revision",0), ok=True,
                source=identity, data=data, metrics=context.metrics())


def dispatch(source, operation, arguments):
    if operation == "spectral_band_map":
        from .spatial_band_map import run
        return run(source, arguments)
    if operation == "spatial_spectrum":
        from .spatial_spectrum import run
        return run(source, arguments)
    if operation == "inspect_derived":
        from .derived import dispatch as derived_dispatch
        return derived_dispatch(source,arguments)
    if operation == "pick":
        from .picking import dispatch as pick_dispatch
        return pick_dispatch(source,arguments)
    if operation in SELECTION_OPERATIONS:
        from .selection_jobs import dispatch as selection_dispatch
        return selection_dispatch(source,operation,arguments)
    if operation == "describe":
        _keys(arguments, [])
        objects = []
        for oid, obj in source.objects.items():
            source.context.check()
            rows = source.samples[oid]
            objects.append(dict(object=obj, samples=len(rows), physical_axis=valid_axis(rows),
                                first_time=float_token(rows[0]["time"]) if rows else None,
                                last_time=float_token(rows[-1]["time"]) if rows else None,
                                channels=[{k:a[k] for k in ("name","dtype","shape","association")}
                                          for a in rows[0]["descriptor"]["arrays"]] if rows else []))
        return dict(objects=objects, time_unit=source.metadata.get("time_unit", "unknown"))
    oid = _object(source, arguments)
    rows, obj = source.samples[oid], source.objects[oid]
    if operation == "records":
        _keys(arguments, ["object", "offset", "limit"])
        start = integer(arguments.get("offset", 0), "offset", 0, len(rows))
        limit = integer(arguments.get("limit", 64), "limit", 1, 128)
        return dict(records=[dict(index=i, sequence=rows[i]["sequence"], time=float_token(rows[i]["time"]))
                             for i in range(start, min(start+limit, len(rows)))], total=len(rows))
    if operation == "identity_audit":
        _keys(arguments, ["object", "last_index"])
        return source.audit_identity(oid, arguments.get("last_index"))
    if operation == "epoch":
        _keys(arguments, ["object", "index"])
        return epoch(source, oid, arguments.get("index"))
    if operation == "probe":
        _keys(arguments, ["object", "time", "coordinate", "channel"])
        if obj["kind"] != "volume":
            raise AnalysisError("unsupported_operation", "A probe requires a direct source grid")
        point = source_bracket(source, oid, request_float(arguments.get("time"), "time"))
        if point["status"] == "unavailable":
            return point
        channel = arguments.get("channel")
        if not isinstance(channel, str):
            raise AnalysisError("invalid_request", "Probe source channel required")
        with source.read_sample(oid, point["a"], [channel]) as sample:
            value = probe_array(sample.arrays[channel], sample.record["descriptor"]["geometry"],
                                obj["data_to_world"], request_vector(arguments.get("coordinate")))
            if value["value"] is not None:
                value["exact"] = float_token(value["value"])
            value["source_dtype"] = sample.descriptors[channel]["dtype"]
        return dict(value=value, sampling=point)
    if operation == "sample":
        _keys(arguments, ["object", "index", "channels", "offset", "limit", "ids"])
        index = integer(arguments.get("index"), "sample index", 0, len(rows)-1)
        names = arguments.get("channels")
        if not isinstance(names, list) or not 1 <= len(names) <= 16 or not all(isinstance(n,str) for n in names):
            raise AnalysisError("invalid_request", "Select 1–16 named source channels")
        if obj["kind"] == "volume":
            raise AnalysisError("unsupported_operation", "Grid sample locations use probe/grid selection, not particle rows")
        with source.read_sample(oid, index, names) as sample:
            associations = {sample.descriptors[n]["association"] for n in names}
            lengths = {sample.descriptors[n]["shape"][0] for n in names}
            if len(associations) != 1 or len(lengths) != 1 or "topology" in associations:
                raise AnalysisError("invalid_request", "Sample table requires one value association")
            count = lengths.pop()
            limit = integer(arguments.get("limit",64), "limit", 1, 128)
            start = integer(arguments.get("offset",0), "offset", 0, count)
            indices = list(range(start,min(start+limit,count)))
            if "ids" in arguments:
                ids = arguments["ids"]
                if not isinstance(ids,list) or len(ids)>128:
                    raise AnalysisError("invalid_request", "ID inspection limit is 128")
                key = "particle_id" if obj["kind"] == "particles" else "vertex_id"
                if key not in sample.arrays or associations != {"vertex"}:
                    raise AnalysisError("anonymous", "No explicit identity for this association")
                requested = [exact_id(v) for v in ids]
                lookup = sample.arrays[key]
                indices = []
                for id_value in requested:
                    source.context.check()
                    found = np.flatnonzero(lookup == id_value)
                    indices.append(int(found[0]) if len(found) else None)
            values = []
            for n, i in enumerate(indices):
                source.context.check()
                row = {"row":i, "status":"source" if i is not None else "absent_at_sample"}
                if "ids" in arguments:row["id"] = arguments["ids"][n]
                row["channels"] = {}
                if i is not None:
                    for name in names:
                        if name not in sample.arrays:
                            row["channels"][name] = {"value":None,"status":"unsupported_channel"}
                            continue
                        v = sample.arrays[name][i]
                        dtype = sample.descriptors[name]["dtype"]
                        row["channels"][name] = [number(x,dtype) for x in v] if np.ndim(v) else number(v,dtype)
                values.append(row)
            return dict(rows=values, total=count, association=next(iter(associations)),
                        time=float_token(sample.record["time"]),
                        identity_status="declared_not_audited" if obj.get("identity") in ("persistent_i8","stable_topology") else "anonymous")
    raise AnalysisError("unsupported_operation", "Unknown analysis operation")

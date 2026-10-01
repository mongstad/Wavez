"""Source-space sampling rules mirrored by viewer/scene/source_sampling.gd."""

from bisect import bisect_right
import hashlib
import json
import math

import numpy as np

from ..scene import affine
from .contracts import AnalysisError, finite, float_token, integer

POLICY_VERSION = "g4-source-sampling-1"


def valid_axis(rows):
    previous = -math.inf
    for row in rows:
        value = row["time"]
        if value is None or not math.isfinite(value) or value <= previous:
            return False
        previous = value
    return bool(rows)


def bracket(rows, time, *, static=False, validated_axis=False):
    time = finite(time, "requested time")
    if not rows:
        return dict(status="unavailable", reason="no_samples")
    if static:
        a = b = 0
        alpha, status = 0., "static"
    else:
        if not validated_axis and not valid_axis(rows):
            raise AnalysisError("index_only", "Physical sampling requires an increasing finite native axis")
        if time < rows[0]["time"]:
            return dict(status="unavailable", reason="before_first_sample")
        a = bisect_right(rows, time, key=lambda r:r["time"])-1
        b = a if time == rows[a]["time"] else min(a+1, len(rows)-1)
        alpha = 0. if a == b else (time-rows[a]["time"])/(rows[b]["time"]-rows[a]["time"])
        status = "exact" if time == rows[a]["time"] else "held"
    return dict(a=a, b=b, alpha=alpha, status=status, time=rows[a]["time"],
                source_times=[float_token(rows[i]["time"]) for i in (a, b)],
                requested_time=float_token(time), policy=POLICY_VERSION)


def source_bracket(source, object_id, time):
    source.verify()
    key=("native_axis",source.sha256,object_id)
    valid=source.memo.get(key)
    if valid is None:
        valid=valid_axis(source.samples[object_id]);source.memo.put(key,valid)
    if not source.objects[object_id]["static"] and not valid:
        raise AnalysisError("index_only","Physical sampling requires an increasing finite native axis")
    return bracket(source.samples[object_id], time, static=source.objects[object_id]["static"],validated_axis=True)


def match_rows(earlier, later):
    """Exact int64 lookup; -1 means absent, including an empty later sample."""
    result = np.full(len(earlier), -1, dtype=np.int64)
    if not len(later) or not len(earlier):
        return result
    order = np.argsort(later, kind="stable")
    sorted_ids = later[order]
    indices = np.searchsorted(sorted_ids, earlier)
    bounded = np.minimum(indices, len(later)-1)
    shared = (indices < len(later)) & (sorted_ids[bounded] == earlier)
    result[shared] = order[bounded[shared]]
    return result


def mesh_compatible(obj, a, b):
    return (obj.get("identity") == "stable_topology" and
            "vertex_id" in a and "vertex_id" in b and
            np.array_equal(a["vertex_id"], b["vertex_id"]) and
            np.array_equal(a["triangles"], b["triangles"]) and
            len(a["vertex_id"]) == len(b["vertex_id"]))


def world_positions(obj, positions):
    transform = affine(obj["data_to_world"])
    values = np.asarray(positions, dtype=np.float64)
    return values @ transform[:, :3].T + transform[:, 3]


def interpolated_positions(obj, a, b, alpha):
    """Earlier active set; return per-row status independent of scalar status."""
    values = np.array(a["position"], dtype=np.float64, copy=True)
    status = np.full(len(values), "held", dtype="U20")
    if alpha > 0 and obj["kind"] == "particles" and obj.get("identity") == "persistent_i8":
        matched = match_rows(a["particle_id"], b["particle_id"])
        shared = matched >= 0
        values[shared] += (np.asarray(b["position"][matched[shared]], dtype=np.float64)-values[shared])*alpha
        status[:] = "held_unmatched"
        status[shared] = "interpolated_by_id"
    elif alpha > 0 and obj["kind"] == "mesh" and mesh_compatible(obj, a, b):
        values += (np.asarray(b["position"], dtype=np.float64)-values)*alpha
        status[:] = "interpolated_by_id"
    return world_positions(obj, values), status


def probe_array(values, geometry, transform, coordinate):
    """G3 trilinear rule including invalid zero-weight corners and cell edges."""
    world = np.asarray(coordinate, dtype=np.float64)
    if world.shape != (3,) or not np.isfinite(world).all():
        raise AnalysisError("invalid_request", "Probe needs finite source-space xyz")
    transform = affine(transform)
    local = np.linalg.solve(transform[:, :3], world-transform[:, 3])
    xyz = (local-np.asarray(geometry["origin"]))/geometry["spacing"]
    shape = np.asarray(values.shape[::-1])
    low = -.5 if geometry["centering"] == "cell" else 0.
    high = shape-.5 if geometry["centering"] == "cell" else shape-1
    if np.any(xyz < low) or np.any(xyz > high):
        return dict(value=None, status="unavailable", reason="out_of_domain")
    xyz = np.clip(xyz, 0, shape-1)
    lo = np.floor(xyz).astype(int)
    hi = np.minimum(lo+1, shape-1)
    f = xyz-lo
    value = 0.
    for dz in (0, 1):
        for dy in (0, 1):
            for dx in (0, 1):
                v = values[(hi if dz else lo)[2], (hi if dy else lo)[1], (hi if dx else lo)[0]]
                if not np.isfinite(v):
                    return dict(value=None, status="unavailable", reason="nonfinite_support")
                value += float(v)*(f[0] if dx else 1-f[0])*(f[1] if dy else 1-f[1])*(f[2] if dz else 1-f[2])
    if not math.isfinite(value):
        return dict(value=None, status="unavailable", reason="arithmetic_overflow")
    return dict(value=value, status="spatially_interpolated", reason=None,
                local_xyz=local.tolist(), policy=POLICY_VERSION)


def epoch(source, object_id, index):
    """A contiguous epoch start prevents A→B→A from resurrecting a face/grid ID."""
    rows, obj = source.samples[object_id], source.objects[object_id]
    index = integer(index, "epoch sample index", 0, len(rows)-1)
    if obj["kind"] not in ("mesh", "volume"):
        raise AnalysisError("invalid_request", "Topology/geometry epochs require mesh or grid")
    source.verify()
    scope = ("epoch",source.sha256,object_id)
    verified_index,cached = source.memo.nearest_epoch(scope,index)
    if verified_index == index:
        source.verify()
        return cached
    start, previous = (cached["first_index"],cached["fingerprint"]) if cached else (0,None)
    for i in range(verified_index+1,index+1):
        source.context.check()
        digest = hashlib.sha256()
        if obj["kind"] == "volume":
            digest.update(json.dumps([rows[i]["descriptor"]["geometry"], obj["data_to_world"]],
                                     sort_keys=True, separators=(",", ":"), allow_nan=False).encode())
        elif obj.get("identity") != "stable_topology":
            digest.update(str(0 if obj["static"] else rows[i]["sequence"]).encode())
        else:
            with source.read_sample(object_id, i, ["vertex_id", "triangles"]) as sample:
                digest.update(sample.arrays["vertex_id"].tobytes())
                digest.update(sample.arrays["triangles"].tobytes())
        current = digest.hexdigest()
        if current != previous:
            start = i
        previous = current
        result = dict(first_index=start,fingerprint=previous,object_id=object_id,
                      source_sha256=source.sha256,policy=POLICY_VERSION)
        source.memo.put(scope+(i,),result)
    source.verify()
    return result

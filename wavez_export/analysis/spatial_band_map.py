"""A bounded plane of source-verified 3D regional band-power measurements.

One native channel is decoded once. A single leased FFT workspace is reused for
all centers; no full transform, interpolated field or persistent map is retained.
"""

import hashlib
import json
import math
import time

import numpy as np

from .contracts import AnalysisError, float_token, integer
from . import spatial_spectrum as spectrum

ALGORITHM = "spectral-band-map-hann-v1"
MAX_CENTERS = 64
AXES = "zyx"


def _pair(value, name, low, high):
    if not isinstance(value, list) or len(value) != 2:
        raise AnalysisError("invalid_grid", f"{name} needs row and column values")
    return [integer(v, name, low, high) for v in value]


def _grid(value):
    keys = {"plane_axis", "fixed_start", "start", "hop", "count"}
    if not isinstance(value, dict) or set(value) != keys:
        raise AnalysisError("invalid_grid", "Grid requires plane_axis, fixed_start, and row/column start, hop and count")
    axis = value["plane_axis"]
    if not isinstance(axis, str) or axis not in AXES or len(axis) != 1:
        raise AnalysisError("invalid_grid", "Plane normal axis must be x, y or z")
    fixed = integer(value["fixed_start"], "fixed-axis window start", -(2**31), 2**31-1)
    start = _pair(value["start"], "grid window start", -(2**31), 2**31-1)
    hop = _pair(value["hop"], "grid hop", 1, 2**31-1)
    count = _pair(value["count"], "grid count", 1, MAX_CENTERS)
    if math.prod(count) > MAX_CENTERS:
        raise AnalysisError("center_limit", "A band map permits at most 64 requested centers, including unavailable centers. Reduce center count or increase hop without reducing needed window support")
    remaining = [a for a in AXES if a != axis]
    return dict(plane_axis=axis, fixed_start=fixed, start=start, hop=hop, count=count,
                shape=count, row_axis=remaining[0], column_axis=remaining[1],
                order="row-major; remaining source z,y,x axes", coordinate_space="data_local",
                centers="integer window starts + (support - 1)/2; no half-cell offset")


def _centers(v, grid, spacing):
    origin = np.asarray(v["geometry"]["origin"], dtype=np.float64)
    translation = np.asarray(v["object"]["data_to_world"], dtype=np.float64).reshape(3, 4)[:, 3]
    shape_xyz = np.asarray(v["shape"][::-1], dtype=np.float64)
    result = []
    for row in range(grid["count"][0]):
        for column in range(grid["count"][1]):
            start = [0, 0, 0]
            start[AXES.index(grid["plane_axis"])] = grid["fixed_start"]
            start[AXES.index(grid["row_axis"])] = grid["start"][0] + row*grid["hop"][0]
            start[AXES.index(grid["column_axis"])] = grid["start"][1] + column*grid["hop"][1]
            end = [a+n for a,n in zip(start, v["shape"])]
            # WVZ origin denotes the first sample center for node AND cell grids.
            indices = np.asarray(start[::-1], dtype=np.float64)+(shape_xyz-1)/2
            with np.errstate(over="ignore", invalid="ignore"):
                center = origin + indices*spacing
                world = center + translation
            if not np.isfinite(center).all() or not np.isfinite(world).all():
                raise AnalysisError("numerical_range", "Map center coordinates exceed the finite float64 geometry range")
            complete = all(0 <= a < b <= n for a,b,n in zip(start,end,v["geometry"]["shape"]))
            result.append(dict(row=row, column=column, start=start, end=end,
                               center_index_xyz=indices.tolist(), center_xyz=center.tolist(),
                               center_world_xyz=world.tolist(), coordinate_space="data_local",
                               status="pending" if complete else "outside_support", power=None,
                               power_exact=None, mean=None, mean_exact=None, total_power=None,
                               total_power_exact=None, parseval_relative_error=None))
    return result


def run(source, arguments):
    required = {"object", "channel", "time", "support", "band", "grid"}
    allowed = required | {"position_units", "value_units"}
    if not isinstance(arguments, dict) or set(arguments)-allowed or not required <= arguments.keys():
        raise AnalysisError("invalid_request", "Band map requires object, channel, time, 3D support, numerical band and a bounded center grid")
    context = source.context
    v = spectrum._source_parameters(source, arguments)
    v["shape"], v["count"] = spectrum._shape(arguments["support"])
    spacing, shape_xyz, extent, df, nyquist = spectrum._frequency_geometry(v)
    band = spectrum._band_parameters(arguments["band"], nyquist)
    grid = _grid(arguments["grid"])
    measurements = _centers(v, grid, spacing)
    with np.errstate(over="ignore", invalid="ignore"):
        cycles = band["low"]*extent
    if not np.isfinite(cycles).all():
        raise AnalysisError("numerical_range", "Band frequency and support exceed finite range")
    support = dict(shape=v["shape"], axis_order="zyx", extent_xyz=extent.tolist(),
                   center_span_xyz=((shape_xyz-1)*spacing).tolist(), df_xyz=df.tolist(),
                   minimum_frequency=band["low"], cycles_xyz=cycles.tolist(),
                   status="insufficient_support" if float(np.min(cycles)) < 2 else "candidate",
                   criterion="at least two cycles of the low band edge on every axis; heuristic, not a resolution guarantee",
                   bounds="complete finite source samples only; no padding or wrap")
    workspace = spectrum._workspace(source, v)
    context.check()
    context.progress("band_map_decode", 0, 1)
    decode_started = time.perf_counter()
    calculation_seconds = reduction_seconds = fft_seconds = 0.
    with context.allocation(workspace), source.read_sample(v["oid"], v["index"], [v["channel"]]) as sample:
        decode_seconds = time.perf_counter()-decode_started
        context.check()
        context.progress("band_map_decode", 1, 1)
        batch_started = time.perf_counter()
        context.progress("band_map_centers", 0, len(measurements))
        for index, measurement in enumerate(measurements):
            context.check()
            if measurement["status"] == "pending":
                try:
                    computed = spectrum._compute_region(sample.arrays[v["channel"]],
                        measurement["start"], measurement["end"], spacing, context,
                        band=band, report_progress=False)
                except AnalysisError as exc:
                    # Cancellation, memory, source and worker failures always abort
                    # the batch. Only a center's unavailable numeric data is masked.
                    if exc.code not in ("nonfinite_samples", "numerical_range"):
                        raise
                    measurement.update(status=exc.code, reason=str(exc))
                else:
                    measurement.update(status="measured", power=computed["band"]["power"],
                        power_exact=computed["band"]["power_exact"],
                        selected_half_complex_bins=computed["band"]["selected_half_complex_bins"])
                    for key in ("mean", "mean_exact", "total_power", "total_power_exact", "parseval_relative_error"):
                        measurement[key] = computed[key]
                    calculation_seconds += computed["calculation_seconds"]
                    reduction_seconds += computed["reduction_seconds"]
                    fft_seconds += computed["fft_seconds"]
            else:
                measurement["reason"] = "The complete 3D support extends outside the source; no padding, wrap or zero power was substituted"
            context.check()
            context.progress("band_map_centers", index+1, len(measurements))
        batch_seconds = time.perf_counter()-batch_started
    context.check()
    measured = sum(m["status"] == "measured" for m in measurements)
    warnings = ["Regional band power is not a unique local wavelength, propagation direction, phase, Hamiltonian energy or optical light.",
                "Finite 3D support and Hann broadening cause leakage; band edges select exact discrete Fourier radii, not ideal physical passbands.",
                "Overlapping windows are correlated. Only listed centers are measured; palette, opacity and display interpolation are presentation.",
                "Unavailable centers have null power, not zero. No periodic boundary wrapping or partial window is used."]
    if support["status"] == "insufficient_support":
        warnings.append("Unresolved band: fewer than two cycles of its low edge fit on at least one axis. Preserve needed support and reduce center count for a smaller batch; this heuristic is not a resolution guarantee.")
    if "unknown" in (v["position_units"], v["value_units"]):
        warnings.append("Coordinate or channel units are unknown; no physical calibration is inferred.")
    if measured < len(measurements):
        warnings.append(f"{len(measurements)-measured} of {len(measurements)} centers are unavailable; inspect their explicit status and coverage mask.")
    record = dict(index=v["index"], sequence=v["record"]["sequence"],
                  native_time=float_token(v["record"]["time"]), requested_time=float_token(v["requested_time"]),
                  sampling=v["bracket"]["status"])
    provenance = dict(algorithm=ALGORITHM, kernel_algorithm=spectrum.ALGORITHM,
        numpy=np.__version__, calculation_dtype="float64", source_dtype=v["spec"]["dtype"],
        window="periodic Hann, separable in z,y,x", detrending="mu=sum(w*q)/sum(w); DFT input=w*(q-mu)",
        normalization=spectrum.NORMALIZATION, power_meaning="sum of exact-band window-weighted mean-square residual powers; not Hamiltonian energy",
        geometry_policy="data_local; identity linear data_to_world; translation changes world centers only",
        descriptor_sha256=hashlib.sha256(json.dumps(v["record"]["descriptor"],sort_keys=True,separators=(",",":")).encode()).hexdigest(),
        unit_policy="canonical position_unit and channel_metadata only; no automatic conversion",
        position_units_source="explicit request override" if "position_units" in arguments else "capture position_unit or unknown",
        value_units_source="explicit request override" if "value_units" in arguments else "capture channel_metadata or unknown",
        batching="one native selected-channel decode; one sequential FFT workspace; no display-preview input")
    result = dict(kind="spectral_band_map", algorithm=ALGORITHM, object=v["oid"], channel=v["channel"],
        record=record, geometry=dict(v["geometry"],data_to_world=v["object"]["data_to_world"]),
        grid=grid, support=support, band=band, measurements=measurements,
        coverage=dict(total=len(measurements), measured=measured, unavailable=len(measurements)-measured,
                      mask=[m["status"] == "measured" for m in measurements]),
        units=dict(position=v["position_units"], value=v["value_units"],
                   frequency=f"cycles / ({v['position_units']})" if v["position_units"]!="unknown" else "cycles / source-coordinate unit (unknown)",
                   power=f"({v['value_units']})^2" if v["value_units"]!="unknown" else "squared channel units (unknown)"),
        df_xyz=df.tolist(), nyquist_xyz=nyquist.tolist(), inscribed_nyquist=float(np.min(nyquist)),
        warnings=warnings, provenance=provenance, workspace_bytes=workspace,
        timings=dict(decode_seconds=decode_seconds, calculation_seconds=calculation_seconds,
                     reduction_seconds=reduction_seconds, fft_seconds=fft_seconds,
                     batch_seconds=batch_seconds, decoded_samples=1))
    key = dict(source=source.identity(), object=v["oid"], channel=v["channel"], record=record,
               geometry=result["geometry"], grid=grid, support=support, band=band, units=result["units"],
               algorithm=ALGORITHM, kernel_algorithm=spectrum.ALGORITHM)
    result["request_key"] = hashlib.sha256(json.dumps(key,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    return result

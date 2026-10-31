"""Bounded source-grid spatial spectrum; derived numbers, never optical emission.

This operation runs only in the existing owned analysis worker. It consumes one
verified native channel, uses no preview textures, and returns a compact radial
diagnostic rather than retaining a transform cube or persistent result artifact.
"""

import hashlib
import json
import math
import time

import numpy as np

from . import channel_semantics as units
from .contracts import AnalysisError, MIB, float_token, integer, request_float
from .sampling import source_bracket

ALGORITHM = "spatial-spectrum-hann-v1"
MAX_REGION_CELLS = 192**3
MAX_AXIS = 256
MIN_AXIS = 4
NORMALIZATION = "m*abs(DFT(w*(q-sum(w*q)/sum(w))))^2/(N*sum(w^2))"


def _unit(value, name):
    value = units.unit(value, name)
    if value != value.strip() or any(ord(c) < 32 for c in value):
        raise AnalysisError("invalid_units", f"{name} must be nonempty plain text or 'unknown'")
    return value


def _bounds(value, name, shape):
    if not isinstance(value, list) or len(value) != 3:
        raise AnalysisError("invalid_roi", f"{name} requires three source indices in z,y,x order")
    return [integer(v, name, 0, shape[i]) for i, v in enumerate(value)]


def _source_parameters(source, arguments):
    """Resolve one pinned native scalar and its canonical units, without decoding."""
    oid, channel = arguments["object"], arguments["channel"]
    if not isinstance(oid, str) or oid not in source.objects:
        raise AnalysisError("unknown_object", "Select an existing source field")
    obj = source.objects[oid]
    if obj["kind"] != "volume":
        raise AnalysisError("unsupported_geometry", "Spatial spectrum requires a uniform source volume")
    transform = np.asarray(obj["data_to_world"], dtype=np.float64).reshape(3, 4)
    if not np.array_equal(transform[:, :3], np.eye(3)):
        raise AnalysisError("unsupported_transform", "Spatial spectrum currently supports untranslated or translated data-local axes only; rotation, scale and shear are unsupported")
    requested_time = request_float(arguments["time"], "requested time")
    bracket = source_bracket(source, oid, requested_time)
    if bracket["status"] == "unavailable":
        raise AnalysisError("unavailable_sample", "No native field sample exists at or before the requested time")
    index = bracket["a"]
    record = source.samples[oid][index]
    geometry = record["descriptor"]["geometry"]
    specs = {a["name"]: a for a in record["descriptor"]["arrays"]}
    if not isinstance(channel, str) or channel not in specs:
        raise AnalysisError("missing_channel", "The selected channel is absent from this native field sample")
    spec = specs[channel]
    if spec["association"] != "sample" or spec["dtype"] not in ("f4", "f8") or spec["shape"] != geometry["shape"]:
        raise AnalysisError("unsupported_channel", "Spatial spectrum requires a real scalar source-grid channel")
    declaration = units.declaration(source, oid, {"channel": channel})
    if declaration["semantic"] not in ("continuous", "signed"):
        raise AnalysisError("unsupported_semantics", "Categorical, identifier and wrapped-phase channels cannot be treated as continuous scalar amplitudes")
    position_units = _unit(units.position_unit(source, oid, arguments.get("position_units")), "coordinate units")
    value_units = _unit(arguments.get("value_units", declaration["units"]), "channel units")
    return dict(oid=oid, channel=channel, object=obj, record=record, index=index,
                bracket=bracket, geometry=geometry, spec=spec,
                position_units=position_units, value_units=value_units,
                declaration=declaration, requested_time=requested_time)


def _shape(shape):
    if not isinstance(shape, list) or len(shape) != 3:
        raise AnalysisError("invalid_roi", "Support requires three sample counts in z,y,x order")
    shape = [integer(n, "support axis", MIN_AXIS, MAX_AXIS) for n in shape]
    count = math.prod(shape)
    if count > MAX_REGION_CELLS:
        raise AnalysisError("memory_limit", "Spatial spectrum is limited to 192³ region samples; select a smaller complete region")
    return shape, count


def _validated(source, arguments):
    allowed = {"object", "channel", "time", "roi", "bins", "position_units", "value_units", "minimum_frequency", "band"}
    if not isinstance(arguments, dict) or set(arguments)-allowed or not {"object", "channel", "time", "roi"} <= arguments.keys():
        raise AnalysisError("invalid_request", "Spatial spectrum requires object, channel, time and integer ROI bounds")
    v = _source_parameters(source, arguments)
    geometry = v["geometry"]
    roi = arguments["roi"]
    if not isinstance(roi, dict) or set(roi) != {"start", "end"}:
        raise AnalysisError("invalid_roi", "ROI needs inclusive start and exclusive end in z,y,x order")
    start = _bounds(roi["start"], "ROI start", geometry["shape"])
    end = _bounds(roi["end"], "ROI end", geometry["shape"])
    shape = [b-a for a, b in zip(start, end)]
    if any(n < MIN_AXIS or n > MAX_AXIS for n in shape):
        raise AnalysisError("invalid_roi", f"Each complete ROI axis needs {MIN_AXIS}–{MAX_AXIS} samples; no padding or wrapping is performed")
    count = math.prod(shape)
    if count > MAX_REGION_CELLS:
        raise AnalysisError("memory_limit", "Spatial spectrum is limited to 192³ region samples; select a smaller complete region")
    bins = integer(arguments.get("bins", 256), "radial bins", 8, 512)
    minimum = None
    if "minimum_frequency" in arguments:
        minimum = request_float(arguments["minimum_frequency"], "lowest frequency of interest")
        if minimum <= 0:
            raise AnalysisError("invalid_request", "Lowest frequency of interest must be positive cycles per source-coordinate unit")
    v.update(start=start, end=end, shape=shape, count=count, bins=bins, minimum=minimum)
    return v


def _radial(power, frequencies, requested_bins, context):
    """Nearest-radius shell sums; reduce planes to avoid a full radius cube."""
    widths = [abs(float(axis[1]-axis[0])) for axis in frequencies]
    width = min(widths)
    radius = math.hypot(*(float(np.abs(axis).max()) for axis in frequencies))
    ratio = radius/width
    if not math.isfinite(ratio):
        raise AnalysisError("numerical_range", "Grid anisotropy exceeds the supported float64 frequency-bin range")
    initial_count = math.floor(ratio+0.5)+1
    # Nearest-shell rounding needs room for its upper half-bin as well as DC.
    # Dividing initial_count by the cap alone can produce cap+1 shell centers.
    if initial_count > requested_bins:
        width *= max(1, math.ceil((ratio+0.5)/(requested_bins-0.5)))
    count = math.floor(radius/width+0.5)+1
    if not 1 <= count <= requested_bins or not math.isfinite(width) or width <= 0:
        raise AnalysisError("numerical_range", "Cannot construct bounded finite radial frequency bins")
    radial = np.zeros(count, dtype=np.float64)
    plane_radius = np.hypot(frequencies[1][:, None], frequencies[2][None, :])
    for z, fz in enumerate(frequencies[0]):
        context.check()
        indices = np.floor(np.hypot(plane_radius, fz)/width+0.5).astype(np.int64)
        if int(indices.max()) >= count:
            raise AnalysisError("numerical_range", "Radial shell rounding exceeded its declared bounds")
        radial += np.bincount(indices.ravel(), weights=power[z].ravel(), minlength=count)
        context.progress("spectrum_reduce", z+1, len(frequencies[0]))
    return dict(frequency=(np.arange(count)*width).tolist(), power=radial.tolist(),
                bin_width=float(width), convention="nearest-shell-sum",
                bin_edges_lower=[max(0., (i-.5)*width) for i in range(count)],
                bin_edges_upper=[(i+.5)*width for i in range(count)])


def _band_parameters(value, nyquist):
    if not isinstance(value, dict) or set(value) != {"low", "high"}:
        raise AnalysisError("invalid_band", "Band requires low and high edges in cycles per source-coordinate unit")
    low = request_float(value["low"], "band low edge")
    high = request_float(value["high"], "band high edge")
    if not 0 <= low < high:
        raise AnalysisError("invalid_band", "Band edges must satisfy 0 <= low < high")
    if high > float(np.min(nyquist)):
        raise AnalysisError("unsupported_frequency", "Band high edge must be at or below the inscribed Nyquist limit; an isotropic radial band beyond it is not fully sampled")
    return dict(low=low, high=high, low_exact=float_token(low), high_exact=float_token(high),
                convention="low <= exact DFT radial frequency < high", frequency_measure="cycles per source-coordinate unit")


def _band_power(power, frequencies, band, context):
    """Sum exact Fourier-bin radii, independently of display-shell coarsening."""
    plane_radius = np.hypot(frequencies[1][:, None], frequencies[2][None, :])
    value = 0.
    selected = 0
    for z, fz in enumerate(frequencies[0]):
        context.check()
        radius = np.hypot(plane_radius, fz)
        mask = (radius >= band["low"]) & (radius < band["high"])
        value += float(np.sum(power[z][mask]))
        selected += int(np.count_nonzero(mask))
    if not math.isfinite(value):
        raise AnalysisError("numerical_range", "Band power exceeds finite float64 range")
    return dict(band, power=value, power_exact=float_token(value), selected_half_complex_bins=selected)


def _frequency_geometry(v):
    spacing = np.asarray(v["geometry"]["spacing"], dtype=np.float64)
    if spacing.shape != (3,) or not np.isfinite(spacing).all() or np.any(spacing <= 0):
        raise AnalysisError("unsupported_geometry", "Finite positive source spacing is required")
    shape_xyz = np.asarray(v["shape"][::-1], dtype=np.float64)
    with np.errstate(over="ignore", invalid="ignore", divide="ignore", under="ignore"):
        extent = shape_xyz*spacing
        df = 1./extent
        nyquist = .5/spacing
    if not np.isfinite(extent).all() or not np.isfinite(df).all() or not np.isfinite(nyquist).all() or np.any(df <= 0):
        raise AnalysisError("numerical_range", "Grid spacing and region support cannot form finite float64 frequencies")
    return spacing, shape_xyz, extent, df, nyquist


def _workspace(source, v):
    # One selected-channel decode and one reusable FFT workspace, never P copies.
    workspace = 64*v["count"] + 4*MIB
    source_bytes = math.prod(v["spec"]["shape"])*np.dtype(v["spec"]["dtype"]).itemsize
    needed = source.context.used + workspace + source_bytes*3 + 9*MIB
    if needed > source.context.limit:
        raise AnalysisError("memory_limit", f"Verified channel decoding plus spectral workspace needs about {math.ceil(needed/MIB)} MiB, above the {source.context.limit//MIB} MiB request budget. Choose a smaller region or source; region cropping does not remove full-channel decode costs")
    return workspace


def _compute_region(array, start, end, spacing, context, *, bins=None, band=None, report_progress=True):
    """Pure array kernel shared by one ROI and a bounded plane batch.

    The caller owns the full-channel and workspace leases. No source access,
    persistent cache or presentation data enters this numerical calculation.
    """
    context.check()
    shape = [b-a for a,b in zip(start,end)]
    count = math.prod(shape)
    progress = context.progress if report_progress else lambda *args: None
    try:
        calculation_started = time.perf_counter()
        region = np.array(array[tuple(slice(a,b) for a,b in zip(start,end))], dtype=np.float64, order="C", copy=True)
        if not np.isfinite(region).all():
            raise AnalysisError("nonfinite_samples", "The selected source region contains nonfinite samples; choose a complete finite region")
        progress("spectrum_window", 0, 1)
        with np.errstate(over="raise", invalid="raise", divide="raise", under="ignore"):
            axes = [.5-.5*np.cos(2*np.pi*np.arange(n)/n) for n in shape]
            w = axes[0][:,None,None]*axes[1][None,:,None]*axes[2][None,None,:]
            mean = float(np.sum(region*w)/np.sum(w))
            w2 = float(np.sum(w*w))
            region -= mean
            region *= w
            expected = float(np.sum(region*region)/w2)
            if expected == 0. and np.any(region != 0.):
                raise AnalysisError("numerical_range", "Nonzero windowed variation underflows float64 power; no zero-power result was substituted")
            del w
            context.check()
            progress("spectrum_fft", 0, 1)
            fft_started = time.perf_counter()
            transformed = np.fft.rfftn(region)
            fft_seconds = time.perf_counter()-fft_started
            context.check()
            progress("spectrum_fft", 1, 1)
            power = np.abs(transformed)
            np.square(power, out=power)
            power /= count*w2
            power[...,1:-1 if shape[-1]%2 == 0 else None] *= 2
            del transformed, region
            total = float(np.sum(power))
            relative_error = abs(total-expected)/max(expected, np.finfo(np.float64).tiny)
            if not math.isfinite(total) or not math.isfinite(relative_error):
                raise AnalysisError("numerical_range", "Spectrum power is outside finite float64 range")
            if relative_error > 1e-10:
                raise AnalysisError("numerical_range", "Float64 spectral power failed the discrete Parseval consistency check")
            frequencies = [np.fft.fftfreq(n, d) for n,d in zip(shape,spacing[::-1])]
            frequencies[-1] = np.fft.rfftfreq(shape[-1],spacing[0])
            calculation_seconds = time.perf_counter()-calculation_started
            reduce_started = time.perf_counter()
            radial = _radial(power, frequencies, bins, context) if bins is not None else None
            band_result = _band_power(power, frequencies, band, context) if band is not None else None
            reduction_seconds = time.perf_counter()-reduce_started
            del power
    except FloatingPointError as exc:
        raise AnalysisError("numerical_range", "Source values exceed the finite float64 spectrum range; no clipping or rescaling was applied") from exc
    return dict(mean=mean, mean_exact=float_token(mean), total_power=total,
                total_power_exact=float_token(total), parseval_relative_error=relative_error,
                radial=radial, band=band_result,
                calculation_seconds=calculation_seconds, reduction_seconds=reduction_seconds,
                fft_seconds=fft_seconds)


def run(source, arguments):
    context = source.context
    v = _validated(source, arguments)
    geometry = v["geometry"]
    spacing, shape_xyz, extent, df, nyquist = _frequency_geometry(v)
    band = _band_parameters(arguments["band"], nyquist) if "band" in arguments else None
    if v["minimum"] is not None and v["minimum"] >= float(np.min(nyquist)):
        raise AnalysisError("unsupported_frequency", "Lowest frequency of interest must be below the inscribed Nyquist limit; this diagnostic cannot establish a fully sampled radial band there")
    workspace = _workspace(source, v)
    context.check()
    context.progress("spectrum_decode", 0, 1)
    decode_started = time.perf_counter()
    with context.allocation(workspace), source.read_sample(v["oid"], v["index"], [v["channel"]]) as sample:
        decode_seconds = time.perf_counter()-decode_started
        context.check()
        context.progress("spectrum_decode", 1, 1)
        computed = _compute_region(sample.arrays[v["channel"]], v["start"], v["end"], spacing,
                                   context, bins=v["bins"], band=band)
    mean, total, relative_error = (computed[k] for k in ("mean", "total_power", "parseval_relative_error"))
    radial = computed["radial"]
    calculation_seconds, reduction_seconds = computed["calculation_seconds"], computed["reduction_seconds"]
    context.check()
    warnings = ["Derived spatial spectrum, not optical emission or physical model energy.",
                "Radial shell sums discard direction and phase; bin centers are not precise wavelengths.",
                "Finite support and Hann broadening limit resolution; small-window leakage can populate unresolved bands."]
    if "unknown" in (v["position_units"], v["value_units"]):
        warnings.append("Coordinate or channel units are unknown; no physical calibration is inferred.")
    radial["inscribed_nyquist"] = float(np.min(nyquist))
    warnings.append("Radial shells above the inscribed Nyquist sphere have incomplete directional coverage.")
    cycles = [] if v["minimum"] is None else (v["minimum"]*extent).tolist()
    if any(not math.isfinite(c) for c in cycles):
        raise AnalysisError("numerical_range", "Frequency of interest and region support exceed finite range")
    support = dict(minimum_frequency=v["minimum"], cycles_xyz=cycles,
                   status="not_requested" if not cycles else "insufficient_support" if min(cycles)<2 else "candidate",
                   criterion="at least two cycles on every axis; heuristic, not a resolution guarantee")
    if support["status"] == "insufficient_support":
        warnings.append("Insufficient support for the requested lowest frequency: fewer than two cycles on at least one axis. Increase region support; do not interpret a peak as its wavelength.")
    start_xyz = np.asarray(v["start"][::-1], dtype=np.float64)
    # WVZ origin is the first sample center for both node and cell centering;
    # cell faces, not sample centers, extend half a spacing beyond that point.
    with np.errstate(over="ignore", invalid="ignore"):
        origin_xyz = np.asarray(geometry["origin"])+start_xyz*spacing
        center_span = (shape_xyz-1)*spacing
    if not np.isfinite(origin_xyz).all() or not np.isfinite(center_span).all():
        raise AnalysisError("numerical_range", "ROI sample coordinates exceed the finite float64 geometry range")
    roi = dict(start=v["start"],end=v["end"],shape=v["shape"],axis_order="zyx",coordinate_space="data_local",
               bounds="inclusive start, exclusive end; complete source samples; no padding or wrap",
               origin_xyz=origin_xyz.tolist(), extent_xyz=extent.tolist(),
               center_span_xyz=center_span.tolist())
    record = dict(index=v["index"],sequence=v["record"]["sequence"],
                  native_time=float_token(v["record"]["time"]),requested_time=float_token(v["requested_time"]),
                  sampling=v["bracket"]["status"])
    provenance = dict(algorithm=ALGORITHM,numpy=np.__version__,calculation_dtype="float64",
        source_dtype=v["spec"]["dtype"],window="periodic Hann, separable in z,y,x",
        detrending="mu=sum(w*q)/sum(w); DFT input=w*(q-mu)",normalization=NORMALIZATION,
        power_meaning="window-weighted mean-square residual; not Hamiltonian energy",
        geometry_policy="data_local; identity linear data_to_world; translation does not change frequencies",
        descriptor_sha256=hashlib.sha256(json.dumps(v["record"]["descriptor"],sort_keys=True,separators=(",",":")).encode()).hexdigest(),
        unit_policy="canonical position_unit and channel_metadata only; no automatic conversion",
        position_units_source="explicit request override" if "position_units" in arguments else "capture position_unit or unknown",
        value_units_source="explicit request override" if "value_units" in arguments else "capture channel_metadata or unknown")
    result = dict(kind="spatial_spectrum",algorithm=ALGORITHM,object=v["oid"],channel=v["channel"],
        record=record,geometry=dict(geometry,data_to_world=v["object"]["data_to_world"]),roi=roi,
        units=dict(position=v["position_units"],value=v["value_units"],
                   frequency=f"cycles / ({v['position_units']})" if v["position_units"]!="unknown" else "cycles / source-coordinate unit (unknown)",
                   power=f"({v['value_units']})^2" if v["value_units"]!="unknown" else "squared channel units (unknown)"),
        mean=mean,mean_exact=float_token(mean),total_power=total,total_power_exact=float_token(total),
        parseval_relative_error=relative_error,df_xyz=df.tolist(),nyquist_xyz=nyquist.tolist(),
        radial=radial,support=support,warnings=warnings,provenance=provenance,
        workspace_bytes=workspace,timings=dict(decode_seconds=decode_seconds,
            calculation_seconds=calculation_seconds,reduction_seconds=reduction_seconds,
            fft_seconds=computed["fft_seconds"]))
    if band is not None:
        result["band"] = computed["band"]
    key = dict(source=source.identity(),object=v["oid"],channel=v["channel"],record=record,geometry=result["geometry"],roi=roi,
               units=result["units"],algorithm=ALGORITHM,bins=v["bins"],minimum_frequency=v["minimum"],band=band)
    result["request_key"] = hashlib.sha256(json.dumps(key,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    return result

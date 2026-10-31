"""Bounded native-time maps in the existing transactional scientific result store.

The stable collection uses ResultCache's manifest/support artifacts and shared
DiskQuota. It is deliberately independent of viewer-lifetime result pins. A
complete selected sequence is one atomic result; no partial sequence is replayed.
"""
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import time

import numpy as np

from . import spatial_band_map as band_map, spatial_spectrum as spectrum
from .contracts import AnalysisError, MAX_CONTROL, MIB, float_token, integer, parse_float_token
from .result_store import ResultCache, FILE_PATTERN, ID_PATTERN, encoded, regular

SCHEMA = 1
MAX_TIMES = 8
MAX_ENTRIES = 8
CACHE_BYTES = 64*MIB
RESULT_BYTES = 2*MIB
RESULT_MEMORY = 8*MIB
MAX_REPLY = MAX_CONTROL-64*1024


def implementation_identity():
    digest = hashlib.sha256()
    root = Path(__file__).parent
    for name in ("spatial_band_sequence.py", "spatial_band_map.py", "spatial_spectrum.py",
                 "source.py", "contracts.py", "channel_semantics.py", "sampling.py"):
        digest.update(name.encode()); digest.update((root/name).read_bytes())
    return digest.hexdigest()


@contextmanager
def locked(path, context):
    if path.is_symlink():
        raise AnalysisError("invalid_result", "Linked spectral cache lock refused")
    with path.open("a+b") as lock:
        while True:
            context.check()
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                time.sleep(.01)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def plan(source, arguments):
    required = {"object", "channel", "support", "band", "grid", "indices"}
    if (not isinstance(arguments, dict) or not required <= arguments.keys() or
            set(arguments)-required-{"position_units", "value_units"}):
        raise AnalysisError("invalid_request", "A sequence requires map parameters and explicit native indices, without a cursor time")
    if arguments["object"] != "field" or arguments["channel"] != "amplitude":
        raise AnalysisError("unsupported_channel", "Selected-time replay initially requires the signed field/amplitude source")
    indices = arguments["indices"]
    if not isinstance(indices, list) or not 1 <= len(indices) <= MAX_TIMES:
        raise AnalysisError("time_limit", "Select one to eight native field records; whole-capture preprocessing is not supported")
    rows = source.samples.get(arguments["object"], [])
    indices = [integer(i, "native record index", 0, len(rows)-1) for i in indices]
    if indices != sorted(set(indices)):
        raise AnalysisError("invalid_request", "Native indices must be unique and increasing")
    base = {key: value for key, value in arguments.items() if key != "indices"}
    grid = band_map._grid(base["grid"])
    support, cells = spectrum._shape(base["support"])
    plans = []
    # ResultCache.page uses its existing bounded 64 MiB parsing lease on hits.
    needed = source.context.used+64*MIB
    for index in indices:
        args = dict(base, time=float_token(rows[index]["time"]))
        v = spectrum._source_parameters(source, args)
        if v["index"] != index:
            raise AnalysisError("ambiguous_time", "A selected record cannot be uniquely addressed by its native time")
        v.update(shape=support, count=cells)
        spacing, shape_xyz, extent, df, nyquist = spectrum._frequency_geometry(v)
        band = spectrum._band_parameters(base["band"], nyquist)
        centers = band_map._centers(v, grid, spacing)
        workspace = spectrum._workspace(source, v)
        decoded = math.prod(v["spec"]["shape"])*np.dtype(v["spec"]["dtype"]).itemsize
        needed = max(needed, source.context.used+workspace+decoded*3+9*MIB+3*MIB)
        if needed > source.context.limit:
            raise AnalysisError("memory_limit", "Sequence result staging plus verified channel/FFT exceeds the request memory budget")
        plans.append(dict(arguments=args, index=index,
            record=dict(index=index, sequence=v["record"]["sequence"],
                        native_time=float_token(v["record"]["time"]),
                        requested_time=float_token(v["record"]["time"]), sampling=v["bracket"]["status"]),
            geometry=dict(v["geometry"], data_to_world=v["object"]["data_to_world"]),
            descriptor_sha256=hashlib.sha256(json.dumps(v["record"]["descriptor"],sort_keys=True,separators=(",",":")).encode()).hexdigest(),
            source_dtype=v["spec"]["dtype"], position_units=v["position_units"],
            value_units=v["value_units"], grid=grid, band=band, centers=centers,
            support_shape=support, extent_xyz=extent.tolist(), df_xyz=df.tolist(),
            nyquist_xyz=nyquist.tolist(), workspace_bytes=workspace))
    binding = dict(schema=SCHEMA, source=source.identity(), indices=indices,
        arguments=base, records=[{key: item[key] for key in ("record", "geometry", "descriptor_sha256", "source_dtype", "position_units", "value_units")} for item in plans],
        algorithm=band_map.ALGORITHM, kernel_algorithm=spectrum.ALGORITHM,
        implementation_sha256=implementation_identity(), numpy=np.__version__,
        calculation_dtype="float64", window="periodic Hann, separable in z,y,x",
        normalization=spectrum.NORMALIZATION)
    key = hashlib.sha256(encoded(binding)).hexdigest()
    admission = dict(selected_times=len(indices), centers_per_time=len(plans[0]["centers"]),
        total_centers=len(indices)*len(plans[0]["centers"]), workspace_bytes=needed,
        result_reservation_bytes=RESULT_BYTES, reply_limit_bytes=MAX_CONTROL)
    return plans, binding, key, admission


def validate_map(value, expected, source_identity):
    """Validate persisted spectral semantics, not only the ResultCache container."""
    fields = {"kind", "algorithm", "object", "channel", "record", "geometry", "grid", "support", "band", "measurements",
              "coverage", "units", "df_xyz", "nyquist_xyz", "inscribed_nyquist", "warnings", "provenance", "workspace_bytes", "timings", "request_key"}
    if not isinstance(value, dict) or set(value) != fields or value.get("kind") != "spectral_band_map" or value.get("algorithm") != band_map.ALGORITHM:
        raise AnalysisError("invalid_result", "Unsupported cached spectral map")
    args = expected["arguments"]
    for key, match in (("object", args["object"]), ("channel", args["channel"]),
                       ("record", expected["record"]), ("geometry", expected["geometry"]),
                       ("grid", expected["grid"]), ("band", expected["band"]),
                       ("df_xyz", expected["df_xyz"]), ("nyquist_xyz", expected["nyquist_xyz"]),
                       ("inscribed_nyquist", min(expected["nyquist_xyz"])),
                       ("workspace_bytes", expected["workspace_bytes"])):
        if value.get(key) != match:
            raise AnalysisError("invalid_result", f"Cached spectral {key} differs from verified request")
    cycles = [expected["band"]["low"]*extent for extent in expected["extent_xyz"]]
    support = dict(shape=expected["support_shape"], axis_order="zyx", extent_xyz=expected["extent_xyz"],
        center_span_xyz=[(n-1)*spacing for n, spacing in zip(expected["support_shape"][::-1], expected["geometry"]["spacing"])],
        df_xyz=expected["df_xyz"], minimum_frequency=expected["band"]["low"], cycles_xyz=cycles,
        status="insufficient_support" if min(cycles) < 2 else "candidate",
        criterion="at least two cycles of the low band edge on every axis; heuristic, not a resolution guarantee",
        bounds="complete finite source samples only; no padding or wrap")
    if value.get("support") != support:
        raise AnalysisError("invalid_result", "Cached support or resolution warning differs")
    position, channel_units = expected["position_units"], expected["value_units"]
    units = dict(position=position, value=channel_units,
        frequency=f"cycles / ({position})" if position != "unknown" else "cycles / source-coordinate unit (unknown)",
        power=f"({channel_units})^2" if channel_units != "unknown" else "squared channel units (unknown)")
    if value.get("units") != units:
        raise AnalysisError("invalid_result", "Cached units differ")
    provenance = value.get("provenance", {})
    expected_provenance_fields = {"algorithm", "kernel_algorithm", "numpy", "calculation_dtype", "source_dtype", "window", "detrending", "normalization", "power_meaning", "geometry_policy", "descriptor_sha256", "unit_policy", "position_units_source", "value_units_source", "batching"}
    if not isinstance(provenance, dict) or set(provenance) != expected_provenance_fields:
        raise AnalysisError("invalid_result", "Cached provenance schema differs")
    for key, match in (("algorithm", band_map.ALGORITHM), ("kernel_algorithm", spectrum.ALGORITHM),
                       ("descriptor_sha256", expected["descriptor_sha256"]),
                       ("source_dtype", expected["source_dtype"]), ("calculation_dtype", "float64"),
                       ("numpy", np.__version__),
                       ("normalization", spectrum.NORMALIZATION),
                       ("detrending", "mu=sum(w*q)/sum(w); DFT input=w*(q-mu)"),
                       ("power_meaning", "sum of exact-band window-weighted mean-square residual powers; not Hamiltonian energy"),
                       ("geometry_policy", "data_local; identity linear data_to_world; translation changes world centers only"),
                       ("unit_policy", "canonical position_unit and channel_metadata only; no automatic conversion"),
                       ("position_units_source", "explicit request override" if "position_units" in args else "capture position_unit or unknown"),
                       ("value_units_source", "explicit request override" if "value_units" in args else "capture channel_metadata or unknown"),
                       ("batching", "one native selected-channel decode; one sequential FFT workspace; no display-preview input"),
                       ("window", "periodic Hann, separable in z,y,x")):
        if provenance.get(key) != match:
            raise AnalysisError("invalid_result", "Cached numerical provenance differs")
    measurements = value.get("measurements")
    if not isinstance(measurements, list) or len(measurements) != len(expected["centers"]):
        raise AnalysisError("invalid_result", "Cached center count differs")
    for actual, center in zip(measurements, expected["centers"]):
        if not isinstance(actual, dict):
            raise AnalysisError("invalid_result", "Invalid cached center")
        for name in ("row", "column", "start", "end", "center_index_xyz", "center_xyz", "center_world_xyz", "coordinate_space"):
            if actual.get(name) != center[name]:
                raise AnalysisError("invalid_result", "Cached center location/order differs")
        status = actual.get("status")
        if status not in ("measured", "outside_support", "nonfinite_samples", "numerical_range"):
            raise AnalysisError("invalid_result", "Invalid cached availability")
        if (center["status"] == "outside_support") != (status == "outside_support"):
            raise AnalysisError("invalid_result", "Cached support mask differs")
        center_fields = set(center)|({"selected_half_complex_bins"} if status == "measured" else {"reason"})
        if set(actual) != center_fields:
            raise AnalysisError("invalid_result", "Cached center schema differs")
        if status != "measured" and (not isinstance(actual.get("reason"), str) or not actual["reason"] or len(actual["reason"]) > 4096 or actual.get("parseval_relative_error") is not None):
            raise AnalysisError("invalid_result", "Cached missing-data reason differs")
        for name in ("power", "mean", "total_power"):
            if status == "measured":
                number = actual.get(name)
                if type(number) not in (int, float) or not math.isfinite(number) or (name != "mean" and number < 0):
                    raise AnalysisError("invalid_result", "Invalid cached numerical value")
                if parse_float_token(actual.get(name+"_exact")) != number:
                    raise AnalysisError("invalid_result", "Cached exact token differs from value")
            elif actual.get(name) is not None or actual.get(name+"_exact") is not None:
                raise AnalysisError("invalid_result", "Unavailable cached power must be null")
        if status == "measured":
            error = actual.get("parseval_relative_error")
            if type(error) not in (int, float) or not math.isfinite(error) or error < 0:
                raise AnalysisError("invalid_result", "Invalid cached Parseval diagnostic")
            integer(actual.get("selected_half_complex_bins"), "cached Fourier bins", 0, 192**3)
    mask = [row["status"] == "measured" for row in measurements]
    if value.get("coverage") != dict(total=len(mask), measured=sum(mask), unavailable=len(mask)-sum(mask), mask=mask):
        raise AnalysisError("invalid_result", "Cached coverage differs from measured centers")
    warnings = value.get("warnings")
    if not isinstance(warnings, list) or not 4 <= len(warnings) <= 8 or any(not isinstance(item, str) or not item or len(item) > 4096 for item in warnings):
        raise AnalysisError("invalid_result", "Cached warning schema differs")
    timings = value.get("timings")
    timing_fields = {"decode_seconds", "calculation_seconds", "reduction_seconds", "fft_seconds", "batch_seconds", "decoded_samples"}
    if not isinstance(timings, dict) or set(timings) != timing_fields or timings.get("decoded_samples") != 1 or any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in timings.values()):
        raise AnalysisError("invalid_result", "Cached timing schema differs")
    key = dict(source=source_identity, object=value["object"], channel=value["channel"], record=value["record"],
               geometry=value["geometry"], grid=value["grid"], support=value["support"], band=value["band"], units=value["units"],
               algorithm=band_map.ALGORITHM, kernel_algorithm=spectrum.ALGORITHM)
    if value.get("request_key") != hashlib.sha256(json.dumps(key,sort_keys=True,separators=(",",":")).encode()).hexdigest():
        raise AnalysisError("invalid_result", "Cached direct-map key differs")
    if len(encoded(value)) > MAX_REPLY:
        raise AnalysisError("invalid_result", "Cached map exceeds bounded transport")


class SpectralCache:
    def __init__(self, registry, *, quota=None, byte_limit=CACHE_BYTES, entry_limit=MAX_ENTRIES):
        registry = Path(registry).absolute()
        self.owner = registry/"spectral-cache"
        if self.owner.is_symlink():
            raise AnalysisError("invalid_result", "Linked spectral cache owner refused")
        self.owner.mkdir(parents=True, exist_ok=True)
        self.cache = ResultCache(self.owner/"results", registry_root=registry, quota=quota)
        self.byte_limit = integer(byte_limit, "spectral cache bytes", 1, CACHE_BYTES)
        self.entry_limit = integer(entry_limit, "spectral cache entries", 1, MAX_ENTRIES)

    def remove(self, path, context):
        # Same allowlisted ResultCache collection boundary; corrupt manifests do
        # not authorize arbitrary paths or recursive deletion.
        if not re.fullmatch(r"(?:\.pending-)?"+ID_PATTERN, path.name) or path.is_symlink() or not path.is_dir():
            raise AnalysisError("invalid_result", "Unknown spectral cache entry; cleanup refused")
        entries = []
        for item in path.iterdir():
            context.check()
            if len(entries) >= 1026 or not re.fullmatch(FILE_PATTERN, item.name) or not stat.S_ISREG(item.lstat().st_mode):
                raise AnalysisError("invalid_result", "Unknown spectral artifact; cleanup refused")
            entries.append(item)
        with locked(self.cache.quota.root/".g4-quota.lock", context), context.defer_checkpoints():
            for item in entries:
                context.check(); item.unlink()
            path.rmdir()

    def entries(self, context):
        found = []
        for number, path in enumerate(self.cache.root.iterdir()):
            context.check()
            if number >= 32:
                raise AnalysisError("result_limit", "Spectral cache scan exceeds its bounded entry count")
            if not re.fullmatch(r"(?:\.pending-)?"+ID_PATTERN, path.name) or path.is_symlink() or not path.is_dir():
                raise AnalysisError("invalid_result", "Unknown spectral cache entry; refusing reuse")
            try:
                info = regular(path/"manifest.json")
                if info[2] > MAX_CONTROL:
                    raise AnalysisError("invalid_result", "Oversized spectral manifest")
                with (path/"manifest.json").open("rb") as stream:
                    content = stream.read(MAX_CONTROL+1)
                context.check()
                if len(content) > MAX_CONTROL or regular(path/"manifest.json") != info:
                    raise AnalysisError("invalid_result", "Spectral manifest changed during bounded read")
                digest = hashlib.sha256(content).hexdigest()
                if path.name != "r-"+digest[:32]:
                    raise AnalysisError("invalid_result", "Spectral manifest identity mismatch")
                ref = dict(version=1, id=path.name, manifest_sha256=digest)
                manifest = self.cache.manifest(ref, context)
                if manifest.get("kind") != "spectral_band_sequence" or manifest.get("schema") != SCHEMA:
                    raise AnalysisError("invalid_result", "Unsupported spectral cache schema")
                allowed = {"manifest.json"}|{a["path"] for a in manifest["artifacts"]}
                paths = []
                for artifact in path.iterdir():
                    context.check()
                    if len(paths) >= 1025:
                        raise AnalysisError("invalid_result", "Spectral artifact count exceeds its bound")
                    paths.append(artifact)
                if len(paths) != len(allowed) or any(p.name not in allowed for p in paths):
                    raise AnalysisError("invalid_result", "Unexpected spectral artifacts")
                size = sum(max(4096, regular(p)[2]) for p in paths)
                found.append(dict(path=path, ref=ref, manifest=manifest, bytes=size, age=info[3]))
            except (AnalysisError, OSError, ValueError, TypeError):
                self.remove(path, context)
        return sorted(found, key=lambda item: item["age"])

    def load(self, entry, binding, plans, context):
        manifest = entry["manifest"]
        if manifest.get("binding") != binding:
            raise AnalysisError("invalid_result", "Cached source/request binding differs")
        metadata = manifest.get("maps")
        if not isinstance(metadata, list) or len(metadata) != len(plans) or manifest["row_count"] != 0:
            raise AnalysisError("invalid_result", "Cached sequence schema differs")
        maps = [dict(item, measurements=[]) for item in metadata]
        expected_count = sum(len(p["centers"]) for p in plans)
        if manifest["support_count"] != expected_count:
            raise AnalysisError("invalid_result", "Cached sequence is incomplete")
        offset = 0
        while offset < expected_count:
            page = self.cache.page(entry["ref"], offset=offset, limit=128, kind="support", context=context)
            if page["next_offset"] <= offset:
                raise AnalysisError("invalid_result", "Cached sequence page is incomplete")
            for row in page["rows"]:
                if not isinstance(row, dict) or set(row) != {"map", "center"}:
                    raise AnalysisError("invalid_result", "Unsupported spectral support record")
                index = integer(row["map"], "cached map index", 0, len(maps)-1)
                if index != offset//len(plans[0]["centers"]):
                    raise AnalysisError("invalid_result", "Cached sequence center order differs")
                maps[index]["measurements"].append(row["center"]); offset += 1
        for value, expected in zip(maps, plans):
            validate_map(value, expected, binding["source"])
        return maps


class Publication:
    def __init__(self, store, writer, context, lock, cache_status):
        self.store, self.writer, self.context, self.lock = store, writer, context, lock
        self.status = cache_status
        self.created = None
        self.closed = False

    def release(self):
        if not self.closed:
            self.closed = True
            self.lock.__exit__(None, None, None)

    def commit(self):
        try:
            with self.context.defer_checkpoints():
                self.context.check(); self.context.verify_publication()
                reference = self.writer.finish()
                self.created = reference
                target = self.store.cache.root/("r-"+reference["manifest_sha256"][:32])
                if target.exists():
                    existing = dict(reference, id=target.name)
                    self.store.cache.manifest(existing, self.context)
                    self.store.cache.discard(reference)
                    self.created = None
                else:
                    os.rename(self.store.cache.directory(reference), target)
                    self.created = dict(reference, id=target.name)
                self.context.verify_publication()
                self.status["stored_bytes"] = sum(p.stat().st_size for p in target.iterdir())
                directory = os.open(self.store.cache.root, os.O_RDONLY)
                try: os.fsync(directory)
                finally: os.close(directory)
        except Exception:
            self.abort("publication failed")
            raise
        finally:
            self.release()

    def abort(self, reason):
        try:
            if not self.writer.closed:
                self.writer.abort()
            if self.created:
                self.store.cache.discard(self.created)
                self.created = None
        finally:
            self.release()


def run(source, arguments, store):
    if store is None:
        raise AnalysisError("invalid_result", "Owned spectral result collection unavailable")
    context = source.context
    with context.allocation(RESULT_MEMORY):
        plans, binding, key, admission = plan(source, arguments)
        lock = locked(store.owner/".spectral.lock", context)
        lock.__enter__()
        publication = None
        try:
            lookup_started = time.perf_counter()
            entries = store.entries(context)
            maps = None; hit = None
            for entry in entries[:]:
                if entry["manifest"].get("request_key") != key:
                    continue
                try:
                    maps = store.load(entry, binding, plans, context); hit = entry; break
                except (AnalysisError, ValueError, TypeError, KeyError) as exc:
                    if isinstance(exc, AnalysisError) and exc.code in ("cancelled", "deadline", "memory_limit", "source_changed"):
                        raise
                    store.remove(entry["path"], context); entries.remove(entry)
            lookup_seconds = time.perf_counter()-lookup_started
            status = dict(hit=hit is not None, policy="exact selected sequence", stored_bytes=0,
                          entry_count=len(entries), limit_bytes=store.byte_limit)
            prepare_started = time.perf_counter()
            if hit is None:
                if RESULT_BYTES > store.byte_limit:
                    raise AnalysisError("result_limit", "Selected sequence reservation exceeds the spectral cache quota")
                while entries and (len(entries) >= store.entry_limit or sum(e["bytes"] for e in entries)+RESULT_BYTES > store.byte_limit):
                    store.remove(entries.pop(0)["path"], context)
                writer = store.cache.begin(dict(kind="spectral_band_sequence", schema=SCHEMA,
                    request_key=key, binding=binding), expected_rows=0,
                    expected_support=admission["total_centers"], byte_limit=RESULT_BYTES, context=context)
                publication = Publication(store, writer, context, lock, status)
                maps = []
                for i, item in enumerate(plans):
                    context.progress("band_sequence_times", i, len(plans))
                    value = band_map.run(source, item["arguments"])
                    validate_map(value, item, source.identity())
                    maps.append(value)
                    for center in value["measurements"]:
                        writer.append(dict(map=i, center=center), kind="support")
                    context.progress("band_sequence_times", i+1, len(plans))
                writer.base["maps"] = [{k: v for k, v in value.items() if k != "measurements"} for value in maps]
                status["entry_count"] = len(entries)+1
            else:
                status["stored_bytes"] = sum(p.stat().st_size for p in hit["path"].iterdir())
            result = dict(kind="spectral_band_sequence", schema=SCHEMA, indices=binding["indices"], maps=maps,
                request_key=key, cache=status, admission=admission,
                timings=dict(lookup_seconds=lookup_seconds, prepare_seconds=time.perf_counter()-prepare_started),
                provenance=dict(implementation_sha256=binding["implementation_sha256"], numpy=np.__version__,
                    storage="existing ResultCache manifest and support artifacts; atomic complete selection",
                    source_policy="verified committed prefix; appended extents miss; no path/UUID-only reuse"))
            if len(encoded(result)) > MAX_REPLY:
                raise AnalysisError("control_limit", "Selected maps exceed the bounded worker reply; reduce selected times or centers")
            source.verify(); context.verify_publication()
            if publication is not None:
                context.stage_publication(publication)
            return result
        except Exception as exc:
            if publication is not None:
                publication.abort(exc)
            raise
        finally:
            if publication is None:
                lock.__exit__(None, None, None)

"""Private, bounded phase-preserving reconstruction of one verified native field.

Dense files are an internal viewer handoff, not a capture/export format. The
float64 files are authoritative; full-grid float32 copies serve display only.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import time
import uuid

import numpy as np

from . import channel_semantics as units
from .contracts import AnalysisError, MIB, float_token, integer, request_float
from .disk_quota import DiskQuota
from .member_assets import process_birth

ALGORITHM = "spectral-reconstruction-periodic-v1"
MAX_AXIS = 192
MAX_CELLS = MAX_AXIS**3
BANDS = ("low", "intermediate", "high")
NAMES = ("original",) + BANDS
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]
OWNER_KIND = "wavez-spectral-reconstruction-v1"


def _json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def _regular(path, maximum=None):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or (maximum is not None and info.st_size > maximum):
        raise AnalysisError("invalid_result", "Unexpected file in private reconstruction store")
    return info


class DenseReconstructionStore:
    """One owned result, replaced only when the viewer starts another request.

    Use a separate quota owner, never the CSV/JSONL ResultCache directory. No
    cleanup follows links or removes unrecognized entries. A crashed worker's
    store is reclaimed by the next worker after PID-birth verification.
    """
    def __init__(self, root, *, registry_root=None, disk_limit=2*1024*MIB):
        self.root = Path(root).absolute()
        self.root.mkdir(parents=True, exist_ok=True)
        if self.root.is_symlink():
            raise AnalysisError("invalid_result", "Linked reconstruction store refused")
        self.root = self.root.resolve()
        self.registry = Path(registry_root or self.root.parent).resolve()
        if self.root.parent != self.registry:
            raise AnalysisError("invalid_result", "Reconstruction store must be an immediate private quota owner")
        self.results = self.root / "results"
        self.results.mkdir(exist_ok=True)
        if self.results.is_symlink():
            raise AnalysisError("invalid_result", "Linked reconstruction results refused")
        self.quota = DiskQuota(self.registry, limit=disk_limit)
        self.owner = dict(kind=OWNER_KIND, pid=os.getpid(), birth=process_birth(os.getpid()))
        owner = self.root / "owner.json"
        if owner.exists():
            _regular(owner, 4096)
            if json.loads(owner.read_text()) != self.owner:
                raise AnalysisError("invalid_result", "Reconstruction store belongs to another worker")
        else:
            with owner.open("xb") as file:
                file.write(_json(self.owner))
        self._validate()

    def _validate(self):
        if set(p.name for p in self.root.iterdir()) != {"owner.json", "results"}:
            raise AnalysisError("invalid_result", "Unknown reconstruction owner entries")
        entries = list(self.results.iterdir())
        if len(entries) > 2:
            raise AnalysisError("disk_limit", "Too many retained reconstruction results")
        for directory in entries:
            if directory.is_symlink() or not directory.is_dir() or not re.fullmatch(r"d-[0-9a-f]{32}(?:\.part)?", directory.name):
                raise AnalysisError("invalid_result", "Unknown reconstruction directory")
            files = list(directory.iterdir())
            allowed = {name + suffix for name in NAMES for suffix in (".f4", ".f8")} | {"reservation.json", "manifest.json"}
            if len(files) > 10 or any(p.name not in allowed for p in files):
                raise AnalysisError("invalid_result", "Unknown reconstruction files")
            for path in files:
                _regular(path, MAX_CELLS*8 if path.suffix in (".f4", ".f8") else MIB)

    def clear(self):
        self._validate()  # Validate the complete tree before removing anything.
        for directory in self.results.iterdir():
            for path in directory.iterdir():
                path.unlink()
            directory.rmdir()

    def close(self):
        self.clear()
        (self.root / "owner.json").unlink()
        self.results.rmdir()
        self.root.rmdir()

    def release(self, manifest):
        """A viewer may release its exact completed handoff, never a staged job."""
        if not isinstance(manifest, str):
            return
        path = Path(manifest)
        if path.parent.parent != self.results or path.name != "manifest.json" or not re.fullmatch(r"d-[0-9a-f]{32}", path.parent.name):
            return
        if not path.parent.exists():
            return
        self._validate()
        for item in path.parent.iterdir():
            item.unlink()
        path.parent.rmdir()

    @classmethod
    def reap_abandoned(cls, registry, context):
        for root in Path(registry).iterdir():
            context.check()
            if root.is_symlink() or not root.is_dir() or not root.name.endswith("-reconstruction"):
                continue
            owner = root / "owner.json"
            try:
                _regular(owner, 4096)
                value = json.loads(owner.read_text())
                if set(value) != {"kind", "pid", "birth"} or value["kind"] != OWNER_KIND:
                    continue
                pid = integer(value["pid"], "worker pid", 1, 2**31-1)
                birth = process_birth(pid)
                if not isinstance(value["birth"], str) or birth == value["birth"]:
                    continue
                if birth is None:
                    try:
                        os.kill(pid, 0)
                    except ProcessLookupError:
                        pass
                    except OSError:
                        continue  # An inaccessible process is not proven dead.
                    else:
                        continue
                store = object.__new__(cls)
                store.root, store.results = root, root / "results"
                if store.results.is_symlink() or not store.results.is_dir():
                    continue
                store.close()
            except (OSError, ValueError):
                continue  # Unrecognized trees remain quarantined, never erased.

    def begin(self, count, context):
        self.clear()
        name = "d-" + uuid.uuid4().hex
        stage, target = self.results / (name + ".part"), self.results / name
        reserved = count*48 + 2*MIB  # Four f64 authorities + four f32 displays.
        with self.quota.reserve(reserved, 10, context):
            stage.mkdir()
            try:
                (stage / "reservation.json").write_bytes(_json(dict(bytes=reserved, files=10)))
            except Exception:
                stage.rmdir()
                raise
        return _Publication(stage, target, context)


class _Publication:
    def __init__(self, stage, target, context):
        self.stage, self.target, self.context = stage, target, context
        self.committed = False

    def write_array(self, name, array):
        metadata = {}
        for dtype in ("f8", "f4"):
            self.context.check()
            filename = name + "." + dtype
            digest = hashlib.sha256()
            size = 0
            # Plane-sized conversion bounds display conversion and I/O scratch.
            with (self.stage / filename).open("xb") as file:
                for plane in array:
                    self.context.check()
                    encoded = np.asarray(plane, dtype="<" + dtype).tobytes(order="C")
                    file.write(encoded)
                    digest.update(encoded)
                    size += len(encoded)
                file.flush()
                os.fsync(file.fileno())
            metadata[dtype] = dict(path=str(self.target / filename), sha256=digest.hexdigest(),
                                   bytes=size, dtype=dtype)
        result = metadata["f4"]
        result.update(shape_zyx=list(array.shape), minimum=float(array.min()), maximum=float(array.max()),
                      scientific=metadata["f8"])
        return result

    def finish(self, data):
        payload = _json(data)
        if len(payload) > MIB:
            raise AnalysisError("control_limit", "Reconstruction manifest exceeds its bounded control size")
        with (self.stage / "manifest.json").open("xb") as file:
            file.write(payload)
            file.flush()
            os.fsync(file.fileno())
        self.context.stage_publication(self)
        return dict(path=str(self.target / "manifest.json"), sha256=hashlib.sha256(payload).hexdigest())

    def commit(self):
        self.context.verify_publication()
        os.rename(self.stage, self.target)
        self.committed = True

    def abort(self, _reason=None):
        directory = self.target if self.committed else self.stage
        if directory.exists():
            for path in directory.iterdir():
                _regular(path)
                path.unlink()
            directory.rmdir()


def _parameters(source, arguments):
    allowed = {"object", "channel", "index", "boundary", "edges"}
    if not isinstance(arguments, dict) or set(arguments)-allowed or not allowed-{"edges"} <= arguments.keys():
        raise AnalysisError("invalid_request", "Reconstruction requires object, channel, native index and explicit periodic boundary")
    if arguments["object"] != "field" or arguments["channel"] != "amplitude":
        raise AnalysisError("unsupported_channel", "This bounded candidate supports original field/amplitude only")
    if arguments["boundary"] != "periodic":
        raise AnalysisError("unsupported_boundary", "Reconstruction requires an explicitly accepted periodic full-domain boundary")
    obj = source.objects.get("field", {})
    if obj.get("kind") != "volume":
        raise AnalysisError("unsupported_geometry", "Reconstruction requires a uniform source volume")
    if obj["data_to_world"] != IDENTITY:
        raise AnalysisError("unsupported_transform", "Reconstruction currently requires an identity data-to-world transform")
    index = integer(arguments["index"], "native sample index", 0, len(source.samples["field"])-1)
    record = source.samples["field"][index]
    geometry = record["descriptor"]["geometry"]
    shape = geometry["shape"]
    if len(shape) != 3 or any(n < 2 or n > MAX_AXIS for n in shape) or math.prod(shape) > MAX_CELLS:
        raise AnalysisError("unsupported_geometry", "Full source dimensions must each be 2–192; no cropping or LOD is applied")
    spec = next((a for a in record["descriptor"]["arrays"] if a["name"] == "amplitude"), {})
    if spec.get("dtype") != "f8" or spec.get("association") != "sample" or spec.get("shape") != shape:
        raise AnalysisError("unsupported_channel", "Reconstruction requires original float64 scalar amplitude; float32 is not promoted to scientific float64")
    declaration = units.declaration(source, "field", {"channel": "amplitude"})
    if declaration["semantic"] not in ("continuous", "signed"):
        raise AnalysisError("unsupported_semantics", "Reconstruction requires an ordinary signed scalar amplitude")
    edges = arguments.get("edges", [.125, .375])
    if not isinstance(edges, list) or len(edges) != 2:
        raise AnalysisError("invalid_request", "Two finite ordered radial edges required")
    edges = [request_float(e, "radial edge") for e in edges]
    if not 0 < edges[0] < edges[1]:
        raise AnalysisError("invalid_request", "Radial edges must satisfy 0 < low < high")
    return obj, index, record, geometry, declaration, edges


def workspace_bytes(shape):
    """Conservative additional lease; SourceSnapshot separately charges decoding.

    80 bytes/full cell cover retained accumulator, inverse output and FFT/copy
    scratch; 64 bytes/half cell cover coefficients, masked coefficients and
    FFT intermediates; 32 MiB cover bounded planes, conversion and JSON/I/O.
    NumPy's calls are indivisible, with checkpoints immediately before/after.
    """
    return math.prod(shape)*80 + math.prod((*shape[:2], shape[2]//2+1))*64 + 32*MIB


def _mean_square(array):
    return float(np.einsum("ijk,ijk->", array, array, optimize=False)/array.size)


def _ac_mean_square(array, mean):
    # Subtract before squaring; total power minus DC power loses weak AC fields
    # in a large offset through catastrophic cancellation. Plane scratch only.
    total = 0.
    for plane in array:
        centered = plane-mean
        total += float(np.einsum("ij,ij->", centered, centered, optimize=False))
    return total/array.size


def run(source, arguments, store):
    if not isinstance(store, DenseReconstructionStore):
        raise AnalysisError("invalid_result", "Owned reconstruction store unavailable")
    store.clear()
    started = time.perf_counter()
    obj, index, record, geometry, declaration, edges = _parameters(source, arguments)
    shape, context = geometry["shape"], source.context
    count = math.prod(shape)
    publication = None
    # Admit workspace before decoding. SourceSnapshot then independently admits
    # the source/decode lease; both remain charged throughout the algorithm.
    try:
        with context.allocation(workspace_bytes(shape)):
            decode_started = time.perf_counter()
            with source.read_sample("field", index, ["amplitude"]) as sample:
                original = sample.arrays["amplitude"]
                decode_seconds = time.perf_counter()-decode_started
                context.check()
                if not np.isfinite(original).all():
                    raise AnalysisError("nonfinite_samples", "Full source contains nonfinite amplitudes; no reconstruction is published")
                maximum = max(abs(float(original.min())), abs(float(original.max())))
                if maximum > np.finfo(np.float32).max:
                    raise AnalysisError("numerical_range", "Source amplitude cannot be represented by the float32 display handoff")
                power = _mean_square(original)
                mean = float(original.mean())
                ac_power = _ac_mean_square(original, mean)
                if not math.isfinite(power):
                    raise AnalysisError("numerical_range", "Source mean-square exceeds float64 range")
                publication = store.begin(count, context)
                context.progress("reconstruction_fft", 0, 3)
                fft_started = time.perf_counter()
                coefficients = np.fft.rfftn(original)
                context.check()
                fft_seconds = time.perf_counter()-fft_started
                spacing = geometry["spacing"][::-1]
                frequencies = [np.fft.fftfreq(n, d) for n, d in zip(shape[:2], spacing[:2])]
                frequencies.append(np.fft.rfftfreq(shape[2], spacing[2]))
                if any(not np.isfinite(axis).all() for axis in frequencies):
                    raise AnalysisError("numerical_range", "Source frequency coordinates exceed float64 range")
                plane_radius = np.hypot(frequencies[1][:, None], frequencies[2][None, :])
                multiplicity = np.full(shape[2]//2+1, 2., dtype=np.float64)
                multiplicity[0] = 1.
                if shape[2] % 2 == 0:
                    multiplicity[-1] = 1.
                scratch = np.empty_like(coefficients)
                combined = np.zeros(shape, dtype=np.float64)
                artifacts = {"original": publication.write_array("original", original)}
                band_metrics = {}
                reconstruct_started = time.perf_counter()
                for band_index, name in enumerate(BANDS):
                    context.progress("reconstruction_" + name, band_index, 3)
                    spectral_power = 0.
                    cells = 0
                    for z, fz in enumerate(frequencies[0]):
                        context.check()
                        radius = np.hypot(plane_radius, fz)
                        mask = radius < edges[0] if band_index == 0 else ((radius >= edges[0]) & (radius < edges[1])) if band_index == 1 else radius >= edges[1]
                        np.multiply(coefficients[z], mask, out=scratch[z])
                        spectral_power += float(np.sum((scratch[z].real**2 + scratch[z].imag**2)*multiplicity)) / count**2
                        cells += int(np.sum(mask*multiplicity))
                    context.check()
                    reconstructed = np.fft.irfftn(scratch, s=shape, axes=(0, 1, 2))
                    context.check()
                    if not np.isfinite(reconstructed).all() or max(abs(float(reconstructed.min())), abs(float(reconstructed.max()))) > np.finfo(np.float32).max:
                        raise AnalysisError("numerical_range", "A reconstructed band cannot be represented by the finite display handoff")
                    measured_power = _mean_square(reconstructed)
                    error = abs(measured_power-spectral_power)/max(power, np.finfo(float).tiny)
                    if not math.isfinite(spectral_power) or error > 1e-11:
                        raise AnalysisError("numerical_accuracy", "Reconstructed band failed float64 Parseval validation")
                    combined += reconstructed
                    artifacts[name] = publication.write_array(name, reconstructed)
                    band_metrics[name] = dict(mean_square=measured_power, spectral_mean_square=spectral_power,
                        fraction=measured_power/power if power else 0., full_dft_cells=cells,
                        parseval_relative_error=error,
                        ac_mean_square=_ac_mean_square(reconstructed, mean) if name == "low" else measured_power)
                    del reconstructed
                combined -= original
                residual_rms = math.sqrt(_mean_square(combined))
                residual_max = max(abs(float(combined.min())), abs(float(combined.max())))
                relative_rms = residual_rms / math.sqrt(power) if power else residual_rms
                spectral_total = sum(m["spectral_mean_square"] for m in band_metrics.values())
                parseval_error = abs(spectral_total-power)/max(power, np.finfo(float).tiny)
                if relative_rms > 1e-11 or parseval_error > 1e-11 or sum(m["full_dft_cells"] for m in band_metrics.values()) != count:
                    raise AnalysisError("numerical_accuracy", "Disjoint band reconstruction failed residual or Parseval validation")
                for name, metrics in band_metrics.items():
                    metrics["ac_fraction"] = metrics["ac_mean_square"]/ac_power if ac_power else 0.
                lengths = [n*d for n, d in zip(shape[::-1], geometry["spacing"])]
                data = dict(kind="spectral_reconstruction", version=1, algorithm=ALGORITHM,
                    source=source.identity(), source_stamp={key: str(value) for key, value in zip(("device", "inode", "size", "mtime_ns", "ctime_ns"), source.stamp)},
                    object="field", channel="amplitude", record=dict(index=index, sequence=record["sequence"], native_time=float_token(record["time"])),
                    geometry=dict(geometry, data_to_world=obj["data_to_world"]), boundary="periodic", edges=edges,
                    units=dict(position=units.position_unit(source, "field"), value=declaration["units"], frequency="cycles/source-coordinate unit"),
                    common_range=[-maximum, maximum], artifacts=artifacts,
                    metrics=dict(source_mean=mean, mean_square=power, ac_mean_square=ac_power, bands=band_metrics,
                        residual_rms=residual_rms, residual_max=residual_max, residual_relative_rms=relative_rms,
                        parseval_relative_error=parseval_error, transfer_bytes=count*16, scientific_bytes=count*32,
                        workspace_bytes=workspace_bytes(shape)),
                    support=dict(length_xyz=lengths, fundamental_xyz=[1./length for length in lengths],
                        nyquist_xyz=[.5/d for d in geometry["spacing"]], low_edge_cycles_xyz=[edges[0]*length for length in lengths],
                        dc_band="low", intervals=["[0, low)", "[low, high)", "[high, sampled corner]"],
                        assumption="Explicit periodic full domain; no boundary declaration is inferred from the capture"),
                    timings=dict(decode_seconds=decode_seconds, fft_seconds=fft_seconds,
                        reconstruction_and_write_seconds=time.perf_counter()-reconstruct_started, total_seconds=time.perf_counter()-started),
                    provenance=dict(source_dtype="f8", scientific_dtype="f8", display_dtype="f4", lod=1,
                        transform="identity", normalization="NumPy backward DFT; disjoint real radial masks; inverse keeps complex phase",
                        lifetime="One worker-owned result; next reconstruction or worker shutdown clears it"))
                del original, coefficients, scratch, combined
            source.verify()
            source.verify_members()
            context.check()
            data["source_stamp"] = {key: str(value) for key, value in zip(("device", "inode", "size", "mtime_ns", "ctime_ns"), source.stamp)}
            data["manifest"] = publication.finish(data)
        return data
    except Exception as exc:
        if publication is not None:
            publication.abort(exc)
        raise

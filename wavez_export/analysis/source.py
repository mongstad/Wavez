"""Pinned, validated scientific reads with no rendering or live-reader state.

Only the existing scanners/validators define capture bytes. A bounded file view
supplies their EOF, so even malformed future records cannot extend a pinned job.
"""

from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path

import numpy as np

from .. import codec
from .. import storage as typed
from ..scene import SceneReader
from ..metadata_budget import MetadataBudget, MetadataCapacityError
from .contracts import AnalysisError, Context, MIB, integer
from .memo import VerificationMemo


def _stamp(path, file):
    a, b = path.stat(), os.fstat(file.fileno())
    fields = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)
    if fields(a) != fields(b):
        raise AnalysisError("source_changed", "Opened source and path no longer identify the same file")
    return fields(a)


class _BoundedFile:
    def __init__(self, raw, extent, context):
        self.raw = raw
        self.read_extent = extent
        self.context = context
        self.indexing = True

    def fileno(self):
        return self.raw.fileno()

    def tell(self):
        return self.raw.tell()

    def seek(self, offset, whence=0):
        self.context.check()
        position = offset if whence == 0 else (self.tell() if whence == 1 else self.read_extent)+offset
        if whence not in (0, 1, 2) or position < 0 or position > self.read_extent:
            raise AnalysisError("source_extent", "Read attempted outside committed source extent")
        return self.raw.seek(position)

    def read(self, count=-1):
        self.context.check()
        count = self.read_extent-self.tell() if count < 0 else min(count, self.read_extent-self.tell())
        if count < 0 or count > 4*MIB:
            raise AnalysisError("memory_limit", "Source read exceeds bounded chunk size")
        data = self.raw.read(count)
        if len(data) != count:
            raise AnalysisError("source_changed", "Source truncated during a bounded read")
        self.context.read_bytes += len(data)
        if self.indexing:
            self.context.progress("source_index", self.tell(), self.read_extent)
        return data


class _SceneIndex(SceneReader):
    """Use the current scene validator without owning a second live file/cache."""

    def __init__(self, source, strict):
        self.source = source
        self.path = source.path
        self.file = source.file
        self.metadata_budget = source.metadata_budget
        self.records = []
        self._scan(strict)

    def _unchanged(self):
        self.source.verify()


@dataclass
class Sample:
    object_id: str
    record: dict
    arrays: dict
    descriptors: dict
    unavailable: tuple
    context: Context
    charge: int

    def close(self):
        if self.charge:
            self.arrays.clear()
            self.context.release(self.charge)
            self.charge = 0

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class SourceSnapshot:
    """Read-only record snapshot; acquired Samples must be closed.

    With no explicit extent, pin the last complete record seen on open. With an
    extent, require a valid complete prefix. Appends are accepted only after the
    pinned SHA-256 is reverified; replacement/truncation/mutation are errors.
    """

    def __init__(self, path, *, committed_bytes=None, sha256=None, context=None, memo=None, assets=None, metadata_bytes=None):
        self.path = Path(path).absolute()
        self.context = context or Context()
        self.raw = self.path.open("rb")
        self.charge = 0
        self.memo = memo if memo is not None else VerificationMemo(0)
        self.memo_charge = 0
        self.assets = assets
        self.member_arrays = {}
        self.member_stamps = {}
        self.member_charge = 0
        self.closed = False
        self.sha256 = None
        self.metadata_budget = None
        try:
            # Metadata shares the request's total workspace; an optional lower
            # metadata budget cannot bypass that enclosing allocation limit.
            self.metadata_budget = MetadataBudget(
                self.context.limit if metadata_bytes is None else metadata_bytes,
                acquire=self._acquire_metadata, release=self.context.release)
            self.memo_charge = self.context.acquire(self.memo.limit)
            # Preserve the analysis adapter's existing fixed bookkeeping/I/O
            # allowance in addition to measured retained metadata.
            self.charge = self.context.acquire(MIB)
            self.stamp = _stamp(self.path, self.raw)
            extent = self.stamp[2] if committed_bytes is None else typed.decimal(committed_bytes)
            if not 16 <= extent <= self.stamp[2]:
                raise AnalysisError("source_extent", "Invalid or truncated committed extent")
            self.file = _BoundedFile(self.raw, extent, self.context)
            magic = self.file.read(8)
            if magic != b"SIMSCP4\0":
                raise AnalysisError("unsupported_format", "Only SIMSCP4 scene captures are supported")
            self.file.seek(0)
            index = _SceneIndex(self, committed_bytes is not None)
            self.format = "SIMSCP4"
            self.metadata = index.metadata
            self.objects = index.objects
            self.samples = index.samples
            self.committed_end = index.committed_end
            self.record_count = sum(len(rows) for rows in self.samples.values())
            integer(self.record_count, "record count")
            if committed_bytes is not None and extent != self.committed_end:
                raise AnalysisError("source_extent", "Extent is not an exact complete-record boundary")
            self.file.read_extent = self.committed_end
            self.file.indexing = False
            self.verify()
            digest_key = ("prefix", str(self.path), *self.stamp, self.committed_end)
            cached_digest = self.memo.get(digest_key) if self.memo is not None else None
            self.sha256 = cached_digest if cached_digest is not None else self._digest()
            if sha256 is not None and self.sha256 != sha256:
                raise AnalysisError("source_changed", "Committed source SHA-256 mismatch")
            if _stamp(self.path, self.raw) != self.stamp:
                raise AnalysisError("source_changed", "Source changed while creating snapshot; retry")
            if self.memo is not None:
                self.memo.put(digest_key, self.sha256)
            self.uuid = self.metadata.get("uuid", self.metadata.get("storage", {}).get("uuid"))
            self.context.verified_source(self.path,self.stamp,(self.sha256,self.committed_end))
            self.audit_coverage = {}
        except MetadataCapacityError as exc:
            self.close()
            raise AnalysisError("memory_limit", str(exc)) from exc
        except Exception:
            self.close()
            raise

    def _acquire_metadata(self, amount):
        try:
            self.context.acquire(amount)
        except AnalysisError as exc:
            if exc.code != "memory_limit":raise
            raise AnalysisError("memory_limit", "Reader metadata exceeds the available job memory_bytes budget; capture validity is unchanged") from exc

    def _digest(self):
        position = self.file.tell()
        h = hashlib.sha256()
        self.file.seek(0)
        try:
            while self.file.tell() < self.file.read_extent:
                h.update(self.file.read(min(MIB, self.file.read_extent-self.file.tell())))
                self.context.progress("source_hash", self.file.tell(), self.file.read_extent)
        finally:
            self.file.seek(min(position, self.file.read_extent))
        return h.hexdigest()

    def verify(self):
        self.context.check()
        current = _stamp(self.path, self.raw)
        if current == self.stamp:
            if self.sha256 is not None:self.context.verified_source(self.path,current,(self.sha256,self.committed_end))
            return
        if (self.sha256 is None or current[:2] != self.stamp[:2] or
                current[2] <= self.stamp[2] or self._digest() != self.sha256 or
                _stamp(self.path, self.raw) != current):
            raise AnalysisError("source_changed", "Source replaced, truncated or changed during analysis")
        self.stamp = current
        self.context.verified_source(self.path,current,(self.sha256,self.committed_end))

    def identity(self):
        return dict(path=str(self.path), format=self.format, uuid=self.uuid,
                    committed_bytes=str(self.committed_end), sha256=self.sha256,
                    complete_records=self.record_count)

    def member_array(self, reference):
        if self.assets is None:raise AnalysisError("invalid_asset","No owned member asset store for this request")
        from .member_assets import asset_stamp
        path,shape,size=self.assets.path(reference)
        key=(reference["sha256"],tuple(shape))
        if key not in self.member_arrays:
            charge=self.context.acquire(size*4+MIB)
            try:
                before=asset_stamp(path)
                values=self.assets.read(reference,self.context)
                if asset_stamp(path)!=before:raise AnalysisError("invalid_asset","Member asset changed during validation")
                self.member_arrays[key]=values
                self.member_stamps[path]=before
                self.member_charge+=charge
            except Exception:
                self.context.release(charge)
                raise
        self.verify_members()
        return self.member_arrays[key]

    def verify_members(self):
        from .member_assets import asset_stamp
        for path,expected in self.member_stamps.items():
            self.context.check()
            if asset_stamp(path)!=expected:
                raise AnalysisError("invalid_asset","A referenced member asset changed during the request")
            self.context.verified_source(path,expected)

    def _bytes(self, size):
        parts = []
        while size:
            block = self.file.read(min(size, codec.MAX_CHUNK))
            if not block:
                raise AnalysisError("source_changed", "Incomplete source payload")
            parts.append(block)
            size -= len(block)
        return b"".join(parts)

    def read_sample(self, object_id, index, names=None):
        self.verify()
        if object_id not in self.objects:
            raise AnalysisError("unknown_object", "Source object is unavailable")
        rows = self.samples[object_id]
        index = integer(index, "sample index", 0, len(rows)-1)
        record, obj = rows[index], self.objects[object_id]
        specs = {a["name"]: a for a in record["descriptor"]["arrays"]}
        wanted = set(specs) if names is None else set(names)
        if not wanted <= specs.keys():
            raise AnalysisError("missing_channel", "Requested source channel is unavailable")
        # Semantic integrity checks are mandatory even for a scalar-only query.
        wanted |= {n for n in ("particle_id", "vertex_id", "triangles") if n in specs}
        selected = [a for a in specs.values() if a["name"] in wanted]
        total = sum(math.prod(a["shape"])*typed.DTYPES.get(a["dtype"], 8) for a in selected)
        ids_size = sum(math.prod(a["shape"])*8 for a in selected if a["name"] in ("particle_id", "vertex_id"))
        # Result + decode/join/immutable copies + sort/unique scratch + codec chunk.
        estimate = total*3+ids_size*5+9*MIB
        charge = self.context.acquire(estimate)
        arrays, unavailable = {}, []
        try:
            for a in specs.values():
                if a["name"] not in wanted:
                    continue
                if a["dtype"] not in typed.DTYPES or any(p["codec"] not in (0, 1) for p in a["chunks"]):
                    if a.get("required", True):
                        raise AnalysisError("unsupported_channel", "Unsupported required source channel")
                    unavailable.append(a["name"])
                    continue
                pieces = []
                for p in a["chunks"]:
                    self.context.check()
                    self.file.seek(record["offset"]+int(p["offset"]))
                    stored = self._bytes(int(p["stored"]))
                    if typed.sha(stored) != p["stored_sha256"]:
                        raise AnalysisError("corrupt_source", "Stored chunk checksum mismatch")
                    raw = codec.decode(stored, int(p["decoded"]), p["codec"])
                    if typed.sha(raw) != p["raw_sha256"]:
                        raise AnalysisError("corrupt_source", "Decoded chunk checksum mismatch")
                    pieces.append(raw)
                data = b"".join(pieces)
                arrays[a["name"]] = np.frombuffer(data, dtype="<"+a["dtype"]).reshape(a["shape"])
            count = specs.get("position", {}).get("shape", [0])[0]
            for name in ("particle_id", "vertex_id"):
                if name in arrays:
                    typed.validate_ids(arrays[name], count)
            if "triangles" in arrays and arrays["triangles"].size and arrays["triangles"].max() >= count:
                raise AnalysisError("corrupt_source", "Triangle index outside source vertices")
            self.context.decoded_bytes += sum(a.nbytes for a in arrays.values())
            self.verify()
            return Sample(object_id, record, arrays, specs, tuple(unavailable), self.context, charge)
        except Exception:
            self.context.release(charge)
            raise

    def audit_identity(self, object_id, last_index=None):
        obj, rows = self.objects[object_id], self.samples[object_id]
        if obj.get("identity") not in ("persistent_i8", "stable_topology"):
            return dict(status="anonymous", through_index=None, distinct_ids=0)
        end = len(rows)-1 if last_index is None else integer(last_index, "audit endpoint", 0, len(rows)-1)
        self.verify()
        cached = self.audit_coverage.get(object_id)
        cache_key = ("audit",self.sha256,object_id)
        cached = cached or self.memo.get(cache_key)
        if cached and cached["through_index"] >= end:
            return dict(cached)
        name = "particle_id" if obj["kind"] == "particles" else "vertex_id"
        history = typed.IdentityHistory()
        # Existing history validator allocates sorted sets and temporary set ops.
        with self.context.allocation(64*MIB):
            for i in range(end+1):
                self.context.check()
                with self.read_sample(object_id, i, [name]) as sample:
                    ids = sample.arrays[name]
                    _, ordered = typed.validate_ids(ids, len(ids))
                    try:
                        history.advance(ordered)
                    except ValueError as exc:
                        raise AnalysisError("identity_contract_violation", str(exc)) from exc
                self.context.progress("identity_audit", i+1, end+1)
            result = dict(status="verified", through_index=end, distinct_ids=len(history.seen))
        self.verify()
        self.audit_coverage[object_id] = result
        self.memo.put(cache_key,result)
        return dict(result)

    def close(self):
        if not self.closed:
            self.raw.close()
            self.context.release(self.charge)
            self.context.release(self.memo_charge)
            self.memo_charge = 0
            self.member_arrays.clear()
            self.context.release(self.member_charge)
            self.member_charge = 0
            self.samples = {};self.objects = {};self.metadata = {}
            if self.metadata_budget is not None:
                self.metadata_budget.clear()
            self.charge = 0
            self.closed = True

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

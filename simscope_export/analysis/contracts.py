"""Bounded request primitives and exact interchange values for G4."""

from contextlib import contextmanager
import math
import re
import struct
import time
from pathlib import Path

MIB = 1024 * 1024
MAX_CONTROL = MIB
MAX_RECORDS = 1_000_000


class AnalysisError(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


class Cancelled(AnalysisError):
    def __init__(self):
        super().__init__("cancelled", "Analysis request cancelled or superseded")


class SharedBudget:
    def __init__(self,limit=512*MIB):
        self.limit=integer(limit,"shared memory budget",MIB,1024*MIB)
        self.used=0;self.peak=0

    def acquire(self,size):
        if self.used+size>self.limit:raise AnalysisError("memory_limit","Active analysis and interactive query exceed the shared working-memory budget")
        self.used+=size;self.peak=max(self.peak,self.used)

    def release(self,size):
        self.used-=size
        if self.used<0:raise RuntimeError("Shared analysis lease underflow")


def exact_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]{0,18}", value):
        raise AnalysisError("invalid_id", "IDs must be canonical decimal strings")
    result = int(value)
    if result >= 2**63:
        raise AnalysisError("invalid_id", "ID is outside the nonnegative int64 range")
    return result


def integer(value, name, low=0, high=MAX_RECORDS):
    # Godot's JSON parser represents bounded structural integers as doubles.
    # Accept that exact representation only; physical IDs still use exact_id.
    if type(value) is float and math.isfinite(value) and abs(value)<=2**53 and value.is_integer():
        value=int(value)
    if type(value) is not int or not low <= value <= high:
        raise AnalysisError("invalid_request", f"{name} must be an integer in [{low}, {high}]")
    return value


def finite(value, name="value"):
    if type(value) not in (int, float) or not math.isfinite(value):
        raise AnalysisError("invalid_request", f"{name} must be finite")
    return float(value)


def float_token(value):
    """Hex bytes, not JSON's potentially lossy numeric parser, are authoritative."""
    value = float(value)
    return {"text": format(value, ".17g"), "f64_le_hex": struct.pack("<d", value).hex()}


def parse_float_token(value):
    if not isinstance(value, dict) or set(value) != {"text", "f64_le_hex"}:
        raise AnalysisError("invalid_request", "Expected exact float64 token")
    encoded = value["f64_le_hex"]
    if not isinstance(encoded, str) or not re.fullmatch("[a-f0-9]{16}", encoded):
        raise AnalysisError("invalid_request", "Invalid float64 bytes")
    result = struct.unpack("<d", bytes.fromhex(encoded))[0]
    finite(result)
    if value["text"] != format(result, ".17g"):
        raise AnalysisError("invalid_request", "Float text differs from exact bytes")
    return result


def request_float(value, name="value"):
    """Interactive JSON numbers or durable exact tokens; never float32 vectors."""
    return parse_float_token(value) if isinstance(value, dict) else finite(value, name)


def request_vector(value, name="coordinate", length=3):
    if not isinstance(value, list) or len(value) != length:
        raise AnalysisError("invalid_request", f"{name} requires {length} components")
    return [request_float(v, name) for v in value]


class Context:
    """Request-local accounting. Every retained source sample owns a lease.

    The charge covers arrays, decoding copies and a conservative parsed-index
    estimate. It is not a whole-process RSS promise; the worker reports RSS too.
    """

    def __init__(self, *, memory_bytes=512*MIB, wall_seconds=150, cpu_seconds=120,
                 cancelled=None, progress=None, pool=None, checkpoint=None):
        self.limit = integer(memory_bytes, "memory_bytes", MIB, 1024*MIB)
        self.started = time.monotonic()
        self.cpu_started = time.process_time()
        self.wall_seconds = finite(wall_seconds, "wall_seconds")
        self.cpu_seconds = finite(cpu_seconds, "cpu_seconds")
        if not 0 < self.wall_seconds <= 86400 or not 0 < self.cpu_seconds <= 86400:
            raise AnalysisError("invalid_request", "Finite positive deadline up to one day required")
        self.cancelled = cancelled or (lambda: False)
        self.progress = progress or (lambda *args: None)
        self.pool=pool
        self.checkpoint=checkpoint
        self.checkpoint_depth=0
        self.used = 0
        self.peak = 0
        self.decoded_bytes = 0
        self.read_bytes = 0
        self.publication_sources={}
        self.publications=[]
        self.retained_members=[] # Assets admitted by a running recipe import.

    def stage_publication(self,action):
        if len(self.publications)>=8:raise AnalysisError("publication_limit","Too many export publications in one request")
        self.publications.append(action)

    def commit_publications(self):
        self.verify_publication()
        for action in self.publications:action.commit()
        self.publications.clear()

    def abort_publications(self,reason):
        for action in self.publications:action.abort(reason)
        self.publications.clear()

    def verified_source(self,path,stamp,identity=None):
        key=(str(path),identity)
        if key not in self.publication_sources and len(self.publication_sources)>=1024:
            raise AnalysisError("source_limit","Too many scientific input files in one request")
        self.publication_sources[key]=tuple(stamp)

    def verify_publication(self):
        # No computation/checkpoint here: after the last cursor handoff, verify
        # every input's most recently hash-verified stamp immediately before the
        # atomic reply. A changed append can be retried with prefix verification.
        for (path,_identity),expected in self.publication_sources.items():
            try:
                info=Path(path).stat()
                actual=(info.st_dev,info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns)
            except OSError as exc:raise AnalysisError("source_changed","Scientific input disappeared before publication") from exc
            if actual!=expected:raise AnalysisError("source_changed","Scientific input changed after its final verification; retry the pinned request")

    def check(self):
        if self.cancelled():
            raise Cancelled()
        if time.monotonic()-self.started > self.wall_seconds:
            raise AnalysisError("deadline", "Analysis wall deadline exceeded")
        if time.process_time()-self.cpu_started > self.cpu_seconds:
            raise AnalysisError("deadline", "Analysis CPU deadline exceeded")
        if self.checkpoint is not None and not self.checkpoint_depth:self.checkpoint()

    @contextmanager
    def defer_checkpoints(self):
        """Bounded atomic publication/locks still check cancellation/deadlines."""
        self.checkpoint_depth+=1
        try:yield
        finally:self.checkpoint_depth-=1

    def acquire(self, size):
        self.check()
        if type(size) is not int or size < 0 or self.used+size > self.limit:
            raise AnalysisError("memory_limit", "Requested scientific workspace exceeds its memory budget")
        if self.pool is not None:self.pool.acquire(size)
        self.used += size
        self.peak = max(self.peak, self.used)
        return size

    def release(self, size):
        self.used -= size
        if self.pool is not None:self.pool.release(size)
        if self.used < 0:
            raise RuntimeError("Analysis memory lease accounting underflow")

    @contextmanager
    def allocation(self, size):
        self.acquire(size)
        try:
            yield
        finally:
            self.release(size)

    def metrics(self):
        return dict(charged_bytes=self.used, peak_charged_bytes=self.peak,
                    decoded_bytes=self.decoded_bytes, read_bytes=self.read_bytes,
                    seconds=time.monotonic()-self.started,
                    cpu_seconds=time.process_time()-self.cpu_started)

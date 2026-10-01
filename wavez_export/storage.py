"""SIMSCP4 framing, lossless types, checksums and exact identity primitives.

These helpers have no reader/writer dispatch or dependency on retired formats.
The framing structs and validation semantics are unchanged.
"""
import hashlib
import json
import re
import struct
import numpy as np

FRAME = struct.Struct('<4sIQQdIIQ32s')
COMMIT = struct.Struct('<8sQ32s')
MAX_DESC = 4*1024*1024
MAX_IDS = 1_000_000
DTYPES = {'f4':4, 'f8':8, 'u4':4, 'i8':8}

def dumps(value): return json.dumps(value,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()


def sha(data): return hashlib.sha256(data).hexdigest()


def integer(value): return type(value) is int


def decimal(value):
    if not isinstance(value,str) or not re.fullmatch(r'0|[1-9][0-9]{0,18}',value): raise ValueError('Invalid decimal size')
    return int(value)


def validate_ids(ids,count):
    if ids.dtype.kind not in 'iu' or ids.dtype.kind=='b' or ids.shape!=(count,): raise ValueError('ids must be a one-dimensional exact integer array')
    if count>MAX_IDS or (count and (ids.min()<0 or int(ids.max())>2**63-1)): raise ValueError('ID range/lifetime allocation ceiling')
    values=np.ascontiguousarray(ids,dtype='<i8');ordered=np.sort(values)
    if len(ordered)>1 and np.any(ordered[1:]==ordered[:-1]): raise ValueError('Duplicate particle ID')
    return values,ordered


class IdentityHistory:
    def __init__(self): self.seen=np.empty(0,dtype='<i8');self.previous=self.seen
    def advance(self,ordered):
        born=np.setdiff1d(ordered,self.previous,assume_unique=True)
        if len(np.intersect1d(born,self.seen,assume_unique=True)): raise ValueError('Particle ID reused after an absence')
        if len(self.seen)+len(born)>MAX_IDS: raise ValueError('Lifetime ID ceiling exceeded')
        self.seen=np.union1d(self.seen,born);self.previous=ordered

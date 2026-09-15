"""Small worker-owned verification memo; no source arrays or unbounded history."""
from collections import OrderedDict
from copy import deepcopy
import json

from .contracts import MIB,integer


class VerificationMemo:
    def __init__(self,limit=4*MIB):
        self.limit=integer(limit,"verification memo budget",0,16*MIB)
        self.used=0;self.peak=0;self.hits=0;self.evictions=0
        self.entries=OrderedDict()

    def get(self,key):
        if key not in self.entries:return None
        value,_=self.entries[key];self.entries.move_to_end(key);self.hits+=1
        return deepcopy(value)

    def put(self,key,value):
        # Conservative Python object/key/parsed scalar overhead. The payload is
        # a compact epoch/audit description, never scientific arrays or ID sets.
        charge=8*len(json.dumps([key,value],allow_nan=False).encode())+256
        if charge>self.limit:return
        previous=self.entries.pop(key,None)
        if previous:self.used-=previous[1]
        while self.used+charge>self.limit:
            _,(_,size)=self.entries.popitem(last=False);self.used-=size;self.evictions+=1
        self.entries[key]=(deepcopy(value),charge);self.used+=charge
        self.peak=max(self.peak,self.used)

    def nearest_epoch(self,scope,index):
        best=None;best_index=-1
        # At most a few thousand compact entries under the fixed byte budget.
        for key in self.entries:
            if key[:3]==scope and best_index<key[3]<=index:
                best_index=key[3];best=key
        value=self.get(best) if best else None
        return (best_index,value) if value is not None else (-1,None)

    def metrics(self):
        return dict(limit_bytes=self.limit,charged_bytes=self.used,peak_bytes=self.peak,
                    entries=len(self.entries),hits=self.hits,evictions=self.evictions)

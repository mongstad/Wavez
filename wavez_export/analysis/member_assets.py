"""Private content-addressed exact member arrays, separate from source captures."""
import hashlib
import json
from contextlib import contextmanager
import os
from pathlib import Path
import re
import stat
import tempfile

import numpy as np

from .contracts import AnalysisError,MIB,integer

MAX_MEMBERS_BYTES=64*MIB
MAX_ASSETS=512


def process_birth(pid):
    try:return Path(f"/proc/{pid}/stat").read_text().rsplit(")",1)[1].split()[19]
    except (OSError,IndexError):return None


def stamp(info):
    return (info.st_dev,info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns)


def asset_stamp(path):
    try:info=path.lstat()
    except OSError as exc:raise AnalysisError("invalid_asset","A referenced member asset is unavailable") from exc
    if not stat.S_ISREG(info.st_mode):raise AnalysisError("invalid_asset","Member assets must be regular files, not links")
    return stamp(info)


class MemberAssets:
    def __init__(self,root,*,limit=MAX_MEMBERS_BYTES,registry_root=None,global_limit=2*1024*MIB):
        self.root=Path(root).absolute()
        self.limit=integer(limit,"member asset bytes",8,MAX_MEMBERS_BYTES)
        self.root.mkdir(parents=True,exist_ok=True)
        if self.root.is_symlink():raise AnalysisError("invalid_asset","Member asset root cannot be a symlink")
        self.root=self.root.resolve()
        self.registry_root=Path(registry_root).resolve() if registry_root is not None else None
        self.global_limit=integer(global_limit,"member global disk budget",8,2*1024*MIB)
        self.used=0;self.count=0
        for path in self.root.iterdir():
            info=path.lstat()
            if path.name in ("owner.json","owner.json.tmp") and stat.S_ISREG(info.st_mode) and info.st_size<=4096:continue
            if not stat.S_ISREG(info.st_mode) or not re.fullmatch(r"[a-f0-9]{64}\.i8|member-.*\.part",path.name):
                raise AnalysisError("invalid_asset","Unexpected file in private member asset directory")
            self.used+=info.st_size;self.count+=1
            if self.used>self.limit or self.count>MAX_ASSETS:raise AnalysisError("selection_limit","Private member asset quota exceeded")
        if self.used>self.limit or self.count>MAX_ASSETS:raise AnalysisError("selection_limit","Private member asset quota exceeded")

    @contextmanager
    def reserve_disk(self,size,context):
        if self.registry_root is None:
            yield
            return
        # A private quota lock coordinates only asset publication, not commands.
        from .disk_quota import DiskQuota
        with DiskQuota(self.registry_root,limit=self.global_limit).reserve(size,1,context):yield

    def path(self,reference):
        if not isinstance(reference,dict) or set(reference)!={"version","sha256","dtype","shape","bytes"} or reference["version"]!=1 or reference["dtype"]!="i8":
            raise AnalysisError("invalid_asset","Unsupported member asset reference")
        integer(reference["version"],"member asset version",1,1)
        digest=reference["sha256"]
        if not isinstance(digest,str) or not re.fullmatch(r"[a-f0-9]{64}",digest):raise AnalysisError("invalid_asset","Invalid member asset hash")
        shape=reference["shape"]
        if not isinstance(shape,list) or len(shape) not in (1,2):raise AnalysisError("invalid_asset","Invalid member asset shape")
        shape=[integer(v,"member asset dimension",0,10_000_000) for v in shape]
        if len(shape)==2 and shape[1]!=3:raise AnalysisError("invalid_asset","Grid address asset requires xyz triples")
        size=int(np.prod(shape))*8
        if reference["bytes"]!=str(size) or size>self.limit:raise AnalysisError("invalid_asset","Invalid member asset size")
        return self.root/(digest+".i8"),shape,size

    def read(self,reference,context):
        path,shape,size=self.path(reference)
        asset_stamp(path)
        info=path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size!=size:
            raise AnalysisError("invalid_asset","Member asset replaced, missing or truncated")
        with path.open("rb") as file:
            opened=os.fstat(file.fileno())
            if (opened.st_dev,opened.st_ino)!=(info.st_dev,info.st_ino):raise AnalysisError("invalid_asset","Member asset replaced during open")
            blocks=[];digest=hashlib.sha256();remaining=size
            while remaining:
                context.check();block=file.read(min(MIB,remaining))
                if not block:raise AnalysisError("invalid_asset","Truncated member asset")
                blocks.append(block);digest.update(block);remaining-=len(block)
            if digest.hexdigest()!=reference["sha256"] or stamp(path.lstat())!=stamp(info) or stamp(os.fstat(file.fileno()))!=stamp(opened):
                raise AnalysisError("invalid_asset","Member asset changed or checksum differs")
        # Caller owns the retained lease; immutable backing bytes prevent mutation.
        return np.frombuffer(b"".join(blocks),dtype="<i8").reshape(shape)

    def put(self,values,context):
        if not isinstance(values,np.ndarray) or values.dtype.kind not in "iu" or values.ndim not in (1,2) or values.ndim==2 and values.shape[1]!=3 or len(values)>10_000_000:
            raise AnalysisError("invalid_asset","Invalid exact member array")
        size=values.size*8
        if size>self.limit:raise AnalysisError("selection_limit","Exact member array exceeds the packed-byte budget")
        with context.allocation(size*3+MIB):
            if values.size and (values.min()<0 or int(values.max())>2**63-1):raise AnalysisError("invalid_asset","Member values must be nonnegative exact int64")
            array=np.asarray(values,dtype="<i8",order="C")
            context.check();data=array.tobytes();digest=hashlib.sha256(data).hexdigest()
            ref=dict(version=1,sha256=digest,dtype="i8",shape=list(array.shape),bytes=str(size))
            path=self.root/(digest+".i8")
            if path.exists():
                self.read(ref,context) # Existing corrupt assets are not silently repaired.
                return ref
            if size>self.limit-self.used or self.count>=MAX_ASSETS:
                raise AnalysisError("selection_limit","Exact member assets exceed the 64 MiB / 512-file budget")
            with self.reserve_disk(size,context):
                temporary=None
                try:
                    with tempfile.NamedTemporaryFile(dir=self.root,prefix="member-",suffix=".part",delete=False) as file:
                        temporary=Path(file.name)
                        for start in range(0,size,MIB):context.check();file.write(data[start:start+MIB])
                        file.flush();os.fsync(file.fileno())
                    context.check()
                    # Exclusive publication never overwrites an existing file.
                    os.link(temporary,path);self.used+=size;self.count+=1
                finally:
                    if temporary is not None:temporary.unlink(missing_ok=True)
            return ref

    def metrics(self):
        return dict(bytes=self.used,files=self.count,limit_bytes=self.limit)

    def set_owner(self,pid):
        birth=process_birth(pid)
        if birth is None:raise AnalysisError("invalid_asset","Member store owner is not alive")
        owner=dict(version=1,kind="wavez-member-cache",pid=pid,birth=birth)
        temporary=self.root/"owner.json.tmp";temporary.write_text(json.dumps(owner))
        os.replace(temporary,self.root/"owner.json")

    @staticmethod
    def reap_abandoned(registry,context):
        """Bounded cleanup of declared private stores whose exact owner has died.

        Live viewer ownership survives analysis-worker crashes/restarts. Unknown
        files, symlinks and stores without valid ownership are never deleted.
        """
        removed=0;visited=0
        for directory in Path(registry).iterdir():
            context.check();visited+=1
            if visited>8192:raise AnalysisError("disk_limit","Private cache directory count limit")
            root=directory/"members"
            if directory.is_symlink() or not directory.is_dir() or root.is_symlink() or not root.is_dir():continue
            owner=root/"owner.json"
            try:
                if owner.is_symlink() or owner.stat().st_size>4096:continue
                info=json.loads(owner.read_text())
                if set(info)!={"version","kind","pid","birth"} or info["version"]!=1 or info["kind"]!="wavez-member-cache" or type(info["pid"]) is not int or info["pid"]<=0 or not isinstance(info["birth"],str):continue
                if process_birth(info["pid"])==info["birth"]:continue
                # Result ownership follows the same live viewer identity. Keep
                # ownership evidence if unknown result files prevent cleanup.
                results=directory/"results"
                if results.is_symlink():continue
                if results.is_dir():
                    from .result_store import ResultCache
                    ResultCache(results,registry_root=registry).collect([],context)
                    results.rmdir()
                entries=[]
                for path in root.iterdir():
                    context.check()
                    if len(entries)>=MAX_ASSETS+2 or path.is_symlink() or not path.is_file() or not re.fullmatch(r"[a-f0-9]{64}\.i8|member-.*\.part|owner\.json(?:\.tmp)?",path.name):
                        entries=[];break
                    entries.append(path)
                for path in entries:
                    context.check();path.unlink();removed+=1
                if entries:root.rmdir()
            except (OSError,ValueError,TypeError):continue
        return removed

    def collect(self,references,context):
        """Explicit live-state pins; perform file work only on the worker."""
        if not isinstance(references,list) or len(references)>MAX_ASSETS:
            raise AnalysisError("invalid_asset","Member pins exceed the asset limit")
        keep=set()
        for ref in references:
            path,_,_=self.path(ref);asset_stamp(path);keep.add(path.name)
        removed=0
        for path in self.root.iterdir():
            context.check()
            if path.name in ("owner.json","owner.json.tmp"):continue
            if path.name in keep:continue
            size=path.lstat().st_size
            if not re.fullmatch(r"[a-f0-9]{64}\.i8|member-.*\.part",path.name) or not stat.S_ISREG(path.lstat().st_mode):
                raise AnalysisError("invalid_asset","Unexpected member cache entry")
            path.unlink();self.used-=size;self.count-=1;removed+=1
        return removed


def references_in(value):
    """Only content references, never paths or arbitrary deletion instructions."""
    found={}
    def visit(item,depth=0):
        if depth>48:raise AnalysisError("invalid_asset","Member reference nesting limit")
        if isinstance(item,dict):
            if set(item)=={"version","sha256","dtype","shape","bytes"} and item.get("dtype")=="i8":
                if str(item['sha256']) in found and found[str(item['sha256'])]!=item:raise AnalysisError('invalid_asset','Conflicting shapes for one member asset hash')
                found[str(item["sha256"])]=item
            else:
                for v in item.values():visit(v,depth+1)
        elif isinstance(item,list):
            for v in item:visit(v,depth+1)
    visit(value)
    return list(found.values())

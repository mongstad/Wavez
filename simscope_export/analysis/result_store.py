"""Immutable, paged scientific results with transactional bounded publication."""
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import stat
import uuid

from .contracts import AnalysisError,Context,MIB,MAX_CONTROL,integer
from .disk_quota import DiskQuota,GLOBAL_BYTES

CHUNK_BYTES=4*MIB
MAX_ROW_BYTES=16384
DEFAULT_RESULT_BYTES=256*MIB
COLUMNS=("result_id","selection_key","selection_revision","source_key","object","association","entity_id","member_key","source_row","clock","sample_index","sequence","time","time_f64_le_hex","aligned_time","channel","component","statistic","value","value_f64_le_hex","source_dtype","units","time_status","position_status","value_status","reason","support_key")
ID_PATTERN=r"r-[a-f0-9]{32}"
FILE_PATTERN=r"(?:rows|support)-[0-9]{6}\.(?:csv|jsonl)(?:\.part)?|manifest\.json(?:\.part)?|reservation\.json"


def encoded(value):return json.dumps(value,allow_nan=False,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()


def references_in(value):
    """Only internal exact result-reference objects, with bounded traversal."""
    pending=[value];references={};visited=0
    while pending:
        item=pending.pop();visited+=1
        if visited>100_000:raise AnalysisError("control_limit","Result reference graph exceeds its structural bound")
        if isinstance(item,dict):
            if set(item)=={"version","id","manifest_sha256"}:
                if not isinstance(item["id"],str) or not re.fullmatch(ID_PATTERN,item["id"]) or not isinstance(item["manifest_sha256"],str):raise AnalysisError("invalid_result","Malformed dependency reference")
                if item["id"] in references and references[item["id"]]!=item:raise AnalysisError("invalid_result","Conflicting hashes for one result identity")
                references[item["id"]]=item
                if len(references)>64:raise AnalysisError("result_limit","At most 64 pinned scientific results including dependencies")
            else:pending.extend(item.values())
        elif isinstance(item,list):pending.extend(item)
    return list(references.values())


def regular(path):
    try:info=path.lstat()
    except OSError as exc:raise AnalysisError("invalid_result","Result artifact unavailable") from exc
    if not stat.S_ISREG(info.st_mode):raise AnalysisError("invalid_result","Result files cannot be links or special files")
    return (info.st_dev,info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns)


def read_checked(path,digest,maximum,context):
    before=regular(path)
    if before[2]>maximum:raise AnalysisError("invalid_result","Result artifact exceeds size bound")
    with path.open("rb") as file:
        content=file.read(maximum+1)
    context.check()
    if regular(path)!=before or len(content)>maximum or hashlib.sha256(content).hexdigest()!=digest:
        raise AnalysisError("invalid_result","Result artifact changed or checksum differs")
    return content


class ResultCache:
    def __init__(self,root,*,registry_root=None,quota=None):
        self.root=Path(root).absolute()
        if self.root.is_symlink():raise AnalysisError("invalid_result","Result cache cannot be a link")
        self.root.mkdir(parents=True,exist_ok=True);self.root=self.root.resolve()
        self.quota=quota or DiskQuota(registry_root or self.root.parent.parent)
        self.active=set();self.member_cache_key=None;self.member_cache=[]

    def directory(self,reference):
        if not isinstance(reference,dict) or set(reference)!={"version","id","manifest_sha256"}:
            raise AnalysisError("invalid_result","Unsupported result reference")
        integer(reference["version"],"result version",1,1)
        if not isinstance(reference["id"],str) or not re.fullmatch(ID_PATTERN,reference["id"]) or not isinstance(reference["manifest_sha256"],str) or not re.fullmatch(r"[a-f0-9]{64}",reference["manifest_sha256"]):
            raise AnalysisError("invalid_result","Invalid result identity/hash")
        path=self.root/reference["id"]
        if path.is_symlink() or not path.is_dir():raise AnalysisError("invalid_result","Result directory unavailable")
        return path

    def manifest(self,reference,context):
        path=self.directory(reference)
        data=read_checked(path/"manifest.json",reference["manifest_sha256"],MAX_CONTROL,context)
        try:manifest=json.loads(data)
        except ValueError as exc:raise AnalysisError("invalid_result","Invalid result manifest") from exc
        if not isinstance(manifest,dict) or manifest.get("completion")!="complete" or manifest.get("columns")!=list(COLUMNS):
            raise AnalysisError("invalid_result","Incomplete or unsupported scientific result")
        integer(manifest.get("version"),"manifest version",1,1)
        chunks=manifest.get("artifacts")
        if not isinstance(chunks,list) or len(chunks)>1024:raise AnalysisError("invalid_result","Result chunk index exceeds limit")
        offsets={"rows":0,"support":0};names=set()
        for chunk in chunks:
            if not isinstance(chunk,dict) or set(chunk)!={"path","sha256","bytes","kind","first","count"} or chunk["kind"] not in offsets:
                raise AnalysisError("invalid_result","Malformed result chunk descriptor")
            name=chunk["path"]
            if not isinstance(name,str) or not re.fullmatch(r"(?:rows|support)-[0-9]{6}\.(?:csv|jsonl)",name) or name in names:
                raise AnalysisError("invalid_result","Invalid/duplicate result artifact path")
            names.add(name)
            pattern=r"rows-[0-9]{6}\.csv" if chunk["kind"]=="rows" else r"support-[0-9]{6}\.jsonl"
            if not re.fullmatch(pattern,name):raise AnalysisError("invalid_result","Artifact path and kind differ")
            if not isinstance(chunk["sha256"],str) or not re.fullmatch(r"[a-f0-9]{64}",chunk["sha256"]):raise AnalysisError("invalid_result","Invalid chunk checksum")
            integer(chunk["bytes"],"chunk bytes",0,CHUNK_BYTES)
            first=integer(chunk["first"],"chunk offset",0,100_000_000);count=integer(chunk["count"],"chunk rows",1,100_000_000)
            if first!=offsets[chunk["kind"]]:raise AnalysisError("invalid_result","Noncontiguous result chunk index")
            offsets[chunk["kind"]]+=count
        if offsets["rows"]!=integer(manifest.get("row_count"),"result rows",0,100_000_000) or offsets["support"]!=integer(manifest.get("support_count"),"result support",0,100_000_000):
            raise AnalysisError("invalid_result","Result counts differ from chunk index")
        return manifest

    def begin(self,manifest,*,expected_rows,expected_support=0,byte_limit=DEFAULT_RESULT_BYTES,context=None):
        return ResultWriter(self,manifest,expected_rows,expected_support,byte_limit,context or Context())

    def page(self,reference,*,offset=0,limit=128,kind="rows",context=None):
        context=context or Context()
        with context.allocation(64*MIB):
            manifest=self.manifest(reference,context);directory=self.directory(reference)
            if kind not in ("rows","support"):raise AnalysisError("invalid_result","Unknown result page kind")
            total=manifest["row_count" if kind=="rows" else "support_count"]
            offset=integer(offset,"page offset",0,total);limit=integer(limit,"page limit",1,128)
            rows=[];size=0
            for chunk in manifest["artifacts"]:
                if chunk["kind"]!=kind or chunk["first"]+chunk["count"]<=offset:continue
                context.check();content=read_checked(directory/chunk["path"],chunk["sha256"],CHUNK_BYTES,context)
                if len(content)!=chunk["bytes"]:raise AnalysisError("invalid_result","Chunk byte count differs")
                text=content.decode("utf-8")
                if kind=="rows":
                    reader=csv.reader(io.StringIO(text,newline=""));header=next(reader,None)
                    if header!=list(COLUMNS):raise AnalysisError("invalid_result","Result columns differ")
                else:reader=(json.loads(line) for line in io.StringIO(text) if line.strip())
                observed=0;byte_page_full=False
                for i,row in enumerate(reader):
                    if i%128==0:context.check()
                    observed+=1
                    if kind=="rows" and len(row)!=len(COLUMNS):raise AnalysisError("invalid_result","Malformed numerical result row")
                    if chunk["first"]+i<offset or len(rows)>=limit:continue
                    value=dict(zip(COLUMNS,row)) if kind=="rows" else row
                    entry_size=len(encoded(value))
                    if size+entry_size>MAX_CONTROL//2:byte_page_full=True;break
                    rows.append(value);size+=entry_size
                # Entire bytes are already hash-checked, so pagination can end
                # inside a chunk without reading additional chunks or rows.
                if len(rows)>=limit or byte_page_full or size>MAX_CONTROL//2-MAX_ROW_BYTES:break
                if observed!=chunk["count"]:raise AnalysisError("invalid_result","Chunk row count differs")
            return dict(rows=rows,offset=offset,next_offset=offset+len(rows),total=total,complete=offset+len(rows)==total,
                        result=reference,kind=kind,source_verification="historical immutable result; no new capture evaluation")

    def rows(self,reference,context):
        """Sequential full-result iterator; one checked chunk, no full table."""
        with context.allocation(64*MIB):
            manifest=self.manifest(reference,context);directory=self.directory(reference)
            for chunk in manifest["artifacts"]:
                if chunk["kind"]!="rows":continue
                content=read_checked(directory/chunk["path"],chunk["sha256"],CHUNK_BYTES,context)
                reader=csv.reader(io.StringIO(content.decode("utf-8"),newline=""))
                if next(reader,None)!=list(COLUMNS):raise AnalysisError("invalid_result","Result columns differ")
                count=0
                for values in reader:
                    if count%128==0:context.check()
                    if len(values)!=len(COLUMNS):raise AnalysisError("invalid_result","Malformed numerical row")
                    yield chunk["first"]+count,dict(zip(COLUMNS,values))
                    count+=1
                if count!=chunk["count"]:raise AnalysisError("invalid_result","Result row count differs")

    def dependencies(self,references,context):
        if not isinstance(references,list) or len(references)>64:raise AnalysisError("invalid_result","Result pins must be a bounded list")
        keep={}
        pending=list(references)
        while pending:
            ref=pending.pop();self.directory(ref)
            if ref["id"] in keep:
                if keep[ref["id"]]!=ref:raise AnalysisError("invalid_result","Conflicting hashes for one result identity")
                continue
            keep[ref["id"]]=ref
            if len(keep)>64:raise AnalysisError("result_limit","Result dependency pins exceed 64 results")
            with context.allocation(16*MIB):
                manifest=self.manifest(ref,context)
                pending.extend(references_in(manifest))
                yield ref,manifest
                del manifest

    def member_references(self,references,context):
        from .member_assets import references_in as member_refs
        key=encoded(references)
        if key==self.member_cache_key:return list(self.member_cache)
        found={}
        for _,manifest in self.dependencies(references,context):
            for ref in member_refs(manifest):found[ref["sha256"]]=ref
            if len(found)>512:raise AnalysisError("selection_limit","Result dependency member assets exceed 512")
        self.member_cache_key=key;self.member_cache=list(found.values())
        return list(self.member_cache)

    def collect(self,references,context):
        keep={ref["id"] for ref,_ in self.dependencies(references,context)}
        removed=0
        for path in self.root.iterdir():
            context.check()
            if path.name in keep or path.name in self.active:continue
            if not re.fullmatch(r"(?:\.pending-)?"+ID_PATTERN,path.name) or path.is_symlink() or not path.is_dir():
                raise AnalysisError("invalid_result","Unknown private result entry; refusing cleanup")
            entries=[]
            for entry in path.iterdir():
                context.check()
                if len(entries)>=1026 or not re.fullmatch(FILE_PATTERN,entry.name) or not stat.S_ISREG(entry.lstat().st_mode):
                    raise AnalysisError("invalid_result","Unknown files in private result; refusing cleanup")
                entries.append(entry)
            for entry in entries:context.check();entry.unlink()
            path.rmdir();removed+=1
        return removed

    def discard(self,reference):
        """Roll back only this request's completed publication, never other pins."""
        context=Context(wall_seconds=10)
        directory=self.directory(reference);manifest=self.manifest(reference,context)
        names={"manifest.json"}|{a["path"] for a in manifest["artifacts"]}
        entries=list(directory.iterdir())
        if len(entries)>1025 or any(p.name not in names or not stat.S_ISREG(p.lstat().st_mode) for p in entries):
            raise AnalysisError("invalid_result","Unknown result files; refusing rollback")
        for path in entries:path.unlink()
        directory.rmdir()


class ResultWriter:
    def __init__(self,cache,base,expected_rows,expected_support,limit,context):
        self.cache=cache;self.context=context;self.base=dict(base)
        self.limit=integer(limit,"result disk bytes",MIB,GLOBAL_BYTES)
        self.expected_rows=integer(expected_rows,"expected result rows",0,100_000_000)
        self.expected_support=integer(expected_support,"expected support records",0,100_000_000)
        estimate=(expected_rows+expected_support)*512+MAX_CONTROL
        if estimate>self.limit:raise AnalysisError("result_limit","Estimated full result exceeds the requested disk budget")
        self.id="r-"+uuid.uuid4().hex;self.directory=cache.root/(".pending-"+self.id)
        self.streams={};self.artifacts=[];self.counts={"rows":0,"support":0};self.bytes=0;self.closed=False
        self.charge=context.acquire(2*MAX_ROW_BYTES+2*MIB)
        try:
            files=math.ceil(self.limit/(CHUNK_BYTES-MAX_ROW_BYTES))+6
            with cache.quota.reserve(self.limit,files,context):
                self.directory.mkdir()
                (self.directory/"reservation.json").write_bytes(encoded(dict(bytes=self.limit,files=files)))
                cache.active.add(self.directory.name)
        except Exception:
            self.abort();raise

    def __enter__(self):return self

    def __exit__(self,typ,value,traceback):
        if not self.closed:self.abort()

    def _open(self,kind):
        index=len([v for v in self.artifacts if v["kind"]==kind]);suffix="csv" if kind=="rows" else "jsonl"
        name=f"{kind}-{index:06d}.{suffix}"
        file=(self.directory/(name+".part")).open("xb")
        stream=dict(file=file,path=name,sha256=hashlib.sha256(),bytes=0,count=0,first=self.counts[kind],kind=kind)
        self.streams[kind]=stream
        if kind=="rows":
            text=io.StringIO(newline="");csv.writer(text,lineterminator="\n").writerow(COLUMNS);self._write(stream,text.getvalue().encode())
        return stream

    def _write(self,stream,data):
        if self.bytes+len(data)+MAX_CONTROL>self.limit:raise AnalysisError("result_limit","Full result reached its reserved disk quota; no partial result published")
        self.context.check();stream["file"].write(data);stream["sha256"].update(data);stream["bytes"]+=len(data);self.bytes+=len(data)

    def _close(self,kind):
        stream=self.streams[kind]
        stream["file"].flush();os.fsync(stream["file"].fileno());stream["file"].close()
        os.replace(self.directory/(stream["path"]+".part"),self.directory/stream["path"])
        self.artifacts.append({k:stream[k] for k in ("path","bytes","kind","first","count")}|dict(sha256=stream["sha256"].hexdigest()))
        self.streams.pop(kind)

    def append(self,row,*,kind="rows"):
        if self.closed or kind not in self.counts:raise AnalysisError("invalid_result","Closed result or unsupported stream")
        if kind=="rows":
            if not isinstance(row,dict) or set(row)-set(COLUMNS):raise AnalysisError("invalid_result","Unknown numerical row fields")
            values=[row.get(k,"") for k in COLUMNS]
            if any(not isinstance(v,str) for v in values):raise AnalysisError("invalid_result","Numerical interchange fields must be exact text")
            text=io.StringIO(newline="");csv.writer(text,lineterminator="\n").writerow(values);data=text.getvalue().encode()
        else:data=encoded(row)+b"\n"
        if len(data)>MAX_ROW_BYTES:raise AnalysisError("result_limit","Scientific row/support exceeds its byte limit")
        stream=self.streams.get(kind)
        if stream is not None and stream["bytes"]+len(data)>CHUNK_BYTES:self._close(kind);stream=None
        if stream is None:stream=self._open(kind)
        self._write(stream,data);stream["count"]+=1;self.counts[kind]+=1

    def finish(self):
        self.context.check()
        for kind in list(self.streams):self._close(kind)
        manifest=self.base|dict(version=1,completion="complete",columns=list(COLUMNS),row_count=self.counts["rows"],support_count=self.counts["support"],
                                artifacts=sorted(self.artifacts,key=lambda a:(a["kind"],a["first"])),output_admission=dict(expected_rows=self.expected_rows,expected_support=self.expected_support,reserved_bytes=self.limit))
        data=encoded(manifest)
        if len(data)>MAX_CONTROL or self.bytes+len(data)>self.limit:raise AnalysisError("result_limit","Result manifest exceeds its reserved limit")
        path=self.directory/"manifest.json"
        with path.open("xb") as file:file.write(data);file.flush();os.fsync(file.fileno())
        self.context.check()
        (self.directory/"reservation.json").unlink()
        os.rename(self.directory,self.cache.root/self.id)
        self.cache.active.discard(self.directory.name)
        self.closed=True;self.context.release(self.charge);self.charge=0
        return dict(version=1,id=self.id,manifest_sha256=hashlib.sha256(data).hexdigest())

    def abort(self):
        names={"reservation.json","manifest.json","manifest.json.part"}
        names.update(a["path"] for a in self.artifacts)
        for stream in self.streams.values():
            names.update([stream["path"],stream["path"]+".part"])
            try:stream["file"].close()
            except OSError:pass
        self.streams.clear()
        # Only names created by this writer, bounded by its chunk index.
        try:
            for name in names:
                path=self.directory/name
                if path.is_file() and not path.is_symlink():path.unlink()
            if self.directory.is_dir():self.directory.rmdir()
        except OSError:pass # An inaccessible staging file is never a complete result.
        finally:
            self.cache.active.discard(self.directory.name)
            self.closed=True
            if self.charge:self.context.release(self.charge);self.charge=0

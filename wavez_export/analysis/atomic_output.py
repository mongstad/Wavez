"""Job-owned, bounded filesystem output with no-replace atomic publication."""
import ctypes,errno,hashlib,json,os,shutil,stat,sys,uuid
from pathlib import Path
from .contracts import AnalysisError,MIB,integer
from .result_store import encoded,regular


def no_replace(source,destination):
    if sys.platform.startswith('linux'):
        libc=ctypes.CDLL(None,use_errno=True)
        function=getattr(libc,'renameat2',None)
        if function is None:raise AnalysisError('atomic_publish','Runtime lacks atomic no-replace directory publication')
        function.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint];function.restype=ctypes.c_int
        if function(-100,os.fsencode(source),-100,os.fsencode(destination),1):
            error=ctypes.get_errno();raise AnalysisError('output_exists' if error==errno.EEXIST else 'atomic_publish',os.strerror(error))
    elif os.name=='nt':os.rename(source,destination) # Windows rename refuses an existing destination.
    else:raise AnalysisError('atomic_publish','Atomic no-replace directory publication is not available on this platform')


class Output:
    def __init__(self,destination,quota,context):
        if not isinstance(destination,str) or len(destination)>4096 or not Path(destination).is_absolute():raise AnalysisError('invalid_output','Select an absolute new export directory')
        target=Path(destination);parent=target.parent.resolve(strict=True)
        if not parent.is_dir() or target.name in ('','.','..'):raise AnalysisError('invalid_output','Export parent must be an existing directory')
        self.target=parent/target.name
        if os.path.lexists(self.target):raise AnalysisError('output_exists','Export destination already exists; choose a new directory')
        self.limit=integer(quota,'declared export bytes',MIB,64*1024*MIB);self.context=context
        if shutil.disk_usage(parent).free<self.limit+256*MIB:raise AnalysisError('disk_limit','Export admission preserves 256 MiB free headroom')
        self.stage=parent/('.'+target.name+'.partial-'+uuid.uuid4().hex);self.stage.mkdir()
        self.used=0;self.artifacts=[];self.committed=False
        self.status('in_progress');context.stage_publication(self)

    def status(self,state,reason=None):
        payload=encoded(dict(kind='wavez-export-staging',version=1,completion=state,destination=str(self.target),reason=reason))
        path=self.stage/'status.json';temporary=self.stage/'status.json.tmp'
        with temporary.open('wb') as file:file.write(payload);file.flush();os.fsync(file.fileno())
        os.replace(temporary,path)

    def path(self,name):
        path=Path(name)
        if path.is_absolute() or '..' in path.parts or not path.parts:raise AnalysisError('invalid_output','Unsafe export-relative path')
        destination=self.stage/path
        destination.parent.mkdir(parents=True,exist_ok=True)
        if any(p.is_symlink() for p in [destination,*destination.parents] if p!=self.stage.parent):raise AnalysisError('invalid_output','Linked export staging refused')
        return destination

    def write(self,name,blocks):
        if len(self.artifacts)>=1024:raise AnalysisError('export_limit','Export file count exceeds 1024')
        destination=self.path(name);digest=hashlib.sha256();size=0
        with destination.open('xb') as file:
            for block in blocks:
                self.context.check()
                if not isinstance(block,bytes) or len(block)>4*MIB:raise AnalysisError('export_limit','Export blocks must be bounded bytes')
                if self.used+len(block)>self.limit:raise AnalysisError('export_limit','Full export exceeds declared quota; no scientific rows dropped')
                file.write(block);digest.update(block);size+=len(block);self.used+=len(block)
            file.flush();os.fsync(file.fileno())
        artifact=dict(path=name,bytes=str(size),sha256=digest.hexdigest());self.artifacts.append(artifact)
        return artifact

    def copy(self,name,path,expected,maximum):
        before=regular(path)
        if before[2]>maximum:raise AnalysisError('invalid_asset','Export input exceeds its declared bound')
        def blocks():
            with Path(path).open('rb') as file:
                if tuple((os.fstat(file.fileno()).st_dev,os.fstat(file.fileno()).st_ino))!=before[:2]:raise AnalysisError('source_changed','Export input replaced during open')
                while block:=file.read(MIB):self.context.read_bytes+=len(block);yield block
        artifact=self.write(name,blocks())
        if artifact['sha256']!=expected or regular(path)!=before:raise AnalysisError('source_changed','Export input changed or hash differs')
        self.context.verified_source(path,before)
        return artifact

    def commit(self):
        # Context performed its final cancellation/source checks before this
        # bounded publication. No foreground service occurs between these steps.
        self.status('ready_to_publish')
        no_replace(self.stage,self.target);self.committed=True
        (self.target/'status.json').unlink()
        directory=os.open(self.target.parent,os.O_RDONLY)
        try:os.fsync(directory)
        finally:os.close(directory)

    def abort(self,reason):
        if not self.committed and self.stage.is_dir():self.status('failed',str(reason)[:2048])

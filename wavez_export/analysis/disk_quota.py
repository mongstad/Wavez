"""One private G4 disk ceiling shared by members and streamed numerical results."""
from contextlib import contextmanager
import fcntl
import json
from pathlib import Path
import shutil
import stat
import time

from .contracts import AnalysisError,MIB,integer

GLOBAL_BYTES=2*1024*MIB
GLOBAL_FILES=8192


class DiskQuota:
    def __init__(self,root,*,limit=GLOBAL_BYTES,file_limit=GLOBAL_FILES,free_reserve=256*MIB):
        self.root=Path(root).resolve();self.root.mkdir(parents=True,exist_ok=True)
        self.limit=integer(limit,"G4 disk quota",8,GLOBAL_BYTES)
        self.file_limit=integer(file_limit,"G4 file quota",1,GLOBAL_FILES)
        self.free_reserve=integer(free_reserve,"free disk reserve",0,GLOBAL_BYTES)

    def usage(self,context):
        used=files=directories=0

        def charge(path):
            info=path.lstat()
            if not stat.S_ISREG(info.st_mode):raise AnalysisError("disk_limit","Unexpected link or non-file in private G4 cache")
            return max(4096,info.st_size)

        for owner in self.root.iterdir():
            context.check();directories+=1
            if directories>GLOBAL_FILES:raise AnalysisError("disk_limit","Too many private cache directories")
            if not owner.is_dir() or owner.is_symlink():continue
            member_root=owner/"members"
            if member_root.is_symlink():raise AnalysisError("disk_limit","Linked member cache refused")
            if member_root.is_dir():
                for path in member_root.iterdir():
                    context.check();used+=charge(path);files+=1
                    if files>self.file_limit:raise AnalysisError("disk_limit","Private G4 file quota exceeded")
            results=owner/"results"
            if results.is_symlink():raise AnalysisError("disk_limit","Linked result cache refused")
            if not results.is_dir():continue
            for result in results.iterdir():
                context.check();directories+=1
                if directories>GLOBAL_FILES:raise AnalysisError("disk_limit","Too many private result directories")
                if result.is_symlink() or not result.is_dir():raise AnalysisError("disk_limit","Unexpected entry in private results")
                actual=entries=0;reservation={}
                for path in result.iterdir():
                    context.check();actual+=charge(path);entries+=1
                    if entries+files>self.file_limit:raise AnalysisError("disk_limit","Private G4 file quota exceeded")
                    if path.name=="reservation.json":
                        if path.stat().st_size>4096:raise AnalysisError("disk_limit","Invalid result reservation")
                        try:reservation=json.loads(path.read_text())
                        except (ValueError,OSError) as exc:raise AnalysisError("disk_limit","Unreadable result reservation") from exc
                used+=max(actual,integer(reservation.get("bytes",0),"reserved result bytes",0,GLOBAL_BYTES))
                files+=max(entries,integer(reservation.get("files",0),"reserved result files",0,GLOBAL_FILES))
                if files>self.file_limit:raise AnalysisError("disk_limit","Private G4 file quota exceeded")
        return dict(bytes=used,files=files)

    @contextmanager
    def reserve(self,size,files,context):
        """Caller publishes its reservation/files before releasing this lock."""
        with (self.root/".g4-quota.lock").open("a+b") as lock:
            while True:
                context.check()
                try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);break
                except BlockingIOError:time.sleep(.01)
            # A foreground asset publication must not recursively acquire this
            # same process lock. Cancellation remains enabled while held.
            with context.defer_checkpoints():
                try:
                    usage=self.usage(context)
                    if usage["bytes"]+max(size,4096*files)>self.limit or usage["files"]+files>self.file_limit:
                        raise AnalysisError("disk_limit","Shared G4 disk budget or file-count limit exceeded")
                    if shutil.disk_usage(self.root).free<size+self.free_reserve:
                        raise AnalysisError("disk_limit","Result admission preserves free disk headroom")
                    yield usage
                finally:fcntl.flock(lock,fcntl.LOCK_UN)

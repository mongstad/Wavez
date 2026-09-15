"""Deterministic test-only pause at an identity-audit progress boundary."""
import sys
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.analyze_selection import Worker, write_json


class PausedWorker(Worker):
    def background_progress(self,stage,completed,total):
        super().background_progress(stage,completed,total)
        if self.background_id=="interval" and stage=="native_analysis":
            write_json(self.directory/"background_barrier.json",dict(id=self.background_id,index=completed))
            while not self.background_cancelled() and not (self.directory/"release").exists():
                self.service_foreground()
                time.sleep(.01)

    def progress(self, stage, completed, total):
        super().progress(stage,completed,total)
        if self.current == "slow":
            write_json(self.directory/"barrier.json",{"id":self.current})
            while not self.cancelled() and not (self.directory/"release").exists():
                time.sleep(.01)


PausedWorker(Path(sys.argv[1]),int(sys.argv[2])).run()

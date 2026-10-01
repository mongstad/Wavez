"""Test-only worker with an 8 MiB disposable cache ceiling."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.analyze_selection import Worker
from wavez_export.analysis.disk_quota import DiskQuota
from wavez_export.analysis.contracts import MIB
worker=Worker(Path(sys.argv[1]),int(sys.argv[2]),assets_root=Path(sys.argv[3]))
worker.results.quota=DiskQuota(worker.directory.parent,limit=8*MIB)
worker.run()

#!/usr/bin/env python3
"""Measure the existing verified source path once, then its verified memo hit.

Research only. Reads one existing audited N192 capture; writes compact evidence.
The first run hashes the complete capture (about 7 GB). OS disk-cache state is
uncontrolled; 'first verification' does not mean cold disk. Never starts Wavez.
"""
import argparse
import hashlib
import json
from pathlib import Path
import resource
import sys
import time

import numpy as np

from experiment import REFERENCE_SHA256, REFERENCE_UUID, patch, spectrum
from wavez_export.analysis.contracts import Context, MIB
from wavez_export.analysis.memo import VerificationMemo
from wavez_export.analysis.source import SourceSnapshot


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture",required=True,type=Path)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    if args.output.resolve().is_relative_to(args.capture.resolve().parent):
        raise ValueError("output must be outside the read-only reference run")
    before=args.capture.stat()
    if before.st_size>8_000_000_000:
        raise ValueError("bounded probe accepts the audited N192 reference, not a larger run")
    memo=VerificationMemo()
    runs=[]
    for label in ["first_verification","memo_reopen"]:
        context=Context()
        start=time.perf_counter()
        with SourceSnapshot(args.capture,context=context,memo=memo,sha256=REFERENCE_SHA256) as source:
            open_seconds=time.perf_counter()-start
            if source.uuid!=REFERENCE_UUID or len(source.samples["field"])!=41 or source.samples["field"][0]["descriptor"]["geometry"]["shape"]!=[192,192,192]:
                raise ValueError("not the audited N192 reference")
            initial_read_bytes=context.read_bytes
            start=time.perf_counter()
            with source.read_sample("field",20,names=["amplitude"]) as sample:
                read_seconds=time.perf_counter()-start
                q=sample.arrays["amplitude"]
                # Proposed research reservation; does not change any runtime policy.
                with context.allocation(128*MIB):
                    start=time.perf_counter()
                    region=patch(q,(96,96,96),128,False)
                    s=spectrum(region,source.samples["field"][20]["descriptor"]["geometry"]["spacing"])
                    roi_seconds=time.perf_counter()-start
                    numpy_times=[]
                    for _ in range(5):
                        start=time.perf_counter()
                        nf=np.fft.rfftn(s["residual"])
                        numpy_times.append(time.perf_counter()-start)
                    parity=float(np.max(np.abs(nf-s["f"]))/max(np.max(np.abs(s["f"])),np.finfo(float).tiny))
                    assert parity<1e-12
                    runs.append(dict(label=label,open_seconds=open_seconds,initial_read_bytes=initial_read_bytes,
                        selected_read_seconds=read_seconds,selected_decode_bytes=q.nbytes,
                        roi128_window_fft_power_seconds=roi_seconds,
                        numpy_fft_only_seconds=numpy_times,numpy_scipy_max_relative_difference=parity,
                        source_identity=source.identity(),context=context.metrics(),memo=memo.metrics(),
                        note="128MiB extra logical reservation; not an OS RSS limit or production operation"))
            source.verify()
        assert context.used==0
    after=args.capture.stat()
    unchanged=(before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(
        after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    assert unchanged
    result=dict(script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),runs=runs,
        process_high_water_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        source_stat_unchanged=unchanged,status="PASS",disk_cache_state="uncontrolled, not a cold-disk benchmark",
        scope="Existing SourceSnapshot with real prefix hash and selected payload verification; no UI/GPU/IPC/cancellation test")
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,allow_nan=False)+"\n")
    print(json.dumps(dict(status=result["status"],runs=[{k:r[k] for k in ["label","open_seconds","selected_read_seconds","roi128_window_fft_power_seconds"]} for r in runs])))


if __name__=="__main__":
    main()

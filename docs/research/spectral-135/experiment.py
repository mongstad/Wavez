#!/usr/bin/env python3
"""Bounded #135 research; not imported by Wavez or a production spectral API.

Run from any directory. Synthetic tests need NumPy, SciPy and Matplotlib.
An optional --capture reads only native field samples 0, 20 and 40, with the
existing strict SceneReader and no cache. No input or production file is written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import resource
import sys
import time

import numpy as np
import scipy
from scipy import fft

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
REFERENCE_UUID = "5848557b4ddd4d56b48e62f9f5700b23"
REFERENCE_DESCRIPTORS = "52344da099531d74576f53b035a561c69c435fffd6c4b580bebbc1e6e37bacf0"
REFERENCE_SHA256 = "1af76f2e5e0642808f33119168d8f5e0c7cc847599e414790923c2c3585e3d7d"


def window(shape, kind):
    if kind == "boxcar":
        return np.ones(shape, dtype=np.float64)
    if kind != "hann_periodic":
        raise ValueError("unsupported window")
    axes = [0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / n) for n in shape]
    return axes[0][:, None, None] * axes[1][None, :, None] * axes[2][None, None, :]


def spectrum(q, spacing_xyz=(1., 1., 1.), kind="hann_periodic", demean=True):
    """Power per DFT bin, summing to window-weighted mean-square residual.

    mu=sum(w*q)/sum(w); P=m*abs(F)**2/(N*sum(w*w)), m folds the
    omitted negative-x half. Units q^2, NOT energy or a PSD per unit frequency.
    This returns phase-bearing F for research checks, not a reconstructed field.
    """
    q = np.asarray(q, dtype=np.float64)
    if q.ndim != 3 or min(q.shape) < 2 or not np.isfinite(q).all():
        raise ValueError("finite 3D samples required; no filling/resampling")
    if len(spacing_xyz) != 3 or not np.isfinite(spacing_xyz).all() or min(spacing_xyz) <= 0:
        raise ValueError("positive finite xyz spacing required")
    w = window(q.shape, kind)
    mu = float(np.sum(w * q) / w.sum()) if demean else 0.
    residual = (q - mu) * w
    f = fft.rfftn(residual, workers=1)
    power = np.abs(f) ** 2 / (q.size * np.sum(w * w))
    power[..., 1:-1 if q.shape[-1] % 2 == 0 else None] *= 2
    freq = [fft.fftfreq(n, d) for n, d in zip(q.shape, spacing_xyz[::-1])]
    freq[-1] = fft.rfftfreq(q.shape[-1], spacing_xyz[0])
    expected = float(np.sum(residual * residual) / np.sum(w * w))
    return dict(f=f, power=power, freq=freq, mean=mu, residual=residual,
                expected=expected, parseval_abs_error=abs(float(power.sum())-expected))


def radial(s):
    z, y, x = s["freq"]
    rho = np.sqrt(z[:, None, None]**2+y[None, :, None]**2+x[None, None, :]**2)
    df = min(abs(a[1]-a[0]) for a in s["freq"])
    bins = np.floor(rho/df + 0.5).astype(np.int32)
    shell = np.bincount(bins.ravel(), weights=s["power"].ravel())
    return dict(frequency=(np.arange(len(shell))*df).tolist(), power=shell.tolist(),
                df=float(df), convention="shell sum, nearest radial bin; not shell mean or PSD")


def wave(shape, bins_zyx, phase=0., amplitude=1.):
    z, y, x = np.ogrid[tuple(slice(0, n) for n in shape)]
    arg = z*bins_zyx[0]/shape[0] + y*bins_zyx[1]/shape[1] + x*bins_zyx[2]/shape[2]
    return amplitude*np.cos(2*np.pi*arg+phase)


def patch(q, center, size, periodic):
    if type(size) is not int or size < 2 or size % 2 or size > min(q.shape):
        raise ValueError("research windows must be even and fit each source axis")
    axes = [np.arange(c-size//2, c+size//2) for c in center]
    if not periodic and any(a[0] < 0 or a[-1] >= n for a, n in zip(axes, q.shape)):
        raise ValueError("ROI crosses an undeclared boundary")
    return q[np.ix_(*(a % n for a, n in zip(axes, q.shape)))]


def synthetic():
    cases = []

    def check(name, metric, tolerance, detail):
        cases.append(dict(name=name, metric=float(metric), tolerance=float(tolerance),
                          passed=bool(metric <= tolerance), detail=detail))

    shape = (24, 32, 64)
    q = wave(shape, (3, -4, 8), phase=.37, amplitude=2.)
    s = spectrum(q, (.25, .5, 1.), "boxcar")
    idx = np.unravel_index(np.argmax(s["power"]), s["power"].shape)
    measured = [float(s["freq"][axis][idx[axis]]) for axis in range(3)]
    check("anisotropic_xyz_zyx_wavevector", np.max(np.abs(np.array(measured)-[.125,-.25,.5])),
          1e-14, "expected zyx cycles/unit = [.125,-.25,.5], with signed y")
    check("known_amplitude_power", abs(float(s["power"].sum())-2.), 2e-13,
          "amplitude 2 cosine has mean square 2; folded conjugates counted once")
    check("phase_at_known_bin", abs(np.angle(s["f"][idx])-0.37), 2e-13,
          "complex coefficient preserves initial phase on this fixed-origin bin")
    check("inverse_boxcar", np.max(np.abs(fft.irfftn(s["f"],s=q.shape)+s["mean"]-q)),
          3e-13, "full coefficient inverse reconstructs sampled q, not an underlying continuum")
    rng = np.random.default_rng(135)
    for sh in [(5, 6, 7), (6, 7, 8)]:
        r = rng.normal(size=sh)
        t = spectrum(r)
        check("parseval_odd_even_"+str(sh), t["parseval_abs_error"], 1e-13,
              "odd/even last-axis folding includes Nyquist only once")
        check("inverse_windowed_"+str(sh),
              np.max(np.abs(fft.irfftn(t["f"],s=sh)-t["residual"])), 1e-13,
              "inverse recovers tapered residual only; zero window edges lose information")
    tiny = rng.normal(size=(3, 4, 5))
    matrices = [np.exp(-2j*np.pi*np.outer(np.arange(n),np.arange(n))/n) for n in tiny.shape]
    direct = np.einsum("az,by,cx,zyx->abc", *matrices, tiny)
    check("independent_direct_dft", np.max(np.abs(direct[...,:3]-fft.rfftn(tiny))), 1e-12,
          "explicit exponential-sum oracle, no FFT implementation in the reference")
    q1 = wave((16,16,64), (0,0,8))
    q2 = wave(q1.shape,(0,0,20), amplitude=.5)
    mixed = spectrum(q1+q2,kind="boxcar")
    check("mixed_tone_power_ratio", abs(mixed["power"][0,0,8]/mixed["power"][0,0,20]-4),
          1e-12,"amplitude ratio 2 gives power ratio 4")
    squared = spectrum(q1*q1,kind="boxcar",demean=False)
    check("squared_field_dc", abs(squared["power"][0,0,0]-.25),1e-13,
          "toy q^2 has DC power .25; actual Model A energy has additional terms")
    check("squared_field_double_frequency", abs(squared["power"][0,0,16]-.125),1e-13,
          "q^2 has twice the q frequency and no sign; not an energy-to-q inverse")
    check("opposite_sign_same_power",np.max(np.abs(spectrum(q1,kind="boxcar")["power"]-
          spectrum(-q1,kind="boxcar")["power"])),1e-14,"power cannot identify sign/phase")
    antiphase=wave(q1.shape,(0,0,8),phase=np.pi)
    check("destructive_interference",spectrum(q1+antiphase,kind="boxcar")["power"].sum(),
          1e-25,"opposite-phase waves cancel; adding their separate powers would be wrong")
    quadrature=wave(q1.shape,(0,0,8),phase=np.pi/2)
    check("quadrature_interference",abs(spectrum(q1+quadrature,kind="boxcar")["power"].sum()-1),
          1e-13,"equal waves in quadrature have total mean square1, not constructive value2")
    check("spatial_alias",np.max(np.abs(wave(q1.shape,(0,0,40))-wave(q1.shape,(0,0,24)))),
          1e-12,"mode 40 aliases to 24 on 64 samples; no FFT can undo this")
    times = np.arange(16)*.25
    check("temporal_alias",np.max(np.abs(np.cos(2*np.pi*3*times)-np.cos(2*np.pi*1*times))),
          1e-12,"3 cycles/time aliases to 1 at sample dt=.25; spatial and temporal axes differ")
    travel = wave(q1.shape,(0,0,8),phase=-.6)
    check("travel_snapshot_power",np.max(np.abs(spectrum(q1,kind="boxcar")["power"]-
          spectrum(travel,kind="boxcar")["power"])),1e-13,"traveling wave changes phase, not snapshot power")
    standing = .5*q1
    check("standing_snapshot_power",abs(spectrum(standing,kind="boxcar")["power"].sum()/.5-.25),
          1e-13,"standing wave at amplitude factor .5 has one quarter the power")
    off = wave((8,8,64),(0,0,8.35))
    leakage = {}
    for kind in ["boxcar","hann_periodic"]:
        t = spectrum(off,kind=kind)
        px = t["power"].sum(axis=(0,1))
        leakage[kind] = float((px.sum()-px[6:11].sum())/px.sum())
    check("hann_far_leakage_reduction",leakage["hann_periodic"]/leakage["boxcar"],.05,
          "power outside x bins6..10; Hann reduces distant leakage but broadens the peak")
    left = wave((32,32,64),(0,0,8))
    right = wave(left.shape,(0,0,16))
    piecewise = np.where(np.arange(64)[None,None,:]<32,left,right)
    peaks=[]
    for cx in (16,48):
        t=spectrum(patch(piecewise,(16,16,cx),32,False),kind="hann_periodic")
        peaks.append(int(np.argmax(t["power"].sum(axis=(0,1)))))
    check("localized_regions",np.max(np.abs(np.array(peaks)-[4,8])),0,
          "32-cube regions distinguish wavelengths8 and4; a global spectrum loses location")
    periodic=patch(left,(16,16,0),32,True)
    oracle=wave((32,32,32),(0,0,4),phase=-4*np.pi)
    check("periodic_wrapped_boundary",np.max(np.abs(periodic-oracle)),1e-13,
          "wrap only when source periodicity is independently established")
    rejected=0
    for operation in [lambda:patch(left,(16,16,0),32,False),
                      lambda:spectrum(np.full((4,4,4),np.nan)),
                      lambda:spectrum(np.ones((4,4,4)),(1,0,1)),
                      lambda:patch(left,(16,16,16),5,True),
                      lambda:patch(left,(16,16,16),128,True)]:
        try: operation()
        except ValueError: rejected+=1
    check("unsupported_inputs_refused",abs(rejected-5),0,"undeclared boundary, nonfinite input, zero spacing, odd/oversized window")
    # Two waves with equal |k| but different orientation have the same radial bin.
    radii=[]
    for bins in [(0,0,5),(0,3,4)]:
        t=radial(spectrum(wave((32,32,32),bins),kind="boxcar"))
        radii.append(t["frequency"][int(np.argmax(t["power"]))])
    check("radial_loses_orientation",abs(radii[0]-radii[1]),0,"axis mode5 and diagonal(3,4) share a radial shell")
    return dict(cases=cases,passed=sum(c["passed"] for c in cases),total=len(cases),
                leakage_fraction=leakage,local_peaks_x_bins=peaks)


def benchmark():
    rng=np.random.default_rng(135)
    rows=[]
    for n in [16,32,64,96,128,192]:
        q=rng.normal(size=(n,n,n))
        # Warm inputs and library; no claim of cold-storage or UI latency.
        spectrum(q)
        durations=[]
        for _ in range(5):
            start=time.perf_counter()
            spectrum(q)
            durations.append(time.perf_counter()-start)
        rows.append(dict(n=n,seconds=durations,median_seconds=float(np.median(durations)),
                         input_f64_bytes=q.nbytes,complex_rfft_bytes=n*n*(n//2+1)*16,
                         workers=1,includes="window, mean removal, FFT, power, Parseval; warm RAM"))
    return rows


def model(capture):
    from wavez_export.scene import SceneReader
    before=capture.stat()
    rows=[]
    start=time.perf_counter()
    with SceneReader(capture,strict=True,cache_bytes=0) as reader:
        index_seconds=time.perf_counter()-start
        if "field" not in reader.objects:
            raise ValueError("This bounded reference experiment requires the Model A field object")
        samples=reader.samples["field"]
        if reader.metadata["uuid"]!=REFERENCE_UUID or len(samples)!=41 or any(r["time"]!=i for i,r in enumerate(samples)):
            raise ValueError("Requires the audited N192, 41-sample t0..40 reference; no implicit substitute")
        descriptor_digest=hashlib.sha256(json.dumps([r["descriptor"] for r in samples],sort_keys=True).encode()).hexdigest()
        if descriptor_digest!=REFERENCE_DESCRIPTORS:
            raise ValueError("audited descriptor identity changed; periodicity cannot be assumed")
        for index in [0,20,40]:
            start=time.perf_counter()
            arrays=reader.read_sample("field",index)
            read_seconds=time.perf_counter()-start
            rec=samples[index]
            geometry=rec["descriptor"]["geometry"]
            if geometry["shape"]!=[192,192,192] or not {"amplitude","energy_density","gradient_magnitude"}<=arrays.keys():
                raise ValueError("Reference channels/shape mismatch")
            entry=dict(index=index,time=rec["time"],read_all_three_channels_seconds=read_seconds,
                       read_bytes=sum(a.nbytes for a in arrays.values()),channels={})
            for name in ["amplitude","energy_density"]:
                q=arrays[name]
                start=time.perf_counter()
                s=spectrum(q,geometry["spacing"],"boxcar")
                rr=radial(s)
                global_seconds=time.perf_counter()-start
                inv=fft.irfftn(s["f"],s=q.shape)+s["mean"]
                inverse_error=float(np.max(np.abs(inv-q)))
                power_total=float(s["power"].sum())
                rel=s["parseval_abs_error"]/max(s["expected"],np.finfo(float).tiny)
                channel=dict(array_sha256=hashlib.sha256(memoryview(q).cast("B")).hexdigest(),
                             mean=float(q.mean()),rms=float(np.sqrt(np.mean(q*q))),
                             global_demeaned_power=power_total,parseval_relative_error=rel,
                             inverse_max_abs_error=inverse_error,global_seconds=global_seconds,
                             global_radial=rr,local=[])
                del inv,s
                for size in [32,64,96,128]:
                    for center in [(96,96,96),(48,96,96),(0,96,96)]:
                        start=time.perf_counter()
                        p=patch(q,center,size,True)
                        ss=spectrum(p,geometry["spacing"])
                        channel["local"].append(dict(size=size,center_zyx=list(center),boundary="periodic",
                            mean=ss["mean"],power=float(ss["power"].sum()),
                            parseval_relative_error=ss["parseval_abs_error"]/max(ss["expected"],np.finfo(float).tiny),
                            radial=radial(ss),seconds=time.perf_counter()-start))
                if name=="amplitude":
                    # Coarse 6^3 sampled windows, not a voxel-resolution spectral field.
                    start=time.perf_counter()
                    band=np.zeros((6,6,6)); total=np.zeros_like(band)
                    for iz,z in enumerate(range(16,192,32)):
                        for iy,y in enumerate(range(16,192,32)):
                            for ix,x in enumerate(range(16,192,32)):
                                ss=spectrum(patch(q,(z,y,x),32,False),geometry["spacing"])
                                fz,fy,fx=ss["freq"]
                                r=np.sqrt(fz[:,None,None]**2+fy[None,:,None]**2+fx[None,None,:]**2)
                                band[iz,iy,ix]=ss["power"][(r>=.375)&(r<.75)].sum()
                                total[iz,iy,ix]=ss["power"].sum()
                    channel["coarse_map"]=dict(shape=[6,6,6],window=32,hop=32,
                        centers=list(range(16,192,32)),band_cycles_per_unit=[.375,.75],
                        seconds=time.perf_counter()-start,band_power=band.tolist(),total_power=total.tolist(),
                        meaning="windowed residual q^2 per 32^3 region; leakage-contaminated, not voxel-local energy")
                entry["channels"][name]=channel
            rows.append(entry)
        info=dict(path=str(capture),uuid=reader.metadata["uuid"],size=before.st_size,
                  committed_end=reader.committed_end,index_seconds=index_seconds,
                  descriptor_sha256=descriptor_digest,
                  payload_scope="All three field channels at indices0,20,40 only; no all-record payload audit",
                  full_file_sha256=None,geometry=geometry,records=len(reader.records),samples=rows)
    after=capture.stat()
    info["source_stat_unchanged"]=(before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(
        after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    if not info["source_stat_unchanged"]:
        raise ValueError("source changed during research")
    return info


def plots(result,out):
    os.environ.setdefault("MPLCONFIGDIR",str(out/".mpl-cache"))
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size":10,"axes.spines.top":False,"axes.spines.right":False})
    fig,axes=plt.subplots(1,2,figsize=(10,3.6),layout="constrained")
    q=wave((8,8,64),(0,0,8.35))
    for kind in ["boxcar","hann_periodic"]:
        s=spectrum(q,kind=kind)
        px=s["power"].sum(axis=(0,1))
        axes[0].semilogy(np.arange(len(px)),np.maximum(px/px.sum(),1e-12),label=kind)
    axes[0].set(xlim=(0,20),ylim=(1e-9,1),xlabel="x DFT bin (true mode 8.35)",ylabel="Fraction of power",title="Window tradeoff on a known sinusoid")
    axes[0].legend()
    timings=result["benchmark"]
    axes[1].plot([r["n"] for r in timings],[1e3*r["median_seconds"] for r in timings],"o-")
    axes[1].set(xlabel="Cube side (samples)",ylabel="Warm median compute (ms)",title="One CPU worker; includes window + power")
    fig.savefig(out/"synthetic_and_cost.png",dpi=160)
    plt.close(fig)
    if "model_a" not in result:
        return
    samples=result["model_a"]["samples"]
    fig,axes=plt.subplots(2,3,figsize=(12,7),layout="constrained")
    vmax=max(np.asarray(r["channels"]["amplitude"]["coarse_map"]["band_power"])[3].max() for r in samples)
    for col,row in enumerate(samples):
        ax=axes[0,col]
        for name in ["amplitude","energy_density"]:
            radial_data=row["channels"][name]["global_radial"]
            p=np.array(radial_data["power"])
            ax.semilogy(radial_data["frequency"],np.maximum(p/p.sum(),1e-18),label=name)
        ax.set(xscale="log",xlim=(.03125,3),ylim=(1e-12,1),xlabel="Spatial frequency (cycles / model unit)",ylabel="Fraction of non-DC power",title=f"Global diagnostic at t={row['time']:g}")
        ax.legend()
        band=np.asarray(row["channels"]["amplitude"]["coarse_map"]["band_power"])[3]
        im=axes[1,col].imshow(band,origin="lower",vmin=0,vmax=vmax,cmap="viridis",extent=(0,32,0,32))
        axes[1,col].set(xlabel="x (model coordinate)",ylabel="y (model coordinate)",title=f"Windowed band power at t={row['time']:g}")
        fig.colorbar(im,ax=axes[1,col],label="q² in [0.375, 0.75) cycles/unit")
    fig.suptitle("Model A: channel spectra differ; lower panels sample 32³ regions at z=18.667\nWindow leakage contributes to band power; these are not physical wavelength maps")
    fig.savefig(out/"model_a_spectra.png",dpi=160)
    plt.close(fig)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--capture",type=Path)
    args=parser.parse_args()
    if args.capture and args.output.resolve().is_relative_to(args.capture.resolve().parent):
        raise ValueError("output must be outside the read-only reference run")
    args.output.mkdir(parents=True,exist_ok=True)
    start=time.perf_counter()
    result=dict(schema="wavez-135-research-v1",script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        environment=dict(python=sys.version,numpy=np.__version__,scipy=scipy.__version__,
                         platform=platform.platform(),cpu=platform.processor(),workers=1),
        synthetic=synthetic(),benchmark=benchmark())
    if args.capture:
        result["model_a"]=model(args.capture)
    result["elapsed_seconds_before_plot"]=time.perf_counter()-start
    result["process_high_water_rss_kib_before_plot"]=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    result["status"]="PASS" if result["synthetic"]["passed"]==result["synthetic"]["total"] else "FAIL"
    if "model_a" in result:
        model_checks=[]
        for sample in result["model_a"]["samples"]:
            for name,channel in sample["channels"].items():
                model_checks.append(channel["parseval_relative_error"]<1e-12)
                model_checks.append(channel["inverse_max_abs_error"]<1e-12)
                model_checks.extend(v["parseval_relative_error"]<1e-12 for v in channel["local"])
        result["model_numerical_checks"]=dict(passed=sum(model_checks),total=len(model_checks),
            meaning="discrete transform consistency only; no continuum or physical validation")
        if not all(model_checks): result["status"]="FAIL"
    (args.output/"experiment.json").write_text(json.dumps(result,indent=2,allow_nan=False)+"\n")
    plots(result,args.output)
    print(json.dumps(dict(status=result["status"],synthetic=f"{result['synthetic']['passed']}/{result['synthetic']['total']}",
                          model=result.get("model_numerical_checks"),output=str(args.output),
                          elapsed_seconds=result["elapsed_seconds_before_plot"])))
    return 0 if result["status"]=="PASS" else 1


if __name__=="__main__":
    raise SystemExit(main())

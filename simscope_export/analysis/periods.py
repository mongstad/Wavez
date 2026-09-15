"""Exploratory peak spacing/autocorrelation; no physical event inference."""
import math
import numpy as np

from .contracts import AnalysisError,Context,request_float,integer
from .reductions import compensated
from . import selectors as S

POLICY="g4-observed-peaks-overlap-acf-1"


def parameters(arguments):
    S.keys(arguments,["method","detrend","lag_range","min_separation","prominence","uniform","uniform_tolerance","hold_cadence","relative_spread","min_correlation"],
           ["method","detrend","lag_range","min_separation","prominence"])
    method=arguments["method"];detrend=arguments["detrend"]
    if method not in ("peak_spacing","autocorrelation") or detrend not in ("mean","linear"):raise AnalysisError("invalid_period","Choose peak_spacing/autocorrelation and explicit mean/linear detrending")
    lag=arguments["lag_range"]
    if not isinstance(lag,list) or len(lag)!=2:raise AnalysisError("invalid_period","Choose a positive lag interval")
    low,high=request_float(lag[0]),request_float(lag[1])
    separation=request_float(arguments["min_separation"]);prominence=request_float(arguments["prominence"])
    if not 0<low<high or separation<=0 or prominence<0:raise AnalysisError("invalid_period","Lag/separation must be positive; prominence nonnegative")
    uniform=arguments.get("uniform",False)
    if type(uniform) is not bool:raise AnalysisError("invalid_period","Uniform-sampling declaration must be boolean")
    tolerance=request_float(arguments.get("uniform_tolerance",1e-6));spread=request_float(arguments.get("relative_spread",.15));strength=request_float(arguments.get("min_correlation",.6))
    if not 0<=tolerance<=.01 or not 0<spread<=.5 or not 0<strength<=1:raise AnalysisError("invalid_period","Invalid sampling/spread/correlation thresholds")
    cadence=request_float(arguments["hold_cadence"]) if "hold_cadence" in arguments else None
    if cadence is not None and cadence<=0:raise AnalysisError("invalid_period","Hold-resampling cadence must be positive")
    if method=="autocorrelation" and not uniform and cadence is None:raise AnalysisError("nonuniform_sampling","Autocorrelation requires an explicit uniform declaration or labeled hold resampling")
    return dict(method=method,detrend=detrend,lag_range=[low,high],min_separation=separation,prominence=prominence,uniform=uniform,
                uniform_tolerance=tolerance,hold_cadence=cadence,relative_spread=spread,min_correlation=strength)


def _range_min(tree,size,start,end):
    start+=size;end+=size+1;value=math.inf
    while start<end:
        if start&1:value=min(value,float(tree[start]));start+=1
        if end&1:end-=1;value=min(value,float(tree[end]))
        start//=2;end//=2
    return value


def peaks(times,values,separation,prominence,context):
    """Observed plateau-leading peaks, contour prominence, greedy separation.

    Minima range queries and nearest strictly-higher bounds avoid quadratic
    valley scans. Plateau leading samples are observed times, not fitted events.
    """
    n=len(values)
    candidates=np.flatnonzero((values[1:-1]>values[:-2])&(values[1:-1]>=values[2:]))+1
    if not len(candidates):return np.empty(0,dtype=np.int64),np.empty(0)
    left=np.empty(n,dtype=np.int64);right=np.empty(n,dtype=np.int64);stack=[]
    for indices,bounds,default in ((range(n),left,-1),(range(n-1,-1,-1),right,n)):
        stack.clear()
        for i in indices:
            if i%4096==0:context.check()
            while stack and values[stack[-1]]<=values[i]:stack.pop()
            bounds[i]=stack[-1] if stack else default;stack.append(i)
    size=1<<(n-1).bit_length();tree=np.full(2*size,np.inf);tree[size:size+n]=values
    width=size
    while width>1:
        context.check();tree[width//2:width]=np.minimum(tree[width:2*width:2],tree[width+1:2*width:2]);width//=2
    heights=np.empty(len(candidates))
    for j,i in enumerate(candidates):
        if j%512==0:context.check()
        heights[j]=values[i]-max(_range_min(tree,size,int(left[i])+1,int(i)),_range_min(tree,size,int(i),int(right[i])-1))
    active=heights>=prominence;chosen=[];candidate_times=times[candidates]
    for rank,j in enumerate(np.argsort(-heights,kind="stable")):
        if rank%4096==0:context.check()
        if not active[j]:continue
        context.check();chosen.append(int(j));time=times[candidates[j]]
        # Equal minimum separation is permitted; suppress only closer peaks.
        a=np.searchsorted(candidate_times,time-separation,side="right");b=np.searchsorted(candidate_times,time+separation,side="left")
        active[a:b]=False
    chosen=np.asarray(sorted(chosen),dtype=np.int64)
    return candidates[chosen],heights[chosen]


def normalized_signal(times,values,detrend,context):
    scale=float(np.max(np.abs(values)))
    if scale==0:return np.zeros(len(values)),1.
    values=values/scale;mean=compensated(values,context)/len(values);centered=values-mean
    if detrend=="linear":
        x=(times-times[0])/(times[-1]-times[0]);x-=compensated(x,context)/len(x)
        denominator=compensated(x*x,context)
        if denominator:centered-=x*(compensated(x*centered,context)/denominator)
    return centered,scale


def autocorrelation(values,context):
    """Cosine-normalized overlapping windows, after the declared detrending."""
    n=len(values);size=1<<(2*n-1).bit_length();context.check()
    transform=np.fft.rfft(values,size);raw=np.fft.irfft(transform*np.conjugate(transform),size)[:n]
    energy=np.concatenate(([0.],np.cumsum(values*values,dtype=np.float64)))
    denominator=np.sqrt(np.maximum(0,energy[n-np.arange(n)]*(energy[n]-energy[np.arange(n)])))
    return np.divide(raw,denominator,out=np.zeros(n),where=denominator>0)


def segment(times,values,options,context):
    n=len(times);duration=float(times[-1]-times[0]) if n else 0.
    result=dict(candidate=None,status="refused",reason="insufficient_cycles",samples=n,window_length=duration,method=options["method"],policy=POLICY,
                peak_indices=np.empty(0,dtype=np.int64),peak_prominence=np.empty(0),acf=np.empty(0),lag_times=np.empty(0))
    if n<4 or duration<=0:return result
    centered,scale=normalized_signal(times,values,options["detrend"],context)
    if float(np.ptp(centered))<=64*np.finfo(float).eps:return result|dict(reason="flat_or_unresolved_signal")
    peak_indices,prominence=peaks(times,centered,options["min_separation"],options["prominence"]/scale,context)
    result.update(peak_indices=peak_indices,peak_prominence=prominence*scale,observed_peak_count=len(peak_indices),peak_time_policy="observed plateau-leading source sample; no subsample fit")
    intervals=np.diff(times[peak_indices])
    native_dt=np.diff(times);cadence=float(np.median(native_dt))
    result["sample_resolution"]=cadence
    if len(intervals)<3:return result
    mean=compensated(intervals,context)/len(intervals)
    spread=float(np.std(intervals))/mean;relative_range=float(np.ptp(intervals))/mean
    result.update(peak_interval_mean=mean,peak_interval_spread=float(np.std(intervals)),relative_spread=spread,relative_range=relative_range,observed_cycles=len(intervals))
    if spread>options["relative_spread"] or relative_range>2*options["relative_spread"]:
        return result|dict(reason="irregular_chirped_or_noise_dominated_spacing")
    if not options["lag_range"][0]<=mean<=options["lag_range"][1]:return result|dict(reason="peak_spacing_outside_requested_lags")
    candidate=mean
    if options["method"]=="autocorrelation":
        sampled=centered;sample_times=times;held=0
        if options["hold_cadence"] is not None:
            cadence=options["hold_cadence"];count=int(math.floor(duration/cadence))+1
            if count>1_000_000:raise AnalysisError("memory_limit","Explicit hold-resampling schedule exceeds one million samples")
            sample_times=times[0]+np.arange(count)*cadence;sample_times=sample_times[sample_times<=times[-1]]
            rows=np.searchsorted(times,sample_times,side="right")-1;sampled=centered[rows];held=int(np.count_nonzero(sample_times!=times[rows]))
            result["resampling"]=dict(policy="explicit left hold within this finite segment only",cadence=cadence,held_samples=held,warning="Cadence-induced correlation; original observations unchanged")
            result["resampled_times"]=sample_times;result["resampled_rows"]=rows
        else:
            deviation=float(np.max(np.abs(native_dt/cadence-1)))
            result["maximum_relative_interval_deviation"]=deviation
            if deviation>options["uniform_tolerance"]:return result|dict(reason="nonuniform_sampling")
        acf=autocorrelation(sampled,context);lags=np.arange(len(acf))*cadence
        result.update(acf=acf,lag_times=lags,sample_resolution=cadence)
        possible=np.flatnonzero((acf[1:-1]>acf[:-2])&(acf[1:-1]>=acf[2:]))+1
        possible=possible[(lags[possible]>=options["lag_range"][0])&(lags[possible]<=options["lag_range"][1])&(acf[possible]>=options["min_correlation"])]
        # The first strong autocorrelation peak must agree with observed peak
        # intervals; harmonic maxima alone do not establish a fundamental period.
        if not len(possible):return result|dict(reason="weak_autocorrelation")
        lag=int(possible[0]);candidate=float(lags[lag]);result["correlation_strength"]=float(acf[lag])
        if abs(candidate-mean)>max(cadence,options["relative_spread"]*mean):return result|dict(reason="ambiguous_harmonics_or_spacing")
    if duration<3*candidate:return result|dict(reason="insufficient_cycles")
    return result|dict(candidate=candidate,status="exploratory_candidate",reason=None,interpretation="descriptive estimate, not a physical event or stability claim")


def analyze(times,values,valid=None,breaks=None,*,arguments,context=None):
    context=context or Context();options=parameters(arguments)
    if not isinstance(times,np.ndarray) or not isinstance(values,np.ndarray) or times.ndim!=1 or values.shape!=times.shape:raise AnalysisError("invalid_period","Period input requires matching scalar arrays")
    n=len(times)
    if n>1_000_000:raise AnalysisError("memory_limit","Period workspace exceeds one million observations")
    if not np.isfinite(times).all() or np.any(np.diff(times)<=0):raise AnalysisError("index_only","Period analysis requires an increasing finite native clock")
    with np.errstate(over="ignore"):
        span=float(times[-1]-times[0]) if n else 0.
    if not math.isfinite(span):raise AnalysisError("arithmetic_overflow","Native time span cannot be represented in float64")
    if valid is not None and (not isinstance(valid,np.ndarray) or valid.shape!=times.shape):raise AnalysisError("invalid_period","Invalid finite-support mask")
    if breaks is not None and (not isinstance(breaks,np.ndarray) or breaks.shape!=times.shape):raise AnalysisError("invalid_period","Invalid gap mask")
    # Source arrays belong to caller. Charge FFT/range-min tree/sort/stack copies
    # and a possible explicitly denser resampling schedule before native calls.
    resampled=n
    if n and options["hold_cadence"] is not None:
        resampled=max(n,integer(int((times[-1]-times[0])/options["hold_cadence"])+1,"resampled observations",0,1_000_000))
    with context.allocation(resampled*224+1048576):
        finite=np.isfinite(values) if valid is None else np.isfinite(values)&valid
        cuts=np.zeros(n,dtype=bool) if breaks is None else breaks
        segments=[];start=None
        for i in range(n+1):
            if i%4096==0:context.check()
            boundary=i==n or not finite[i] or cuts[i]
            if boundary and start is not None:
                if len(segments)>=1024:raise AnalysisError("result_limit","More than 1024 finite segments; choose a smaller explicit window")
                item=segment(times[start:i],values[start:i],options,context);item["start_index"]=start;item["end_index"]=i-1;segments.append(item);start=None
            if i<n and finite[i] and start is None:start=i
        return dict(policy=POLICY,options=options,segments=segments,finite_count=int(np.count_nonzero(finite)),missing_count=n-int(np.count_nonzero(finite)),
                    combination="segments remain separate; no interval spans a missing sample or declared gap")

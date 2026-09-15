"""Deterministic scientific reductions, independent of rendering/preview values."""
import math
import re

import numpy as np

from .contracts import AnalysisError,Context

POLICY="g4-neumaier-two-pass-scaled-population-1"
UNWEIGHTED={"count","min","max","sum","mean","stddev"}
WEIGHTED={"sum_weights","weighted_sum","weighted_mean","weighted_stddev","algebraic_weighted_sum"}


class Neumaier:
    def __init__(self):self.total=0.;self.correction=0.

    def add(self,value):
        value=float(value);next_value=self.total+value
        correction=(self.total-next_value)+value if abs(self.total)>=abs(value) else (value-next_value)+self.total
        self.total=next_value;self.correction+=correction
        if not math.isfinite(self.total) or not math.isfinite(self.correction):
            raise AnalysisError("arithmetic_overflow","Compensated float64 reduction overflow")

    def value(self):
        result=self.total+self.correction
        if not math.isfinite(result):raise AnalysisError("arithmetic_overflow","Compensated float64 result overflow")
        return result


def compensated(values,context):
    accumulator=Neumaier()
    for first in range(0,len(values),4096):
        context.check()
        for value in values[first:first+4096]:accumulator.add(value)
    return accumulator.value()


def quantile_parameter(name):
    match=re.fullmatch(r"(weighted_quantile|quantile):(.+)",name)
    if match is None:return None
    try:q=float(match[2])
    except ValueError:raise AnalysisError("invalid_statistic","Quantile requires a finite fraction")
    if not math.isfinite(q) or not 0<=q<=1:raise AnalysisError("invalid_statistic","Quantile fraction must be in [0,1]")
    return match[1],q


def statistics(values,*,metrics=("count","min","max","sum","mean","stddev"),weights=None,semantic="continuous",context=None):
    context=context or Context()
    if not isinstance(values,np.ndarray) or values.ndim!=1 or values.dtype.kind not in "ifu":
        raise AnalysisError("association","Statistics require one numeric source component")
    if not isinstance(metrics,(list,tuple)) or not 1<=len(metrics)<=32 or len(set(metrics))!=len(metrics):
        raise AnalysisError("invalid_statistic","Choose 1–32 unique statistics")
    quantiles={}
    for name in metrics:
        if not isinstance(name,str):raise AnalysisError("invalid_statistic","Statistic names must be text")
        q=quantile_parameter(name)
        if q:quantiles[name]=q
        elif name not in UNWEIGHTED|WEIGHTED:raise AnalysisError("invalid_statistic","Unsupported statistic")
    if semantic not in ("continuous","signed","categorical","phase","identifier"):
        raise AnalysisError("unsupported_semantics","Unknown channel semantics")
    if semantic in ("categorical","phase","identifier") and set(metrics)!={"count"}:
        raise AnalysisError("unsupported_semantics","Phase/categories/identifiers offer raw traces or counts, not linear statistics")
    weighted=any(m in WEIGHTED or m.startswith("weighted_quantile:") for m in metrics)
    if weighted and weights is None:raise AnalysisError("missing_weight","An explicit source/geometric weight is required")
    if weights is not None and (not isinstance(weights,np.ndarray) or weights.ndim!=1 or len(weights)!=len(values) or weights.dtype.kind not in "ifu"):
        raise AnalysisError("association","Weights require the same source association and length")
    # Covers masks, paired copies, sorting indices, sort results, products and
    # scaled deviation temporaries. Inputs belong to the caller's source lease.
    with context.allocation(len(values)*(128 if weighted else 80)+65536):
        valid=np.isfinite(values);x=values[valid]
        support=dict(source_count=len(values),finite_count=len(x),invalid_count=len(values)-len(x),
                     nan_count=int(np.count_nonzero(np.isnan(values))),positive_inf_count=int(np.count_nonzero(np.isposinf(values))),negative_inf_count=int(np.count_nonzero(np.isneginf(values))),
                     reduction=POLICY,quantile_policy="linear (n-1)*q; weighted first cumulative positive weight >= q*sum; q=0/1 endpoints",integer_policy="exact values/extrema and checked signed128 sum; other integer arithmetic float64")
        paired=positive=None;w=xw=None
        if weights is not None:
            finite_w=np.isfinite(weights);paired=valid&finite_w;positive=paired&(weights>0)
            support.update(invalid_weight_count=int(np.count_nonzero(~finite_w)),negative_weight_count=int(np.count_nonzero(finite_w&(weights<0))),
                           zero_weight_count=int(np.count_nonzero(finite_w&(weights==0))),paired_count=int(np.count_nonzero(paired)),positive_weight_count=int(np.count_nonzero(positive)))
            xw=values[positive].astype(np.float64);w=weights[positive].astype(np.float64)
        output={};cache={}

        def sum_x():
            if "sum" not in cache:
                if values.dtype.kind in "iu":
                    total=0
                    for start in range(0,len(x),4096):
                        context.check();total+=sum(int(v) for v in x[start:start+4096])
                        if not -(2**127)<=total<2**127:raise AnalysisError("arithmetic_overflow","Signed128 exact integer sum overflow")
                    cache["sum"]=total
                else:cache["sum"]=compensated(x,context)
            return cache["sum"]

        def weight_sum():
            if "weights" not in cache:cache["weights"]=compensated(w,context)
            return cache["weights"]

        def weighted_sum():
            if "wx" not in cache:
                with np.errstate(over="ignore",invalid="ignore"):product=w*xw
                cache["wx"]=compensated(product,context)
            return cache["wx"]

        for name in metrics:
            context.check()
            try:
                if name=="count":result=len(x)
                elif not len(x):raise AnalysisError("empty_support","No finite values in the selected population")
                elif name in ("min","max"):result=(x.min() if name=="min" else x.max()).item()
                elif name=="sum":result=sum_x()
                elif name=="mean":result=sum_x()/len(x)
                elif name=="stddev":result=population_std(x.astype(np.float64),sum_x()/len(x),context)
                elif name.startswith("quantile:"):
                    if "sorted" not in cache:cache["sorted"]=np.sort(x,kind="stable")
                    ordered=cache["sorted"];at=(len(ordered)-1)*quantiles[name][1];lo=int(math.floor(at));hi=int(math.ceil(at));alpha=at-lo
                    result=ordered[lo].item() if lo==hi else (1-alpha)*float(ordered[lo])+alpha*float(ordered[hi])
                elif name=="algebraic_weighted_sum":
                    if not np.any(paired):raise AnalysisError("empty_support","No finite value/weight pairs")
                    with np.errstate(over="ignore",invalid="ignore"):product=values[paired].astype(np.float64)*weights[paired].astype(np.float64)
                    result=compensated(product,context)
                else:
                    if support["negative_weight_count"]:raise AnalysisError("negative_weights","Negative weights refuse probability-weighted statistics")
                    if not np.any(paired):raise AnalysisError("empty_support","No finite value/weight pairs")
                    total=weight_sum()
                    if name=="sum_weights":result=total
                    elif name=="weighted_sum":result=weighted_sum()
                    elif total<=0:raise AnalysisError("zero_weight","Weighted mean/variance/quantile requires positive total weight")
                    elif name=="weighted_mean":result=weighted_sum()/total
                    elif name=="weighted_stddev":result=population_std(xw,weighted_sum()/total,context,weights=w,total_weight=total)
                    else:
                        if "weight_order" not in cache:cache["weight_order"]=np.argsort(values[positive],kind="stable")
                        order=cache["weight_order"];q=quantiles[name][1];ordered=values[positive][order]
                        if q==0:result=ordered[0].item()
                        elif q==1:result=ordered[-1].item()
                        else:
                            accumulator=Neumaier();result=ordered[-1].item()
                            for i,row in enumerate(order):
                                if i%4096==0:context.check()
                                accumulator.add(w[row])
                                if accumulator.value()>=q*total:result=ordered[i].item();break
                if isinstance(result,float) and not math.isfinite(result):raise AnalysisError("arithmetic_overflow","Result is not representable in float64")
                output[name]=dict(value=result,status="source" if name in ("min","max") else "derived",reason=None,precision="exact_integer" if isinstance(result,int) else "float64")
            except AnalysisError as exc:
                if exc.code in ("cancelled","deadline","memory_limit"):raise
                output[name]=dict(value=None,status="unavailable",reason=exc.code,precision="float64")
        return dict(statistics=output,support=support)


def population_std(values,mean,context,*,weights=None,total_weight=None):
    with np.errstate(over="ignore",invalid="ignore"):delta=values-mean
    scale=float(np.max(np.abs(delta))) if len(delta) else 0.
    if not math.isfinite(scale):raise AnalysisError("arithmetic_overflow","Variance deviation overflow")
    if scale==0:return 0.
    squared=(delta/scale)**2
    if weights is not None:squared*=weights
    variance=compensated(squared,context)/(len(values) if weights is None else total_weight)
    result=math.sqrt(variance)*scale
    if not math.isfinite(result):raise AnalysisError("arithmetic_overflow","Population standard deviation overflow")
    return result

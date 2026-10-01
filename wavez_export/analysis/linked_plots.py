"""Explicitly mapped, separately labeled series sharing display axes only."""
from decimal import Decimal,localcontext
from .contracts import AnalysisError,MAX_CONTROL,MIB,integer,request_float
from .result_store import encoded
from .comparisons import binding
from .plot_preview import preview
from . import selectors as S


def run(cache,arguments,context):
    S.keys(arguments,["bindings","bins"],["bindings"])
    bindings=arguments["bindings"]
    if not isinstance(bindings,list) or not 1<=len(bindings)<=16:raise AnalysisError("plot_limit","Overlay 1–16 explicit series")
    bins=integer(arguments.get("bins",128),"overlay bins per series",1,2048)
    with context.allocation(24*MIB),localcontext() as dc:
        dc.prec=50;plots=[];reference=None;xlow=xhigh=ylow=yhigh=None
        for item in bindings:
            S.keys(item,["label","binding"],["label","binding"])
            if not isinstance(item["label"],str) or not 1<=len(item["label"])<=128:raise AnalysisError("invalid_plot","Each overlaid series needs a label")
            description,_=binding(cache,item["binding"],context,arithmetic=False)
            current=tuple(description[p][k] for p in ("time","value") for k in ("units","reference"))
            if reference is not None and current!=reference:raise AnalysisError("incompatible_units","Shared plot axes require explicit matching unit/reference mappings")
            reference=current;plot=preview(cache,description["result"],description["series"],context,bins=bins)
            if plot["axis"]!="native_time":raise AnalysisError("index_only","Linked physical plots require physical native times")
            ts=Decimal(str(request_float(description["time"]["scale"])));to=Decimal(str(request_float(description["time"]["offset"])))
            vs=Decimal(str(request_float(description["value"]["scale"])));vo=Decimal(str(request_float(description["value"]["offset"])))
            # Envelopes preserve extrema under the declared affine mappings.
            xx=[Decimal(v)*ts-to for v in plot["x_range"]];yy=sorted(Decimal(v)*vs+vo for v in plot["y_range"]) if plot["y_range"] else None
            xlow=xx[0] if xlow is None else min(xlow,xx[0]);xhigh=xx[1] if xhigh is None else max(xhigh,xx[1])
            if yy:ylow=yy[0] if ylow is None else min(ylow,yy[0]);yhigh=yy[1] if yhigh is None else max(yhigh,yy[1])
            plot.update(label=item["label"],mapping=description,units=description["value"]["units"],time_units=description["time"]["units"],mapped_x_range=[str(v) for v in xx])
            for cell in plot["bins"]:
                for key in ("first","last","min","max"):
                    if key in cell:
                        point=cell[key];point[:2]=[str(Decimal(point[0])*ts-to),str(Decimal(point[1])*vs+vo)]
            plots.append(plot)
            if len(encoded(plots))>MAX_CONTROL-16384:raise AnalysisError("control_limit","Overlay preview exceeds control budget; reduce explicit display bins")
        for plot in plots:
            plot["x_range"]=[str(xlow),str(xhigh)];plot["y_range"]=[str(ylow),str(yhigh)] if ylow is not None else None
            for cell in plot["bins"]:
                local_low,local_high=map(Decimal,plot["mapped_x_range"])
                missing_x=local_low+(local_high-local_low)*(Decimal(cell["bin"])+Decimal(".5"))/plot["bin_count"]
                cell["missing_x"]=float((missing_x-xlow)/(xhigh-xlow)) if xhigh>xlow else .5
                for key in ("first","last","min","max"):
                    if key in cell:
                        p=cell[key];p[3:]=[float((Decimal(p[0])-xlow)/(xhigh-xlow)) if xhigh>xlow else .5,float((Decimal(p[1])-ylow)/(yhigh-ylow)) if yhigh>ylow else .5]
        result=dict(plots=plots,policy="display-only affine axes; separate native series, clocks, counts and missing support; no pooled observations")
        if len(encoded(result))>MAX_CONTROL-16384:raise AnalysisError("control_limit","Mapped overlay preview exceeds control budget")
        return result

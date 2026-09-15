"""Explicit analysis declarations; arbitrary unit strings are never converted."""
from .contracts import AnalysisError,integer,request_float
from . import selectors as S

SEMANTICS={"continuous","signed","categorical","phase","identifier"}
QUANTITIES={"unspecified","actual_particle_mass","mass_density","norm","sampling_weight"}
RESERVED={"particle_id":"identifier","vertex_id":"identifier","particle_type":"categorical","phase":"phase"}


def unit(value,name="units"):
    if not isinstance(value,str) or not value or len(value)>128:raise AnalysisError("invalid_units",f"{name} must be explicit text or 'unknown'")
    return value


def position_unit(source,oid,override=None):
    if override is not None:return unit(override,"position unit override")
    if "position_unit" in source.metadata:return unit(source.metadata["position_unit"])
    obj=source.objects[oid]
    return unit(obj["units"]) if obj["kind"] in ("particles","mesh") else "unknown"


def time_unit(source,override=None):
    return unit(override if override is not None else source.metadata.get("time_unit","unknown"),"time unit")


def product_unit(a,b):
    return "unknown" if "unknown" in (a,b) else f"({a})*({b})"


def quotient_unit(a,b):
    return "unknown" if "unknown" in (a,b) else f"({a})/({b})"


def declaration(source,oid,request):
    """Interpret only the documented G4 metadata key; retain override provenance.

    Optional capture metadata: channel_metadata[object_id][channel_name].
    Existing arbitrary metadata remains untouched; unknown descriptive fields in
    that mapping are opaque provenance and never drive calculation.
    """
    S.keys(request,["channel","component","override","coordinates"],["channel"])
    name=request["channel"]
    if not isinstance(name,str) or not name or len(name)>128:raise AnalysisError("invalid_channel","Choose a named source channel")
    component=request.get("component")
    if component not in (None,"magnitude"):
        component=integer(component,"channel component",0,3)
    mapping=source.metadata.get("channel_metadata",{})
    if not isinstance(mapping,dict) or not isinstance(mapping.get(oid,{}),dict):raise AnalysisError("invalid_metadata","Malformed declared channel metadata")
    original=mapping.get(oid,{}).get(name,{})
    if not isinstance(original,dict):raise AnalysisError("invalid_metadata","Chosen channel metadata must be an object")
    override=request.get("override",{})
    S.keys(override,["units","semantic","quantity","physical","basis","position_units"])
    declared={k:original[k] for k in ("units","semantic","quantity","physical","basis") if k in original}
    declared.update(override)
    semantic=declared.get("semantic",RESERVED.get(name,"continuous"))
    if semantic not in SEMANTICS:raise AnalysisError("unsupported_semantics","Unsupported declared channel semantics")
    protected=RESERVED.get(name,original.get("semantic"))
    if protected in ("phase","categorical","identifier") and semantic!=protected:
        raise AnalysisError("unsupported_semantics","G4 cannot reinterpret declared phase/categories/identity as linear values")
    quantity=declared.get("quantity","unspecified")
    if quantity not in QUANTITIES:raise AnalysisError("unsupported_semantics","Unsupported physical quantity declaration")
    units=unit(declared.get("units","unknown"))
    coordinates=request.get("coordinates","data_local")
    if coordinates not in ("viewer_world","data_local"):raise AnalysisError("invalid_channel","Unknown channel coordinate policy")
    if name=="position" and source.objects[oid]["kind"] in ("particles","mesh"):units=position_unit(source,oid,override.get("position_units",override.get("units")))
    elif coordinates!="data_local":raise AnalysisError("unsupported_basis","Only source positions have a defined data-to-world transformation; vector channels keep their supplied basis")
    if component=="magnitude" and semantic in ("phase","categorical","identifier"):
        raise AnalysisError("unsupported_semantics","Magnitude requires a numeric vector, not phase/category/identity")
    physical=declared.get("physical")
    if physical is not None:
        S.keys(physical,["mass_unit","length_unit","scale"],["mass_unit","scale"])
        physical=dict(mass_unit=unit(physical["mass_unit"]),scale=request_float(physical["scale"]))
        if "length_unit" in declared["physical"]:physical["length_unit"]=unit(declared["physical"]["length_unit"])
        if physical["scale"]<=0:raise AnalysisError("invalid_units","Declared physical scale must be positive")
    basis=declared.get("basis","unspecified")
    if not isinstance(basis,str) or len(basis)>128:raise AnalysisError("unsupported_basis","Vector basis must be descriptive text")
    return dict(channel=name,component=component,units=units,semantic=semantic,quantity=quantity,physical=physical,basis=basis,
                coordinates=coordinates,source_metadata=original,override=override,unit_conversion="none unless explicit physical scale requested")


def physical_mass_policy(channel,kind,coordinate_units):
    """Only an explicit physical declaration can label a result as mass."""
    expected="mass_density" if kind=="volume" else "actual_particle_mass" if kind=="particles" else None
    if expected is None or channel["quantity"]!=expected:
        raise AnalysisError("unsupported_physical_sum","Physical mass requires declared actual particle mass or original-grid mass density; tracer density sums are not field mass")
    physical=channel["physical"]
    if physical is None or physical["mass_unit"]=="unknown":
        raise AnalysisError("invalid_units","Physical mass requires an explicit mass unit and source-to-declared-value scale")
    if kind=="volume" and (coordinate_units=="unknown" or physical.get("length_unit")!=coordinate_units):
        raise AnalysisError("invalid_units","Density length unit must match the declared world grid-coordinate unit; no implicit conversion")
    return dict(units=physical["mass_unit"],scale=physical["scale"],quantity=expected,provenance="explicit capture declaration or recorded user override")

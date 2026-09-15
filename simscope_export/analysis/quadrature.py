"""Full-cell source quadrature. No preview grids, fractional clipping or remapping."""
import math
import numpy as np

from .contracts import AnalysisError,Context
from .reductions import Neumaier
from .sampling import world_positions
from . import selectors as S

POLICY="g4-full-cell-center-neumaier-1"
CHUNK=4096


def grid_geometry(values,geometry,obj):
    if values.ndim!=3 or values.dtype.kind not in "ifu":raise AnalysisError("association","Discrete integral requires one original scalar grid")
    shape=tuple(geometry["shape"])
    if values.shape!=shape:raise AnalysisError("association","Source grid shape differs from geometry")
    centering=geometry["centering"]
    if centering not in ("node","cell"):raise AnalysisError("association","Unsupported grid centering")
    cell_shape=tuple(max(0,n-1) for n in shape) if centering=="node" else shape
    affine=np.asarray(obj["data_to_world"],dtype=np.float64).reshape(3,4)
    with np.errstate(over="ignore",invalid="ignore"):measure=float(np.prod(geometry["spacing"])*abs(np.linalg.det(affine[:,:3])))
    if not math.isfinite(measure) or measure<=0:raise AnalysisError("arithmetic_overflow","World cell volume is not finite and positive")
    return cell_shape,measure


def cell_batches(values,geometry,obj,space,context):
    """Shared source quadrature cells; each yielded batch owns bounded scratch."""
    if space not in ("viewer_world","data_local"):raise AnalysisError("invalid_selection","Unknown quadrature coordinate space")
    cell_shape,measure=grid_geometry(values,geometry,obj);count=math.prod(cell_shape)
    centering=geometry["centering"];spacing=np.asarray(geometry["spacing"],dtype=np.float64);origin=np.asarray(geometry["origin"],dtype=np.float64)
    with context.allocation(min(count,CHUNK)*512+65536):
        for first in range(0,count,CHUNK):
            context.check();context.progress("field_quadrature",first,count)
            flat=np.arange(first,min(count,first+CHUNK),dtype=np.int64);z,y,x=np.unravel_index(flat,cell_shape)
            xyz=np.column_stack((x,y,z)).astype(np.float64)
            if centering=="node":xyz+=.5
            with np.errstate(over="ignore",invalid="ignore"):positions=origin+xyz*spacing
            if space=="viewer_world":positions=world_positions(obj,positions)
            if not np.isfinite(positions).all():raise AnalysisError("arithmetic_overflow","Cell center cannot be represented in requested coordinates")
            if centering=="cell":cell_values=values[z,y,x].astype(np.float64);valid=np.isfinite(cell_values)
            else:
                valid=np.ones(len(x),dtype=bool);running=np.zeros(len(x));correction=running.copy()
                for dz in (0,1):
                    for dy in (0,1):
                        for dx in (0,1):
                            corner=values[z+dz,y+dy,x+dx].astype(np.float64)
                            finite=np.isfinite(corner);valid &= finite
                            v=np.where(finite,corner/8,0.);next_value=running+v
                            correction+=np.where(np.abs(running)>=np.abs(v),(running-next_value)+v,(v-next_value)+running)
                            running=next_value
                cell_values=running+correction;valid &= np.isfinite(cell_values)
            yield positions,cell_values,valid,measure,flat


def volume_integral(values,geometry,obj,region,*,space="viewer_world",finite_subtotal=False,context=None):
    context=context or Context();cell_shape,measure=grid_geometry(values,geometry,obj)
    selected=valid_count=0;total=Neumaier()
    for positions,cell_values,valid,_,_ in cell_batches(values,geometry,obj,space,context):
        included=S.inside(positions,region);selected+=int(np.count_nonzero(included));valid=valid&included;valid_count+=int(np.count_nonzero(valid))
        with np.errstate(over="ignore",invalid="ignore"):terms=cell_values[valid]*measure
        for term in terms:total.add(term)
    valid_volume=valid_count*measure;effective_volume=selected*measure
    if not math.isfinite(effective_volume):raise AnalysisError("arithmetic_overflow","Selected cell volume overflows float64")
    invalid=selected-valid_count;reason="empty_support" if selected==0 else "nonfinite_support" if invalid else None
    support=dict(policy=POLICY,centering=geometry["centering"],selected_cells=selected,valid_cells=valid_count,invalid_cells=invalid,
                 cell_volume=measure,effective_volume=effective_volume,valid_volume=valid_volume,full_grid_cells=math.prod(cell_shape),
                 boundary_approximation="whole cells selected by inclusive center; no partial-cell clipping",coordinate_space=space,
                 determinant_applied="absolute, once",node_value="eight-corner compensated mean" if geometry["centering"]=="node" else None)
    result=dict(value=total.value() if reason is None else None,status="derived" if reason is None else "unavailable",reason=reason,support=support)
    if finite_subtotal:result["finite_subtotal"]=dict(value=total.value() if valid_count else None,status="incomplete_support" if invalid and valid_count else "derived" if valid_count else "unavailable",reason="empty_support" if not valid_count else None)
    return result


def face_areas(obj,sample,rows,context):
    """World triangle area, separate from claims about enclosed volume/mass."""
    with context.allocation(min(len(rows),CHUNK)*512+len(rows)*8+65536):
        result=np.empty(len(rows),dtype=np.float64)
        for first in range(0,len(rows),CHUNK):
            context.check();tri=sample.arrays["position"][sample.arrays["triangles"][rows[first:first+CHUNK]]]
            tri=world_positions(obj,tri.reshape(-1,3)).reshape(-1,3,3)
            with np.errstate(over="ignore",invalid="ignore",divide="ignore"):
                cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);scale=np.max(np.abs(cross),axis=1)
                unit=np.divide(cross,scale[:,None],out=np.zeros_like(cross),where=scale[:,None]!=0)
                result[first:first+len(tri)]=scale*.5*np.sqrt(np.sum(unit*unit,axis=1))
        # Caller reserves its retained weight array; scratch is released here.
        return result

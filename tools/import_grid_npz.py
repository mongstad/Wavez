"""Import raw grids using an explicit JSON mapping; no pickle or axis inference."""
import argparse, hashlib, json, sys, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import numpy as np
from simscope_export import SceneCapture
MAX_SOURCE=256*1024**2


def inspect_npz(path):
    total=0
    with zipfile.ZipFile(path) as z:
        if len(z.infolist())>256:raise ValueError('NPZ array count ceiling')
        for info in z.infolist():
            total+=info.file_size
            if total>MAX_SOURCE or not info.filename.endswith('.npy'):raise ValueError('NPZ uncompressed byte ceiling or unknown member')
            with z.open(info) as f:
                version=np.lib.format.read_magic(f)
                if version==(1,0):shape,_,dtype=np.lib.format.read_array_header_1_0(f)
                elif version==(2,0):shape,_,dtype=np.lib.format.read_array_header_2_0(f)
                else:raise ValueError('Unsupported NPY header version')
                if dtype.hasobject or dtype.kind not in 'fciub' or np.prod(shape,dtype=object)*dtype.itemsize>MAX_SOURCE:raise ValueError('Unsafe/oversized NPZ array')


def convert(mapping_path,output,compression='none'):
    mapping_path=Path(mapping_path)
    if mapping_path.stat().st_size>1048576:raise ValueError('Mapping metadata ceiling')
    mapping=json.loads(mapping_path.read_text())
    if mapping.get('version')!=1 or not isinstance(mapping.get('snapshots'),list) or not mapping['snapshots']:raise ValueError('Explicit version 1 snapshot mapping required')
    obj=dict(mapping['object'],id=mapping['object'].get('id','field'),kind='volume')
    provenance=[]
    for snapshot in mapping['snapshots']:
        path=(mapping_path.parent/snapshot['file']).resolve();inspect_npz(path)
        with path.open('rb') as f:h=hashlib.file_digest(f,'sha256').hexdigest()
        provenance.append({'file':str(path),'sha256':h,'time':snapshot['time']})
    with SceneCapture(output,objects=[obj],metadata={'simulation_name':mapping.get('name','Imported raw grid'),'provenance':{'adapter':'explicit-npz-v1','sources':provenance,'mapping':mapping}},compression=compression) as capture:
        for snapshot_index,snapshot in enumerate(mapping['snapshots']):
            path=(mapping_path.parent/snapshot['file']).resolve();fields={};total=0
            with np.load(path,allow_pickle=False) as data:
                for name,spec in mapping['fields'].items():
                    value=data[spec['array']];axes=spec['axes'];derive=spec.get('derive','none')
                    if value.ndim!=3 or sorted(axes)!=['x','y','z']:raise ValueError('Explicit xyz or zyx axis mapping required')
                    value=np.transpose(value,[axes.index(a) for a in 'zyx'])
                    if derive=='real':value=value.real
                    elif derive=='imag':value=value.imag
                    elif derive=='abs2':value=value.real*value.real+value.imag*value.imag
                    elif derive!='none':raise ValueError('Unknown explicit derivation')
                    if value.dtype.kind!='f' or value.dtype.itemsize not in (4,8):raise ValueError('Export real/imaginary channels explicitly for complex grids')
                    total+=value.nbytes
                    if total>MAX_SOURCE:raise ValueError('Mapped sample ceiling')
                    fields[name]=value
                with path.open('rb') as f:current_hash=hashlib.file_digest(f,'sha256').hexdigest()
                if current_hash!=provenance[snapshot_index]['sha256']:raise ValueError('NPZ source changed during import')
                geometry=dict(mapping['geometry']);geometry.update(snapshot.get('geometry',{}))
                capture.add_volume(obj['id'],float(snapshot['time']),fields,**geometry)
    return output


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mapping',type=Path);p.add_argument('output',type=Path);p.add_argument('--compression',choices=['none','zstd'],default='none');a=p.parse_args()
    print(convert(a.mapping,a.output,a.compression))
if __name__=='__main__':main()

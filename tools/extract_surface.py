"""Bounded optional level-set worker. Full source grids, never preview textures."""
import argparse, hashlib, json, math, os, re, resource, sys, time, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import numpy as np
from simscope_export import SceneReader, SceneCapture
ALGORITHM='skimage-lewiner-0.26/source-f32/no-smoothing/no-decimation/v2'
MAX_VERTICES=1_000_000;MAX_TRIANGLES=2_000_000


def digest(path,extent=None):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        left=path.stat().st_size if extent is None else extent
        while left:
            b=f.read(min(left,1048576))
            if not b:raise ValueError('Source shorter than committed extent')
            h.update(b);left-=len(b)
    return h.hexdigest()


def memory():
    # Linux mm high-water mark resets at exec; ru_maxrss may retain the Godot
    # launcher's pre-exec fork peak and overstate the Python worker allocation.
    status=Path('/proc/self/status').read_text()
    return dict(peak_rss_mib=int(re.search(r'^VmHWM:\s+(\d+)',status,re.M)[1])/1024,final_rss_mib=int(re.search(r'^VmRSS:\s+(\d+)',status,re.M)[1])/1024,rusage_peak_including_launcher_mib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024)

def write_json(path,value):
    temp=path.with_suffix('.tmp-'+uuid.uuid4().hex);temp.write_text(json.dumps(value,allow_nan=False));os.replace(temp,path)


def extract(job):
    began=time.perf_counter();source=Path(job['source']);extent=int(job['extent'])
    source_hash=digest(source,extent)
    if source_hash!=job['sha256']:raise ValueError('Source identity changed')
    import skimage
    from skimage.measure import marching_cubes
    if not skimage.__version__.startswith('0.26.'):raise ValueError('This extraction contract requires scikit-image 0.26.x')
    threshold=float(job['threshold'])
    if not math.isfinite(threshold):raise ValueError('Finite threshold required')
    with SceneReader(source,strict=False,cache_bytes=0) as reader:
        obj=reader.objects[job['object']];row=reader.samples[job['object']][int(job['index'])];g=row['descriptor']['geometry']
        if obj['kind']!='volume' or row['end']>extent:raise ValueError('Grid sample outside pinned extent')
        provenance=dict(source_sha256=source_hash,committed_bytes=str(extent),object=obj['id'],channel=job['channel'],source_time=row['time'],geometry=g,data_to_world=obj['data_to_world'],threshold=threshold,algorithm=ALGORITHM,precision='source converted to float32 for Lewiner extraction; storage unchanged',invalid_policy='omit any cell with a nonfinite corner',smoothing=False,decimation=False)
        signature=hashlib.sha256(json.dumps(provenance,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        cache=Path(job['cache']);cache.mkdir(parents=True,exist_ok=True);mesh_path=cache/(signature+'.ssc');meta_path=cache/(signature+'.json')
        if mesh_path.exists() and meta_path.exists():
            try:
                result=json.loads(meta_path.read_text())
                if result['signature']==signature and result['sha256']==digest(mesh_path):
                    with SceneReader(mesh_path,cache_bytes=0) as verified:verified.read_sample('isosurface',0)
                    result.update(memory());return dict(result,cache_hit=True,seconds=time.perf_counter()-began)
            except (ValueError,KeyError,OSError):pass
        original=reader.read_sample(obj['id'],int(job['index']))[job['channel']]
        if original.ndim!=3:raise ValueError('Scalar grid required')
        field=original.astype('f4',copy=True)
        if np.any(np.isfinite(original)&~np.isfinite(field)):raise ValueError('Source exceeds float32 extraction range')
        del original
        valid=np.ones(tuple(n-1 for n in field.shape),dtype=bool);low=np.full(valid.shape,np.inf,dtype='f4');high=np.full(valid.shape,-np.inf,dtype='f4')
        for z in (0,1):
            for y in (0,1):
                for x in (0,1):
                    corner=field[z:z+valid.shape[0],y:y+valid.shape[1],x:x+valid.shape[2]]
                    valid &= np.isfinite(corner);np.minimum(low,corner,out=low);np.maximum(high,corner,out=high)
        crossing=valid & (low<=threshold) & (high>threshold);active=int(np.count_nonzero(crossing))
        # Lewiner ambiguous cases can emit up to 12 triangles plus a center vertex.
        # Conservative worst-case bounds are enforced BEFORE native extraction.
        if active*12>MAX_TRIANGLES or active*13>MAX_VERTICES:raise ValueError('Isosurface preflight vertex/triangle ceiling; choose a less complex source/threshold')
        mask=np.zeros(field.shape,dtype=bool);mask[1:,1:,1:]=valid
        del valid,low,high,crossing
        finite=np.isfinite(field);field[~finite]=0;del finite
        if active:
            vertices,faces,normals,_=marching_cubes(field,level=threshold,spacing=g['spacing'][::-1],method='lewiner',gradient_direction='descent',allow_degenerate=False,mask=mask)
            # Lewiner descent winding in zyx becomes CCW toward lower values in xyz.
            # Sphere normal tests verify this convention after the odd axis permutation.
            vertices=np.ascontiguousarray(vertices[:,::-1]+np.asarray(g['origin']),dtype='f4');faces=np.ascontiguousarray(faces,dtype='u4')
        else:vertices=np.empty((0,3),dtype='f4');faces=np.empty((0,3),dtype='u4')
        if len(vertices)>MAX_VERTICES or len(faces)>MAX_TRIANGLES:raise ValueError('Isosurface output ceiling')
        reader._unchanged()
        temp=cache/(signature+'.tmp-'+uuid.uuid4().hex+'.ssc')
        with SceneCapture(temp,objects=[dict(id='isosurface',kind='mesh',units=obj['units'],identity='none',static=True,data_to_world=obj['data_to_world'])],metadata={'provenance':provenance}) as writer:writer.add_mesh('isosurface',row['time'],vertices,faces)
        os.replace(temp,mesh_path)
        result=dict(signature=signature,path=str(mesh_path),sha256=digest(mesh_path),provenance=provenance,vertices=len(vertices),triangles=len(faces),active_cells=active,cache_hit=False,seconds=time.perf_counter()-began,**memory())
        write_json(meta_path,result);return result


def main():
    p=argparse.ArgumentParser();p.add_argument('--job',type=Path,required=True);a=p.parse_args()
    result_path=a.job.parent/'result.json'
    try:
        if a.job.stat().st_size>1048576:raise ValueError('Job descriptor limit')
        job=json.loads(a.job.read_text())
        resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3));resource.setrlimit(resource.RLIMIT_CPU,(120,120))
        result=extract(job);result.update(ok=True,request=job.get('request'))
    except Exception as e:result=dict(ok=False,error=str(e),request=locals().get('job',{}).get('request'))
    write_json(result_path,result)
    return 0 if result['ok'] else 1
if __name__=='__main__':raise SystemExit(main())

"""WVZ1: independently committed, lossless particle/mesh/grid samples."""
import hashlib,json,math,os,re,struct,tempfile,uuid
from collections import OrderedDict
from pathlib import Path
import numpy as np
from . import codec
from . import storage
from . import field_statistics
from .metadata_budget import MetadataBudget, MetadataCapacityError, DEFAULT_METADATA_BYTES, MAX_READER_RECORDS
MAGIC=b'WVZ1\0\0\0\0'
PREFIX=struct.Struct('<8sII')
FRAME=storage.FRAME
COMMIT=storage.COMMIT
MAX_SAMPLE=256*1024*1024
IDENTITY=[1,0,0,0,0,1,0,0,0,0,1,0]


def affine(value):
    a=np.asarray(value,dtype='f8')
    if a.shape!=(12,) or not np.isfinite(a).all() or abs(np.linalg.det(a.reshape(3,4)[:,:3]))<1e-12: raise ValueError('Invalid affine data_to_world')
    return a.reshape(3,4)


def metadata_valid(meta):
    if not isinstance(meta,dict) or meta.get('version')!=1 or not re.fullmatch('[a-f0-9]{32}',str(meta.get('uuid',''))): raise ValueError('Unsupported scene metadata/version')
    objects=meta.get('objects');names=set()
    if not isinstance(objects,list) or not 1<=len(objects)<=16: raise ValueError('Object table limit')
    for obj in objects:
        if not isinstance(obj,dict) or not re.fullmatch('[a-z][a-z0-9_]*',str(obj.get('id',''))) or obj['id'] in names: raise ValueError('Invalid/duplicate object id')
        names.add(obj['id'])
        if obj.get('kind') not in ('particles','mesh','volume'): raise ValueError('Unsupported required object kind')
        if obj.get('space')!='viewer_world' or not isinstance(obj.get('units'),str) or not isinstance(obj.get('static'),bool): raise ValueError('Object units/space/static required')
        affine(obj.get('data_to_world'))
        if obj['kind']=='particles' and obj.get('identity') not in ('anonymous','persistent_i8'): raise ValueError('Explicit particle identity policy required')
        if obj['kind']=='particles' and obj['data_to_world']!=IDENTITY: raise ValueError('Particle positions must already be viewer_world; transform explicitly in an adapter')
        if obj['kind']=='mesh' and obj.get('identity') not in ('none','stable_topology'): raise ValueError('Mesh vertex identity policy required')
    if sum(o['kind']=='particles' for o in objects)>1: raise ValueError('One particle object supported')


def geometry_valid(obj,g,arrays):
    if not isinstance(g,dict): raise ValueError('Geometry descriptor required')
    specs={a['name']:a for a in arrays}
    if obj['kind']=='volume':
        shape=g.get('shape');spacing=g.get('spacing');origin=g.get('origin')
        if not isinstance(shape,list) or len(shape)!=3 or any(type(x) is not int or not 2<=x<=512 for x in shape): raise ValueError('Grid dimensions must be 2..512 in zyx')
        if not isinstance(spacing,list) or len(spacing)!=3 or any(not isinstance(x,(int,float)) or not math.isfinite(x) or x<=0 for x in spacing): raise ValueError('Invalid xyz spacing')
        if not isinstance(origin,list) or len(origin)!=3 or not np.isfinite(origin).all() or g.get('centering') not in ('cell','node'): raise ValueError('Invalid grid origin/centering')
        for a in arrays:
            if a['shape']!=shape or a['dtype'] not in ('f4','f8') or a['association']!='sample': raise ValueError('Grid scalar shape/dtype/association mismatch')
    else:
        pos=specs.get('position',{})
        if pos.get('dtype') not in ('f4','f8') or len(pos.get('shape',[]))!=2 or pos['shape'][1]!=3 or pos['association']!='vertex': raise ValueError('Required float xyz position')
        n=pos['shape'][0]
        if obj['kind']=='mesh':
            tri=specs.get('triangles',{})
            if tri.get('dtype')!='u4' or len(tri.get('shape',[]))!=2 or tri['shape'][1]!=3 or tri['association']!='topology': raise ValueError('Required uint32 triangle indices')
            if n>1_000_000 or tri['shape'][0]>2_000_000: raise ValueError('Mesh allocation limit')
            ids=specs.get('vertex_id')
            if (ids is not None)!=(obj['identity']=='stable_topology'):raise ValueError('Stable topology requires explicit vertex_id')
            if ids and (ids['dtype']!='i8' or ids['shape']!=[n]):raise ValueError('Exact int64 vertex IDs required')
            normal=specs.get('normal')
            if normal and (normal['dtype'] not in ('f4','f8') or normal['shape']!=[n,3]):raise ValueError('Float xyz vertex normals required')
            for a in arrays:
                if a['name'] in ('position','triangles'):continue
                if a['association'] not in ('vertex','face') or a['shape'][0]!=(n if a['association']=='vertex' else tri['shape'][0]): raise ValueError('Mesh channel association mismatch')
        else:
            if n>10_000_000: raise ValueError('Particle allocation limit')
            ids=specs.get('particle_id')
            if (ids is not None)!=(obj['identity']=='persistent_i8'): raise ValueError('ID presence differs from declaration')
            if ids and (ids['dtype']!='i8' or ids['shape']!=[n] or n>storage.MAX_IDS): raise ValueError('Invalid exact IDs')
            for a in arrays:
                if a['shape'][0]!=n or a['association']!='vertex': raise ValueError('Particle shape/association mismatch')


def schema_valid(obj,desc,stored,decoded):
    arrays=desc.get('arrays') if isinstance(desc,dict) else None
    if not isinstance(arrays,list) or not 1<=len(arrays)<=256: raise ValueError('Array table limit')
    names=set();offset=0;total=0
    for a in arrays:
        if not isinstance(a,dict) or not re.fullmatch('[a-z][a-z0-9_]*',str(a.get('name',''))) or a['name'] in names or a.get('dtype') not in storage.DTYPES: raise ValueError('Unknown/invalid required array')
        names.add(a['name']);shape=a.get('shape')
        if not isinstance(shape,list) or not 1<=len(shape)<=3 or any(type(x) is not int or x<0 or x>10_000_000 for x in shape): raise ValueError('Invalid shape')
        size=math.prod(shape)*storage.DTYPES[a['dtype']]
        if obj['kind']=='volume':field_statistics.validate(a.get('statistics_v1'),math.prod(shape))
        elif 'statistics_v1' in a:raise ValueError('statistics_v1 requires a volume')
        total+=size
        if total>MAX_SAMPLE: raise ValueError('Sample allocation ceiling')
        parts=a.get('chunks')
        if not isinstance(parts,list) or len(parts)>4096: raise ValueError('Chunk table ceiling')
        length=0
        for i,p in enumerate(parts):
            off=storage.decimal(p.get('offset'));s=storage.decimal(p.get('stored'));d=storage.decimal(p.get('decoded'))
            if off!=offset or not 0<d<=codec.MAX_CHUNK or not 0<s<=d+65536 or type(p.get('codec')) is not int or p['codec'] not in (0,1): raise ValueError('Chunk bounds/codec invalid')
            if p['codec']==0 and s!=d: raise ValueError('None byte count mismatch')
            for key in ('raw_sha256','stored_sha256'):
                if not re.fullmatch('[a-f0-9]{64}',str(p.get(key,''))): raise ValueError('Chunk checksum missing')
            if 'origin' in p or 'shape' in p or d!=min(codec.MAX_CHUNK,size-length):raise ValueError('Noncanonical contiguous chunk')
            offset+=s;length+=d
        if length!=size: raise ValueError('Decoded array length mismatch')
    if offset!=stored or total!=decoded: raise ValueError('Sample byte totals mismatch')
    geometry_valid(obj,desc.get('geometry'),arrays)


class SceneCapture:
    def __init__(self,path,*,objects,metadata=None,compression='none',compression_level=1):
        if Path(path).suffix != '.wvz':raise ValueError('WAVEZ Scene Format requires a .wvz path')
        if compression not in ('none','zstd'):raise ValueError('Unknown compression')
        if compression=='zstd':codec.zstd_module()
        self.codec=int(compression=='zstd');self.level=compression_level
        if type(self.level) is not int or not 1<=self.level<=6:raise ValueError('Compression level 1..6 required')
        self.metadata=dict(metadata or {},version=1,uuid=uuid.uuid4().hex,objects=[])
        for obj in objects:
            o=dict(space='viewer_world',static=False,data_to_world=IDENTITY.copy());o.update(obj)
            self.metadata['objects'].append(o)
        metadata_valid(self.metadata);raw=storage.dumps(self.metadata)
        if len(raw)>1048576:raise ValueError('Metadata limit')
        self.file=Path(path).open('xb');self.file.write(PREFIX.pack(MAGIC,1,len(raw))+raw);self.file.flush()
        self.seq=0;self.last={};self.failed=False;self.histories={}
    def _add(self,object_id,time,arrays,associations,geometry):
        if self.failed or self.file.closed:raise ValueError('Closed or failed writer')
        index=next((i for i,o in enumerate(self.metadata['objects']) if o['id']==object_id),-1)
        if index<0:raise ValueError('Unknown object id')
        obj=self.metadata['objects'][index]
        if not np.isfinite(time) or time<=self.last.get(index,-math.inf) or (obj['static'] and index in self.last):raise ValueError('Object times/static sample violation')
        prepared={};total=0
        for name,value in arrays.items():
            a=np.asarray(value);code=a.dtype.kind+str(a.dtype.itemsize)
            if code not in storage.DTYPES:raise ValueError('Unsupported lossless dtype: '+str(a.dtype))
            total+=a.nbytes
            if total>MAX_SAMPLE:raise ValueError('Sample allocation ceiling')
            prepared[name]=np.ascontiguousarray(a,dtype='<'+code)
        specs=[dict(name=n,dtype=a.dtype.str[1:],shape=list(a.shape),association=associations[n]) for n,a in prepared.items()]
        geometry_valid(obj,geometry,specs)
        if obj['kind']!='volume' and 'position' in prepared and not np.isfinite(prepared['position']).all():raise ValueError('Nonfinite positions')
        if obj['kind']=='mesh' and 'triangles' in prepared and prepared['triangles'].size and prepared['triangles'].max()>=len(prepared['position']):raise ValueError('Triangle index outside vertices')
        ordered=None
        if obj['kind']=='mesh' and 'vertex_id' in prepared:_,ordered=storage.validate_ids(prepared['vertex_id'],len(prepared['position']))
        if obj['kind']=='particles' and 'particle_id' in prepared:_,ordered=storage.validate_ids(prepared['particle_id'],len(prepared['position']))
        with tempfile.TemporaryFile() as payload:
            stored=0
            for a in specs:
                value=prepared[a['name']];parts=[]
                if obj['kind']=='volume':
                    a['statistics_v1']=field_statistics.summarize(value)
                raw_view=memoryview(value).cast('B') if value.size else memoryview(b'')
                pieces=((raw_view[start:start+codec.MAX_CHUNK],{}) for start in range(0,value.nbytes,codec.MAX_CHUNK))
                for piece,extra in pieces:
                    raw=memoryview(piece).cast('B');encoded=codec.encode(raw,self.codec,self.level)
                    parts.append(dict(offset=str(stored),stored=str(len(encoded)),decoded=str(len(raw)),codec=self.codec,raw_sha256=storage.sha(raw),stored_sha256=storage.sha(encoded),**extra))
                    payload.write(encoded);stored+=len(encoded)
                a['chunks']=parts
            desc=dict(geometry=geometry,arrays=specs);schema_valid(obj,desc,stored,total);d=storage.dumps(desc)
            if len(d)>storage.MAX_DESC:raise ValueError('Record descriptor ceiling')
            if ordered is not None:self.histories.setdefault(object_id,storage.IdentityHistory()).advance(ordered)
            h=FRAME.pack(b'FRM1',len(d),stored,total,time,index,len(specs),self.seq,hashlib.sha256(d).digest())
            try:
                self.file.write(h);self.file.write(d);payload.seek(0)
                while block:=payload.read(codec.MAX_CHUNK):self.file.write(block)
                self.file.write(COMMIT.pack(b'COMMIT1\0',self.seq,hashlib.sha256(h+d).digest()));self.file.flush()
            except Exception:self.failed=True;raise
        self.last[index]=time;self.seq+=1
    def add_particles(self,object_id,time,positions,*,ids=None,**channels):
        arrays=dict(position=np.asarray(positions),**channels)
        if ids is not None:arrays['particle_id']=np.asarray(ids,dtype='<i8') if np.asarray(ids).dtype.kind in 'iu' and (not np.asarray(ids).size or int(np.asarray(ids).max())<2**63) else np.asarray(ids)
        self._add(object_id,time,arrays,{n:'vertex' for n in arrays},{})
    def add_mesh(self,object_id,time,positions,triangles,*,vertex_channels=None,face_channels=None):
        tri=np.asarray(triangles)
        if tri.dtype.kind not in 'iu' or (tri.size and (tri.min()<0 or tri.max()>2**32-1)):raise ValueError('Exact unsigned triangle indices required')
        arrays=dict(position=np.asarray(positions),triangles=tri.astype('<u4'));assoc=dict(position='vertex',triangles='topology')
        for association,channels in [('vertex',vertex_channels or {}),('face',face_channels or {})]:
            for n,a in channels.items():
                if n in arrays:raise ValueError('Duplicate mesh channel')
                arrays[n]=a;assoc[n]=association
        self._add(object_id,time,arrays,assoc,{})
    def add_volume(self,object_id,time,fields,*,origin,spacing,centering='node'):
        shape=list(np.asarray(next(iter(fields.values()))).shape)
        self._add(object_id,time,fields,{n:'sample' for n in fields},dict(shape=shape,origin=[float(v) for v in origin],spacing=[float(v) for v in spacing],centering=centering))
    def close(self):self.file.close()
    def __enter__(self):return self
    def __exit__(self,*args):self.close()


class SceneReader:
    def __init__(self,path,*,strict=True,cache_bytes=256*1024*1024,metadata_bytes=DEFAULT_METADATA_BYTES):
        if Path(path).suffix != '.wvz':raise ValueError('WAVEZ Scene Format requires a .wvz path')
        self.metadata_budget=MetadataBudget(metadata_bytes)
        self.path=Path(path);self.file=self.path.open('rb');self.cache=OrderedDict();self.used=0;self.limit=cache_bytes;self.records=[];self.source_stamp=self._stamp()
        try:self._scan(strict)
        except Exception:self.close();raise
    def _stamp(self):
        st=self.path.stat();return (st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns,st.st_ctime_ns)
    def _unchanged(self):
        if self._stamp()!=self.source_stamp:raise ValueError('Scene source changed; refresh before reading')
    def refresh(self,*,strict=False):
        self.close()
        self.source_stamp=self._stamp();self.file=self.path.open('rb')
        try:self._scan(strict)
        except Exception:self.close();raise
    def _scan(self,strict):
        prefix=self.file.read(16)
        if len(prefix)!=16:raise ValueError('Incomplete scene prefix')
        magic,version,n=PREFIX.unpack(prefix)
        if magic!=MAGIC or version!=1 or n>1048576:raise ValueError('Unsupported scene format/version')
        reservation=self.metadata_budget.reserve(n)
        self.metadata=json.loads(self.file.read(n));metadata_valid(self.metadata);self.objects={o['id']:o for o in self.metadata['objects']};self.samples={key:[] for key in self.objects}
        self.metadata_budget.retain(reservation,self.metadata)
        end=getattr(self.file,'read_extent',os.fstat(self.file.fileno()).st_size);offset=16+n;last={}
        while offset<end:
            if end-offset<80:
                if strict:raise ValueError('Incomplete scene record')
                break
            self.file.seek(offset);h=self.file.read(80);tag,dlen,stored,decoded,time,oi,narrays,seq,digest=FRAME.unpack(h)
            if tag!=b'FRM1' or dlen>storage.MAX_DESC or stored>MAX_SAMPLE+64*1024*1024 or decoded>MAX_SAMPLE or oi>=len(self.objects) or not math.isfinite(time) or seq!=len(self.records) or not 1<=narrays<=256:raise ValueError('Scene header/allocation limit')
            size=128+dlen+stored
            if size>end-offset:
                if strict:raise ValueError('Incomplete scene payload/commit')
                break
            if seq>=MAX_READER_RECORDS:raise MetadataCapacityError('Reader record capacity exceeded (one million records)')
            reservation=self.metadata_budget.reserve(dlen)
            obj=self.metadata['objects'][oi]
            if time<=last.get(oi,-math.inf) or (obj['static'] and oi in last):raise ValueError('Object time/static violation')
            raw=self.file.read(dlen)
            if hashlib.sha256(raw).digest()!=digest:raise ValueError('Descriptor checksum')
            desc=json.loads(raw);schema_valid(obj,desc,stored,decoded)
            if len(desc['arrays'])!=narrays:raise ValueError('Array count')
            self.file.seek(offset+size-48)
            if COMMIT.unpack(self.file.read(48))!=(b'COMMIT1\0',seq,hashlib.sha256(h+raw).digest()):raise ValueError('Commit checksum')
            record=dict(time=time,object=obj['id'],offset=offset+80+dlen,end=offset+size,decoded=decoded,descriptor=desc,sequence=seq)
            self.metadata_budget.retain(reservation,record)
            self.records.append(record);self.samples[obj['id']].append(record);last[oi]=time;offset+=size
            del raw,desc
        self.committed_end=offset;self.times=sorted(set(r['time'] for r in self.records));self._unchanged()
    def read_sample(self,object_id,index):
        self._unchanged()
        r=self.samples[object_id][index];key=r['sequence']
        if key in self.cache:
            self.cache.move_to_end(key);return {k:v.view() for k,v in self.cache[key].items()}
        arrays={}
        for a in r['descriptor']['arrays']:
            pieces=[]
            for p in a['chunks']:
                self.file.seek(r['offset']+int(p['offset']));stored=self.file.read(int(p['stored']))
                if storage.sha(stored)!=p['stored_sha256']:raise ValueError('Stored checksum')
                raw=codec.decode(stored,int(p['decoded']),p['codec'])
                if storage.sha(raw)!=p['raw_sha256']:raise ValueError('Decoded checksum')
                pieces.append(raw)
            value=np.frombuffer(b''.join(pieces),dtype='<'+a['dtype']).reshape(a['shape'])
            value.flags.writeable=False;arrays[a['name']]=value
        self._unchanged()
        if self.objects[object_id]['kind']=='mesh' and 'vertex_id' in arrays:storage.validate_ids(arrays['vertex_id'],len(arrays['position']))
        if self.objects[object_id]['kind']=='particles' and 'particle_id' in arrays:storage.validate_ids(arrays['particle_id'],len(arrays['position']))
        if self.objects[object_id]['kind']=='mesh' and 'triangles' in arrays and arrays['triangles'].size and arrays['triangles'].max()>=len(arrays['position']):raise ValueError('Triangle index out of bounds')
        if r['decoded']<=self.limit:
            while self.cache and self.used+r['decoded']>self.limit:
                _,old=self.cache.popitem(last=False);self.used-=sum(a.nbytes for a in old.values())
            self.cache[key]=arrays;self.used+=r['decoded']
        return {k:v.view() for k,v in arrays.items()}
    def audit_identity(self):
        for id,obj in self.objects.items():
            identity_name='particle_id' if obj['kind']=='particles' else 'vertex_id'
            if obj.get('identity') not in ('persistent_i8','stable_topology'):continue
            history=storage.IdentityHistory()
            for i in range(len(self.samples[id])):
                a=self.read_sample(id,i);_,ordered=storage.validate_ids(a[identity_name],len(a['position']));history.advance(ordered)
        return True
    def bracket(self,object_id,time):
        rows=self.samples[object_id]
        if not rows:return None
        if self.objects[object_id]['static']:return (0,0,0.,'static')
        if time<rows[0]['time']:return None
        times=[r['time'] for r in rows];i=int(np.searchsorted(times,time,side='right'))-1
        if time==times[i]:return (i,i,0.,'exact')
        j=min(i+1,len(rows)-1)
        return (i,j,0. if i==j else (time-times[i])/(times[j]-times[i]),'held')
    def probe(self,object_id,index,channel,world):
        record=self.samples[object_id][index];g=record['descriptor']['geometry'];a=self.read_sample(object_id,index)[channel]
        transform=affine(self.objects[object_id]['data_to_world']);local=np.linalg.solve(transform[:,:3],np.asarray(world)-transform[:,3]);xyz=(local-g['origin'])/g['spacing']
        shape=np.asarray(a.shape[::-1]);low=-.5 if g['centering']=='cell' else 0.;high=shape-.5 if g['centering']=='cell' else shape-1
        if np.any(xyz<low) or np.any(xyz>high):return None
        xyz=np.clip(xyz,0,shape-1);lo=np.floor(xyz).astype(int);hi=np.minimum(lo+1,shape-1);f=xyz-lo;value=0.
        for dz in (0,1):
            for dy in (0,1):
                for dx in (0,1):
                    v=a[(hi if dz else lo)[2],(hi if dy else lo)[1],(hi if dx else lo)[0]]
                    if not np.isfinite(v):return None
                    value+=float(v)*(f[0] if dx else 1-f[0])*(f[1] if dy else 1-f[1])*(f[2] if dz else 1-f[2])
        return value
    def close(self):
        self.file.close();self.cache.clear();self.used=0
        self.records=[];self.samples={};self.objects={};self.metadata={};self.times=[]
        self.metadata_budget.clear()
    def __enter__(self):return self
    def __exit__(self,*args):self.close()

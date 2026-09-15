"""G3 storage, transforms, source precision, extraction and adapter acceptance."""
import hashlib,json,shutil,struct,sys,tempfile,time,unittest,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import numpy as np
from simscope_export import SceneCapture,SceneReader
from simscope_export.scene import schema_valid,MAX_SAMPLE
from tools.extract_surface import extract
from tools.import_grid_npz import convert,inspect_npz
OUT=ROOT/'results/g3';OUT.mkdir(parents=True,exist_ok=True)
IDENTITY=[1,0,0,0,0,1,0,0,0,0,1,0]

def volume(**kw):return dict(id='field',kind='volume',units='u',**kw)
def mesh(**kw):return dict(id='mesh',kind='mesh',units='m',identity='none',**kw)
def save(path,a,**g):
    with SceneCapture(path,objects=[volume()],compression='zstd') as w:w.add_volume('field',0,{'f':a},origin=g.get('origin',[0,0,0]),spacing=g.get('spacing',[1,1,1]),centering=g.get('centering','node'))

def fixtures():
    # Generate the small demo instead of depending on retained scientific outputs.
    small = OUT/'small.ssc'
    if not small.exists():
        subprocess.run([sys.executable, '-m', 'examples.scene_demo', '--small', '--output', str(small)], cwd=ROOT, check=True)
    # Non-cubic, anisotropic, translated and reflected grid detects axis swaps.
    z,y,x=np.meshgrid(np.arange(35),np.arange(6),np.arange(9),indexing='ij');f=(x*.5+2*y*2+3*z*1.5+7).astype('f8')
    path=OUT/'affine.ssc'
    if path.exists():path.unlink()
    with SceneCapture(path,objects=[volume(data_to_world=[0,-1,0,10,1,0,0,20,0,0,-1,30])]) as w:
        w.add_volume('field',0,{'f':f},origin=[1,2,3],spacing=[.5,2,1.5])
        w.add_volume('field',2,{'f':np.full((4,7,10),5,dtype='f4')},origin=[-3,4,5],spacing=[2,3,4],centering='cell')
    for name,a,spacing,origin in [('slab',np.ones((16,16,16),dtype='f4'),[2/15]*3,[-1]*3),('sphere',None,[.2,.3,.4],[-6,-6,-6])]:
        if a is None:
            z,y,x=np.meshgrid(np.arange(31)*.4-6,np.arange(41)*.3-6,np.arange(61)*.2-6,indexing='ij');a=(9-x*x-y*y-z*z).astype('f4')
        path=OUT/(name+'.ssc')
        if path.exists():path.unlink()
        save(path,a,origin=origin,spacing=spacing)
    z,y,x=np.meshgrid(np.linspace(-12,12,65),np.linspace(-4,4,41),np.linspace(-12,12,65),indexing='ij');a=(4-(np.sqrt(x*x+z*z)-7)**2-y*y).astype('f4')
    for name,data in [('torus',a),('missing',np.where((x>6)&(y>0),np.nan,a))]:
        path=OUT/(name+'.ssc')
        if path.exists():path.unlink()
        save(path,data,origin=[-12,-4,-12],spacing=[24/64,8/40,24/64])


    path=OUT/'names.ssc'
    if path.exists():path.unlink()
    a=np.ones((3,3,3),dtype='f4');a[0,0,0]=np.nan
    with SceneCapture(path,objects=[volume()]) as w:w.add_volume('field',0,{name:a for name in ['position','triangles','particle_id','vertex_id']},origin=[0]*3,spacing=np.ones(3,dtype='f4'))
    path=OUT/'tiny.ssc'
    if path.exists():path.unlink()
    z,y,x=np.indices((8,8,8));save(path,(x*1e-24).astype('f4'),origin=[-1]*3,spacing=[2/7]*3)
    path=OUT/'cadence.ssc'
    if path.exists():path.unlink()
    objects=[dict(id='p',kind='particles',units='m',identity='anonymous'),dict(id='static_mesh',kind='mesh',units='m',static=True,identity='none',data_to_world=[-2,0,0,0,0,3,0,0,0,0,1,0]),dict(id='a',kind='volume',units='u'),dict(id='b',kind='volume',units='u')]
    with SceneCapture(path,objects=objects) as w:
        for t in [0,4]:w.add_particles('p',t,np.array([[t,0,0]],dtype='f4'))
        w.add_mesh('static_mesh',3,np.array([[0,0,0],[1,0,0],[0,1,0]],dtype='f4'),[[0,1,2]],vertex_channels={'normal':np.tile(np.array([0,0,1],dtype='f4'),(3,1))},face_channels={'value':np.array([.25],dtype='f4')})
        for id in ['a','b']:
            for t in [1,3]:w.add_volume(id,t,{'f':np.ones((3,4,5),dtype='f4')*t},origin=[0]*3,spacing=[1]*3)

def interop():
    fixtures=[]
    for name in ['small.ssc','affine.ssc','sphere.ssc','torus.ssc','missing.ssc','names.ssc']:
        with SceneReader(OUT/name,cache_bytes=0) as r:
            samples=[]
            for id in r.objects:
                for i,row in enumerate(r.samples[id]):
                    a=r.read_sample(id,i);samples.append(dict(object=id,index=i,time=row['time'],arrays={k:dict(dtype=v.dtype.str[1:],sha256=hashlib.sha256(v.tobytes()).hexdigest()) for k,v in a.items()}))
            fixtures.append(dict(file=name,samples=samples))
    (OUT/'interop.json').write_text(json.dumps(fixtures))

class SceneTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):fixtures()
    def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name)
    def tearDown(self):self.tmp.cleanup()
    def test_none_zstd_bitwise_bricks_and_nan(self):
        a=np.arange(35*34*33,dtype='f8').reshape(35,34,33)/7;a[2,3,4]=np.nan;a[5,6,7]=-0.
        for codec in ['none','zstd']:
            p=self.base/(codec+'.ssc')
            with SceneCapture(p,objects=[volume()],compression=codec) as w:w.add_volume('field',.125,{'f':a},origin=[0,0,0],spacing=[1,2,3])
            with SceneReader(p) as r:self.assertEqual(r.read_sample('field',0)['f'].tobytes(),a.tobytes())
    def test_cache_cannot_mutate_scientific_values(self):
        p=self.base/'a.ssc';save(p,np.ones((4,4,4),dtype='f8'))
        with SceneReader(p) as r:
            a=r.read_sample('field',0)['f']
            with self.assertRaises(ValueError):a.setflags(write=True)
            with self.assertRaises(ValueError):a.base.setflags(write=True)
            self.assertEqual(r.read_sample('field',0)['f'][0,0,0],1)
    def test_bounded_cache(self):
        with SceneReader(OUT/'affine.ssc',cache_bytes=3000) as r:
            for _ in range(3):
                r.read_sample('field',0);r.read_sample('field',1);self.assertLessEqual(r.used,3000)
    def test_transform_source_probe(self):
        with SceneReader(OUT/'affine.ssc') as r:
            # local=(1+.5*2.3,2+2*1.4,3+1.5*3.2); rotate/reflect/translate.
            q=np.array([2.15,4.8,7.8]);world=[10-q[1],20+q[0],30-q[2]]
            self.assertAlmostEqual(r.probe('field',0,'f',world),2.3*.5+2*1.4*2+3*3.2*1.5+7,places=11)
            self.assertIsNone(r.probe('field',0,'f',[999,999,999]))
    def test_cell_faces(self):
        p=self.base/'a.ssc';save(p,np.ones((3,4,5),dtype='f8'),centering='cell')
        with SceneReader(p) as r:
            self.assertEqual(r.probe('field',0,'f',[-.5,-.5,-.5]),1);self.assertIsNone(r.probe('field',0,'f',[-.501,0,0]))
    def test_grid_change_and_hold(self):
        with SceneReader(OUT/'affine.ssc') as r:
            self.assertEqual(r.bracket('field',1)[3],'held');self.assertEqual(r.read_sample('field',1)['f'].shape,(4,7,10));self.assertIsNone(r.bracket('field',-1))
    def test_live_partial_and_refresh(self):
        p=self.base/'live.ssc'
        with SceneCapture(p,objects=[volume()]) as w:
            w.add_volume('field',0,{'f':np.ones((3,3,3),dtype='f4')},origin=[0]*3,spacing=[1]*3)
            with SceneReader(p) as r:
                w.add_volume('field',1,{'f':np.ones((3,3,3),dtype='f4')*2},origin=[0]*3,spacing=[1]*3)
                with self.assertRaisesRegex(ValueError,'changed'):r.read_sample('field',0)
                r.refresh();self.assertEqual(len(r.records),2)
        data=p.read_bytes();p.write_bytes(data[:-20])
        with self.assertRaises(ValueError):SceneReader(p)
        with SceneReader(p,strict=False) as r:self.assertEqual(len(r.records),1)
    def test_corrupt_payload_rejected(self):
        p=self.base/'bad.ssc';save(p,np.ones((3,3,3),dtype='f4'))
        with SceneReader(p) as r:offset=r.records[0]['offset']
        raw=bytearray(p.read_bytes());raw[offset]^=1;p.write_bytes(raw)
        with SceneReader(p) as r:
            with self.assertRaises(ValueError):r.read_sample('field',0)
    def test_corrupt_commit_rejected(self):
        p=self.base/'bad.ssc';save(p,np.ones((3,3,3),dtype='f4'));raw=bytearray(p.read_bytes());raw[-1]^=1;p.write_bytes(raw)
        with self.assertRaises(ValueError):SceneReader(p)
    def test_mesh_indices_and_nonfinite(self):
        with SceneCapture(self.base/'m.ssc',objects=[mesh()]) as w:
            with self.assertRaises(ValueError):w.add_mesh('mesh',0,np.zeros((3,3),dtype='f4'),[[0,1,4]])
            with self.assertRaises(ValueError):w.add_mesh('mesh',0,np.full((3,3),np.nan,dtype='f4'),[[0,1,2]])
    def test_explicit_mesh_ids(self):
        with SceneCapture(self.base/'m.ssc',objects=[dict(mesh(),identity='stable_topology')]) as w:
            with self.assertRaises(ValueError):w.add_mesh('mesh',0,np.zeros((3,3),dtype='f4'),[[0,1,2]])
            w.add_mesh('mesh',0,np.zeros((3,3),dtype='f4'),[[0,1,2]],vertex_channels={'vertex_id':np.array([2**53+1,2**53+2,2**53+3],dtype='i8')})
        with SceneReader(self.base/'m.ssc') as r:self.assertEqual(int(r.read_sample('mesh',0)['vertex_id'][0]),2**53+1)
    def test_identity_death_cannot_reappear(self):
        with SceneCapture(self.base/'p.ssc',objects=[dict(id='p',kind='particles',units='m',identity='persistent_i8')]) as w:
            w.add_particles('p',0,np.zeros((1,3),dtype='f4'),ids=[2**53+1]);w.add_particles('p',1,np.zeros((0,3),dtype='f4'),ids=np.empty(0,dtype='i8'))
            with self.assertRaises(ValueError):w.add_particles('p',2,np.zeros((1,3),dtype='f4'),ids=[2**53+1])
    def test_identity_audit(self):
        with SceneReader(OUT/'small.ssc',cache_bytes=0) as r:self.assertTrue(r.audit_identity())
    def test_static_and_independent_clock(self):
        with SceneReader(OUT/'small.ssc') as r:
            self.assertEqual(len(r.times),9);self.assertEqual(r.bracket('density',.5),(0,1,.5,'held'));self.assertEqual(r.bracket('surface',.5),(0,1,.25,'held'))
    def test_scalar_names_do_not_imply_geometry_or_identity(self):
        p=self.base/'names.ssc';a=np.ones((3,3,3),dtype='f4');a[0,0,0]=np.nan
        with SceneCapture(p,objects=[volume()]) as w:w.add_volume('field',0,{name:a for name in ['position','triangles','particle_id','vertex_id']},origin=[0]*3,spacing=[1]*3)
        with SceneReader(p) as r:
            for value in r.read_sample('field',0).values():np.testing.assert_array_equal(value,a)
    def test_grid_shape_ceiling(self):
        with SceneCapture(self.base/'a.ssc',objects=[volume()]) as w:
            with self.assertRaises(ValueError):w.add_volume('field',0,{'f':np.ones((2,2,513),dtype='f4')},origin=[0]*3,spacing=[1]*3)
    def test_singular_transform(self):
        with self.assertRaises(ValueError):SceneCapture(self.base/'a.ssc',objects=[volume(data_to_world=[0]*12)])
    def test_no_overwrite(self):
        p=self.base/'a.ssc';save(p,np.ones((3,3,3),dtype='f4'))
        with self.assertRaises(FileExistsError):SceneCapture(p,objects=[volume()])
    def test_npz_explicit_axes_and_complex_derivations(self):
        a=np.arange(5*4*3,dtype='f4').reshape(5,4,3)+1j*np.ones((5,4,3),dtype='f4');np.savez(self.base/'raw.npz',psi=a)
        m={'version':1,'object':{'units':'u'},'fields':{k:{'array':'psi','axes':'xyz','derive':d} for k,d in [('re','real'),('im','imag'),('rho','abs2')]},'geometry':{'origin':[1,2,3],'spacing':[.1,.2,.3]},'snapshots':[{'file':'raw.npz','time':3}]}
        (self.base/'map.json').write_text(json.dumps(m));convert(self.base/'map.json',self.base/'out.ssc')
        with SceneReader(self.base/'out.ssc') as r:
            v=r.read_sample('field',0);np.testing.assert_array_equal(v['rho'],(a.real*a.real+a.imag*a.imag).transpose(2,1,0));self.assertIn('mapping',r.metadata['provenance'])
    def test_npz_pickle_rejected(self):
        np.savez(self.base/'bad.npz',x=np.array([{}],dtype=object))
        with self.assertRaises(ValueError):inspect_npz(self.base/'bad.npz')
    def test_extraction_preflight_and_empty_level(self):
        z,y,x=np.indices((64,64,64));p=self.base/'complex.ssc';save(p,((x+y+z)%2).astype('f4'))
        job={'source':str(p),'extent':str(p.stat().st_size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'object':'field','index':0,'channel':'f','threshold':.5,'cache':str(self.base/'cache')}
        with self.assertRaisesRegex(ValueError,'ceiling'):extract(job)
        job['threshold']=2.;result=extract(job);self.assertEqual(result['triangles'],0)
    def test_mesh_size_and_channel_association(self):
        with SceneCapture(self.base/'m.ssc',objects=[mesh()]) as w:
            with self.assertRaises(ValueError):w.add_mesh('mesh',0,np.zeros((1_000_001,3),dtype='f4'),[[0,1,2]])
            with self.assertRaises(ValueError):w.add_mesh('mesh',0,np.zeros((3,3),dtype='f4'),[[0,1,2]],face_channels={'f':np.zeros(3,dtype='f4')})
    def test_sphere_torus_surface_and_cache(self):
        evidence=[]
        for name in ['sphere','torus','missing']:
            source=OUT/(name+'.ssc');job={'source':str(source),'extent':str(source.stat().st_size),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'object':'field','index':0,'channel':'f','threshold':0.,'cache':str(self.base/'cache')}
            result=extract(job)
            with SceneReader(result['path']) as r:v=r.read_sample('isosurface',0);p=v['position'];f=v['triangles'];center=p[f].mean(axis=1);norm=np.cross(p[f[:,1]]-p[f[:,0]],p[f[:,2]]-p[f[:,0]])
            error=np.abs(np.linalg.norm(p,axis=1)-3) if name=='sphere' else np.abs(np.sqrt((np.sqrt(p[:,0]**2+p[:,2]**2)-7)**2+p[:,1]**2)-2)
            self.assertLess(float(error.max()),.04)
            if name=='sphere':self.assertGreater(float(np.mean(np.sum(norm*center,axis=1))),0)
            edges=np.sort(np.concatenate([f[:,[0,1]],f[:,[1,2]],f[:,[2,0]]]),axis=1);_,counts=np.unique(edges,axis=0,return_counts=True)
            if name!='missing':self.assertTrue(np.all(counts==2),'No brick-boundary cracks')
            else:self.assertGreater(np.sum(counts==1),0,'Explicit invalid-data opening')
            self.assertTrue(extract(job)['cache_hit']);evidence.append(dict(name=name,max_error=float(error.max()),boundary_edges=int(np.sum(counts==1)),**{k:result[k] for k in ['vertices','triangles','seconds','peak_rss_mib']}))
            Path(result['path']).write_bytes(b'corrupt');self.assertFalse(extract(job)['cache_hit'])
        (OUT/'surface-measurements.json').write_text(json.dumps(evidence,indent=2))

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(SceneTests);result=unittest.TextTestRunner(verbosity=2).run(suite)
    interop()
    (OUT/'python-tests.json').write_text(json.dumps({'checks':result.testsRun,'failures':len(result.failures),'errors':len(result.errors)},indent=2));raise SystemExit(not result.wasSuccessful())

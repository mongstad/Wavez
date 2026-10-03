"""G3 analytic toroidal scalar grid, animated mesh and explicit-ID particles."""
import argparse,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture


def torus(n=32,m=16,radius=8.,tube=2.):
    u,v=np.meshgrid(np.arange(n)*2*np.pi/n,np.arange(m)*2*np.pi/m,indexing='ij')
    p=np.stack(((radius+tube*np.cos(v))*np.cos(u),tube*np.sin(v),(radius+tube*np.cos(v))*np.sin(u)),axis=-1).reshape(-1,3).astype('f4')
    faces=[]
    for i in range(n):
        for j in range(m):
            a=i*m+j;b=((i+1)%n)*m+j;c=((i+1)%n)*m+(j+1)%m;d=i*m+(j+1)%m
            faces.extend([[a,c,b],[a,d,c]])
    return p,np.asarray(faces,dtype='u4')


def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--small',action='store_true');a.add_argument('--output',type=Path);args=a.parse_args()
    out=args.output or ROOT/'results/g3'/('small.wvz' if args.small else 'scene-demo.wvz');out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists():raise SystemExit('Choose a new output; demo does not overwrite captures')
    n=32 if args.small else 128;count=64 if args.small else 100000
    objects=[dict(id='particles',kind='particles',units='demo units',identity='persistent_i8'),dict(id='surface',kind='mesh',units='demo units',identity='stable_topology'),dict(id='density',kind='volume',units='density units',channels={'rho':{'units':'density units'},'signed':{'units':'demo units'}})]
    x=np.linspace(-16,16,n,dtype='f4');z,y,x=np.meshgrid(x,x,x,indexing='ij');distance=(np.sqrt(x*x+z*z)-9)**2+y*y
    rho=np.exp(-distance/8).astype('f4');signed=(x+2*y+3*z).astype('f8')
    rng=np.random.default_rng(731);positions=rng.normal(0,6,(count,3)).astype('f4');ids=np.arange(count,dtype='i8')+2**53+1
    mesh,tri=torus()
    with SceneCapture(out,objects=objects,metadata={'simulation_name':'G3 analytic field / mesh / particles','provenance':'Synthetic analytic fixtures; not a reconstructed physical field','geometry':{'version':1,'coordinate_space':'viewer_world','units':'demo units','domain':{'min':[-16,-16,-16],'max':[16,16,16]},'absorber':{'center':[0,0,0],'start':14.,'width':2.,'profile':'synthetic declared demonstration boundary'}}},compression='zstd') as capture:
        for i in range(9):
            t=i/4;order=np.roll(np.arange(count),i*17)
            capture.add_particles('particles',t,positions[order]+np.array([0,np.sin(t),0],dtype='f4'),ids=ids[order],particle_type=np.asarray(order%3,dtype='u4'),visual_size=np.full(count,.13 if count>1000 else .8,dtype='f4'))
            if i in (0,4,8):
                capture.add_volume('density',t,{'rho':rho*(1+.1*t),'signed':signed+t},origin=[-16.,-16.,-16.],spacing=[32/(n-1)]*3)
            if i in (0,8):capture.add_mesh('surface',t,mesh*np.float32(1+.08*t),tri,vertex_channels={'height':mesh[:,1],'vertex_id':np.arange(len(mesh),dtype='i8')})
    print(out)

if __name__=='__main__':main()

"""Explicit simulator-owned identities, reordered rows and particle birth/death.

Run from the project root: python examples/identity_demo.py
Open results/identity-demo.ssc, choose Physical time and enable Recorded History.
"""
from pathlib import Path
import sys
import argparse
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from wavez_export import SceneCapture


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'results/identity-demo.ssc')
    output=parser.parse_args().output
    output.parent.mkdir(parents=True,exist_ok=True)
    # These keys are assigned to simulated lifetimes, independent of row order.
    identities=np.array([16777217,9007199254740993,9223372036854775807,44,55],dtype='<i8')
    with SceneCapture(output,objects=[dict(id='particles',kind='particles',units='demo units',identity='persistent_i8')],compression='none',metadata={
            'simulation_name':'Explicit identities: reorder, birth and death',
            'units':'demo units','time_unit':'seconds'}) as capture:
        for sample in range(121):
            t=sample/10
            active=[0,1,2]+([3] if sample<70 else [])+([4] if sample>=30 else [])
            active=np.roll(active,sample%len(active))
            phase=np.asarray(active)*1.25+t
            positions=np.column_stack((6*np.cos(phase),np.asarray(active)*2-4,6*np.sin(phase))).astype('<f4')
            capture.add_particles("particles",t,positions,ids=identities[active],
                particle_type=np.asarray(active,dtype='<u4'),
                phase=np.remainder(phase,2*np.pi).astype('<f8'),visual_size=np.full(len(active),.6,dtype="f4"))
    print(output)

if __name__=='__main__': main()

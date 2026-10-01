"""Self-contained synthetic G4 selections, native traces, field mass and diagnostics.

Run: python -m examples.g4_demo --output results/g4-demo
Open scene.ssc in the native viewer; GUIDE.md in the new output gives the oracles.
"""
import argparse,csv,hashlib,json,math
from pathlib import Path
import numpy as np
from wavez_export import SceneCapture
from wavez_export.analysis import SourceSnapshot,AnalysisError,selectors as S
from wavez_export.analysis.jobs import execute
from wavez_export.analysis.member_assets import MemberAssets
from wavez_export.analysis.result_store import ResultCache
from wavez_export.analysis.recipes import pack


def create(path):
    high=2**53+1;objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m'),dict(id='field',kind='volume',units='mixed; channel metadata authoritative'),dict(id='mesh',kind='mesh',identity='stable_topology',units='m')]
    metadata=dict(time_unit='s',position_unit='m',simulation_name='G4 synthetic selections and temporal analysis',channel_metadata=dict(p=dict(value=dict(units='K'),velocity=dict(units='m/s')),field=dict(rho=dict(units='kg/m^3',quantity='mass_density',physical=dict(mass_unit='kg',length_unit='m',scale=1)),signal=dict(units='1'))))
    particle_times={0:[7,high],.5:[high,7,9],1.5:[9,high],3:[9]}
    with SceneCapture(path,objects=objects,metadata=metadata,compression='zstd') as writer:
        for time in [0,.25,.5,1,1.5,2.5,3,4]:
            if time in particle_times:
                ids=np.array(particle_times[time],dtype='i8');x=np.array([0. if i==high else -.5 if i==7 else .5 for i in ids])+time
                writer.add_particles('p',time,np.column_stack((x,x*0,x*0)),ids=ids,value=300.+x,velocity=np.tile([1.,0,0],(len(x),1)),visual_size=np.full(len(x),.15))
            if time in [0,.25,1,2.5,4]:
                x=np.arange(4);signal=np.tile(np.exp(-((x-time)/.6)**2),(2,3,1))
                writer.add_volume('field',time,dict(rho=np.full((2,3,4),2.),signal=signal),origin=[0,0,0],spacing=[1,2,3],centering='cell')
            if time in [0,4]:writer.add_mesh('mesh',time,np.array([[0.,-2,0],[1,-2,0],[0,-1,0]])+[0,0,time*.1],[[0,1,2]],vertex_channels=dict(vertex_id=np.array([11,12,13],dtype='i8'),value=np.array([1.,2.,3.])))
    return path


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    path=create(out/'scene.ssc');digest=hashlib.sha256(path.read_bytes()).hexdigest();assets=MemberAssets(out/'private/members');cache=ResultCache(out/'private/results');outputs=[];serial=0
    with SourceSnapshot(path,assets=assets) as source:
        identity=source.identity()
        cohort=S.define(source,dict(key='cohort',name='Exact persistent cohort',object='p',kind='particle_ids',selector=dict(ids=['7',str(2**53+1)])))
        region=S.define(source,dict(key='region',name='Fixed spatial box',object='p',kind='roi',selector=dict(shape='box',lower=[-1,-1,-1],upper=[1,1,1])))
        field=S.define(source,dict(key='field',name='Whole cell-centered source grid',object='field',kind='roi',selector=dict(shape='box',lower=[-10]*3,upper=[10]*3)))
        lower=S.define(source,dict(key='lower-cylinder',name='Lower cylinder on source cells',object='field',kind='roi',selector=dict(shape='cylinder',start=[1.5,2,-1.5],end=[1.5,2,1.5],radius=3)))
    def run(operation,arguments,binding=None):
        nonlocal serial
        serial+=1
        return execute(dict(version=1,id='demo-'+str(serial),scene_revision=1,selection_revision=1,operation=operation,source=binding or identity,arguments=arguments),assets=assets,results=cache,provenance=dict(example='examples/g4_demo.py',source_kind='synthetic analytic fixture'))['data']
    def export(name,result,binding=None):
        result=run('export_analysis',dict(result=result,destination=str(out/name),quota_bytes=16*1024**2),binding);outputs.append(result['export'])
    interval=dict(axis='native_time',start=0,end=4)
    trace=run('analyze',dict(selections=[cohort],mode='trace',channels=[dict(channel='position',component=0),dict(channel='velocity',component=0),dict(channel='value')],range=interval))['result'];export('traces',trace)
    population=run('analyze',dict(selections=[cohort,region],mode='population',channels=[],range=interval))['result'];export('populations',population)
    mass=run('analyze',dict(selections=[field],mode='integral',channels=[dict(channel='rho')],range=interval,physical_mass=True))['result'];export('field-mass',mass)
    mass_rows=cache.page(mass)['rows']
    assert len(mass_rows)==5 and all(float(r['value'])==288 and r['units']=='kg' for r in mass_rows)
    lower_mass=run('analyze',dict(selections=[lower],mode='integral',channels=[dict(channel='rho')],range=interval,physical_mass=True))['result'];export('lower-cylinder-mass',lower_mass)
    assert all(float(r['value'])==144 for r in cache.page(lower_mass)['rows'])
    spatial=run('space_time',dict(object='field',mode='grid_line',channel=dict(channel='signal'),range=interval,spatial=dict(start=[0,0,0],end=[3,0,0],bins=12,space='data_local',units='m')))['result'];export('space-time',spatial)
    diagnostic=out/'supplied-diagnostic.csv'
    with diagnostic.open('w',newline='') as file:
        writer=csv.writer(file);writer.writerow(['t','oscillation'])
        for n in range(241):writer.writerow([format(n*.05,'.17g'),format(math.sin(math.pi*n*.05),'.17g')])
    csv_hash=hashlib.sha256(diagnostic.read_bytes()).hexdigest()
    supplied=run('import_csv',dict(path=str(diagnostic),key='supplied',time_column='t',time_units='s',delimiter=',',values=[dict(column='oscillation',dtype='f8',units='1')]))['result'];export('diagnostic',supplied)
    period=run('estimate_period',dict(result=supplied,series=dict(selection_key='supplied',channel='oscillation',component='',statistic='supplied_diagnostic',member_key=''),window=[0,12],options=dict(method='peak_spacing',detrend='mean',lag_range=[1,3],min_separation=1,prominence=.5)))['result'];export('period',period)
    candidates=[row for row in cache.page(period)['rows'] if row['statistic']=='exploratory_period']
    assert candidates and all(float(row['value'])==2 and row['value_status']=='exploratory_candidate' for row in candidates)
    tracer_path=out/'tracer-only.ssc'
    with SceneCapture(tracer_path,objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m')],metadata=dict(time_unit='s',position_unit='m',channel_metadata=dict(p=dict(rho=dict(units='kg/m^3'))))) as writer:
        for t in [0,.5,1.5,3]:writer.add_particles('p',t,np.array([[.25+t,2,0],[.75+t,2,0],[1.25+t,2,0]]),ids=[7,8,9],rho=np.full(3,2.))
    tracer_hash=hashlib.sha256(tracer_path.read_bytes()).hexdigest()
    with SourceSnapshot(tracer_path,assets=assets) as source:
        tracer_identity=source.identity();tracer_roi=S.define(source,dict(key='tracer-cylinder',object='p',kind='roi',selector=dict(shape='cylinder',start=[1.5,2,-1.5],end=[1.5,2,1.5],radius=3)))
    try:run('analyze',dict(selections=[tracer_roi],mode='integral',channels=[dict(channel='rho')],range=interval,physical_mass=True),tracer_identity)
    except AnalysisError as error:refusal=dict(code=error.code,message=str(error),interpretation='Sampled tracer density cannot supply an exact original-grid field integral')
    else:raise AssertionError('Tracer-only exact field mass must refuse')
    tracer_series=run('space_time',dict(object='p',mode='tracer_bins',selection=tracer_roi,channel=dict(channel='rho'),reducer='sample_mean',range=interval,spatial=dict(start=[0,2,0],end=[5,2,0],bins=10,space='viewer_world',units='m')),tracer_identity)['result'];export('tracer-estimate',tracer_series,tracer_identity)
    assert hashlib.sha256(tracer_path.read_bytes()).hexdigest()==tracer_hash
    assert hashlib.sha256(path.read_bytes()).hexdigest()==digest and hashlib.sha256(diagnostic.read_bytes()).hexdigest()==csv_hash
    (out/'selections.json').write_text(json.dumps(pack(dict(source=identity,definitions=[cohort,region,field,lower],tracer_source=tracer_identity,tracer_definitions=[tracer_roi])),indent=2)+'\n')
    (out/'demo.json').write_text(json.dumps(dict(kind='wavez-g4-synthetic-demo',source=identity,tracer_source=tracer_identity,tracer_field_integral_refusal=refusal,exports=outputs,oracles=dict(field_mass_kg=288,lower_cylinder_mass_kg=144,field_samples=5,particle_times=[0,.5,1.5,3],recorded_velocity_m_s=1,diagnostic_period_seconds=2),source_unchanged=True),indent=2)+'\n')
    (out/'GUIDE.md').write_text('''# Synthetic G4 walkthrough

Open `scene.ssc`, choose **Selections → Use current capture**, and inspect object `p`.
Create the exact ID cohort `7,9007199254740993` or the box from (-1,-1,-1) to (1,1,1).
The cohort follows supplied IDs; the spatial box reevaluates membership. ID 7 is
absent at 1.5 s and the large ID is absent at 3 s. No missing member becomes zero.
Particle positions interpolate by ID; recorded scalars/velocity hold. The recorded
velocity is 1 m/s. `selections.json` is a readable definition inventory, not an
inspection recipe; save portable viewer state through **Analysis export and state**.

The field clock is 0, 0.25, 1, 2.5, 4 s. Its 24 whole cells each occupy 6 m³,
with declared density 2 kg/m³: every native field integral is exactly 288 kg.
The scalar `signal` is a sampled pulse, distinct from mass density. The mesh has
stable explicit vertex IDs 11–13. Use a source probe or a line space-time request
on `signal` to inspect the field at its own cadence.

The lower-cylinder ROI has axis (1.5,2,-1.5) → (1.5,2,1.5), radius 3 m.
It includes the 12 lower cells: discrete mass is 144 kg. `tracer-only.ssc` has
supplied density samples and no grid. Its exact field-mass request is explicitly
refused; `tracer-estimate` contains only labeled sampled means at native times.

Eight export folders contain full scientific CSV, support JSONL and provenance.
`supplied-diagnostic.csv` has its own 0.05 s clock and analytic 2 s period. Import
it explicitly in Diagnostics; exploratory peak spacing should report 2 s over
[0,12]. It is supplied synthetic data, not an automatic event detector.

To compare two saved scenes, choose both recipes and exact selection keys in
**Matched runs**, explicitly select every capture, declare common coordinates,
clock/unit mappings and fixed scalar bounds, prepare, then render the pair.
G5 local services and G6 automatic event detection are outside this example.
''')
    print('G4 synthetic demo:',out)


if __name__=='__main__':main()

import hashlib,math,tempfile,unittest
from pathlib import Path
import numpy as np
from wavez_export import SceneCapture
from wavez_export.analysis import SourceSnapshot,Context,AnalysisError
from wavez_export.analysis.space_time import run
from wavez_export.analysis.result_store import ResultCache
from wavez_export.analysis import selectors as S
from tests.g4.fixtures import scene


class SpaceTimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.path=scene(self.root/'fixture.wvz');self.source=SourceSnapshot(self.path)
        self.digest=hashlib.sha256(self.path.read_bytes()).hexdigest();self.cache=ResultCache(self.root/'owner'/'results')

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0);self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest);self.tmp.cleanup()

    def evaluate(self,args,source=None):
        result=run(source or self.source,args,self.cache)
        return self.cache.page(result['result'])['rows'],self.cache.page(result['result'],kind='support')['rows'],self.cache.manifest(result['result'],Context()),result['result']

    def test_affine_line_source_values_and_nonuniform_native_times(self):
        rows,support,manifest,_=self.evaluate(dict(object='field',mode='grid_line',channel=dict(channel='value'),range=dict(axis='native_time',start=0,end=4),spatial=dict(start=[0,0,0],end=[1.5,0,0],bins=3,space='data_local',units='m')))
        self.assertEqual([r['time'] for r in rows],['0']*3+['1']*3+['4']*3)
        self.assertEqual([float(r['value']) for r in rows],[7.25,7.75,8.25,8.25,8.75,9.25,11.25,11.75,12.25])
        self.assertEqual(support[0]['source_world_coordinate'][0]['text'],'10.5')
        self.assertEqual(support[0]['lower_edge']['text'],'0');self.assertEqual(support[0]['upper_edge']['text'],'0.5')
        self.assertIn('direct source grid',manifest['value_origin'])

    def test_slab_integral_uses_whole_cells_and_determinant_once(self):
        args=dict(object='field',mode='grid_slab',reducer='integral',channel=dict(channel='constant',override=dict(units='kg/m^3')),range=dict(axis='native_time',start=0,end=0),spatial=dict(start=[0,0,0],end=[1.5,0,0],bins=3,space='data_local',units='m',slab=dict(shape='slab',center=[.75,2,1.5],normal=[0,0,1],tangent=[1,0,0],width=2,height=5,thickness=4)))
        rows,support,_,_=self.evaluate(args)
        self.assertEqual([float(r['value']) for r in rows],[24,24,24]);self.assertEqual(sum(float(r['value']) for r in rows),72)
        self.assertEqual([r['selected_support'] for r in support],[2]*3)
        self.assertEqual([r['world_cell_volume']['text'] for r in support],['6']*3)
        args['reducer']='mean';rows,_,_,_=self.evaluate(args);self.assertEqual([float(r['value']) for r in rows],[2]*3)

    def test_tracer_bins_counts_mean_and_declared_weighted_estimate(self):
        path=self.root/'tracers.wvz'
        with SceneCapture(path,objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m')],metadata=dict(time_unit='s')) as writer:
            writer.add_particles('p',0,np.array([[0.,0,0],[.5,0,0],[1,0,0],[1.5,0,0],[2,0,0]]),ids=np.arange(5,dtype='i8'),value=np.array([1.,3.,5.,7.,9.]),weight=np.array([2.,2.,2.,2.,2.]))
        args=dict(object='p',mode='tracer_bins',range=dict(axis='native_time',start=0,end=0),spatial=dict(start=[0,0,0],end=[2,0,0],bins=2,space='viewer_world',units='m'))
        with SourceSnapshot(path) as source:
            rows,support,manifest,_=self.evaluate(args,source);self.assertEqual([r['value'] for r in rows],['2','3']);self.assertIn('tracer samples/estimate',manifest['value_origin'])
            args.update(reducer='sample_mean',channel=dict(channel='value'))
            rows,_,_,_=self.evaluate(args,source);self.assertEqual([float(r['value']) for r in rows],[2,7])
            args.update(reducer='weighted_estimate',weight=dict(channel='weight'))
            with self.assertRaisesRegex(AnalysisError,'interpretation'):self.evaluate(args,source)
            args['sampling_population']='Each tracer represents two declared population members'
            args['weight']['override']=dict(quantity='sampling_weight',units='1')
            rows,_,_,_=self.evaluate(args,source);self.assertEqual([float(r['value']) for r in rows],[8,42])

    def test_invalid_corner_and_missing_channel_never_become_zero(self):
        path=self.root/'invalid.wvz';grid=np.ones((2,2,2));grid[1,1,1]=np.nan
        with SceneCapture(path,objects=[dict(id='f',kind='volume',units='unknown')]) as writer:writer.add_volume('f',0,dict(value=grid),origin=[0,0,0],spacing=[1,1,1],centering='node')
        args=dict(object='f',mode='grid_line',channel=dict(channel='value'),range=dict(axis='native_time',start=0,end=0),spatial=dict(start=[-.5,0,0],end=[.5,0,0],bins=1,space='data_local',units='unknown'))
        with SourceSnapshot(path) as source:
            rows,_,_,_=self.evaluate(args,source);self.assertEqual(rows[0]['value'],'');self.assertEqual(rows[0]['reason'],'nonfinite_support')
            args['channel']['channel']='missing';rows,_,_,_=self.evaluate(args,source);self.assertEqual(rows[0]['reason'],'missing_channel')

    def test_cell_slab_and_grid_channel_named_position_keep_source_semantics(self):
        path=self.root/'cell.wvz'
        with SceneCapture(path,objects=[dict(id='f',kind='volume',units='K',data_to_world=[-2,0,0,10,0,1,0,0,0,0,1,0])],metadata=dict(position_unit='m',channel_metadata=dict(f=dict(position=dict(units='K'))))) as writer:
            writer.add_volume('f',0,dict(position=np.full((2,2,2),2.)),origin=[0,0,0],spacing=[1,1,1],centering='cell')
        args=dict(object='f',mode='grid_slab',channel=dict(channel='position'),reducer='integral',range=dict(axis='native_time',start=0,end=0),spatial=dict(start=[-.5,0,0],end=[1.5,0,0],bins=2,space='data_local',units='m',slab=dict(shape='slab',center=[.5,.5,.5],normal=[0,0,1],tangent=[1,0,0],width=3,height=3,thickness=3)))
        with SourceSnapshot(path) as source:
            rows,support,manifest,_=self.evaluate(args,source)
        self.assertEqual([r['value'] for r in rows],['16','16']);self.assertEqual(manifest['channel']['units'],'K')
        self.assertEqual([r['selected_support'] for r in support],[4,4]);self.assertEqual(support[0]['world_cell_volume']['text'],'2')

    def test_invalid_sampling_weights_cannot_be_a_complete_estimate(self):
        path=self.root/'weights.wvz'
        with SceneCapture(path,objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m')]) as writer:
            writer.add_particles('p',0,np.array([[.25,0,0],[.75,0,0],[1.25,0,0],[1.75,0,0]]),ids=np.arange(4,dtype='i8'),value=np.array([2.,4.,6.,8.]),weight=np.array([1.,np.nan,-1.,1.]))
        args=dict(object='p',mode='tracer_bins',reducer='weighted_estimate',channel=dict(channel='value'),weight=dict(channel='weight',override=dict(quantity='sampling_weight')),sampling_population='Declared synthetic sampling population',range=dict(axis='native_time',start=0,end=0),spatial=dict(start=[0,0,0],end=[2,0,0],bins=2,space='viewer_world',units='m'))
        with SourceSnapshot(path) as source:rows,support,_,_=self.evaluate(args,source)
        self.assertEqual([r['value'] for r in rows],['','']);self.assertEqual([r['reason'] for r in rows],['incomplete_weighted_support','negative_weights'])
        self.assertEqual(support[0]['invalid_weight_count'],1)

    def test_anonymous_cohorts_have_no_temporal_population_and_bins_preflight(self):
        selected=S.define(self.source,dict(object='p',kind='sample_rows',selector=dict(index=0,rows=[0])))
        args=dict(object='p',mode='tracer_bins',selection=selected,range=dict(axis='native_time',start=0,end=3),spatial=dict(start=[0,0,0],end=[100,0,0],bins=2,space='viewer_world',units='m'))
        with self.assertRaisesRegex(AnalysisError,'sample-local'):self.evaluate(args)
        del args['selection'];args['spatial']['bins']=16385
        with self.assertRaises(AnalysisError):self.evaluate(args)

    def test_traveling_pulse_peak_follows_recorded_irregular_times(self):
        path=self.root/'pulse.wvz';times=[0,.25,1,2.5,4]
        with SceneCapture(path,objects=[dict(id='f',kind='volume',units='unknown')],metadata=dict(time_unit='s',position_unit='m')) as writer:
            for t in times:
                x=np.arange(21)*.25;profile=np.exp(-((x-t)/.25)**2);writer.add_volume('f',t,dict(value=np.tile(profile,(2,2,1))),origin=[0,0,0],spacing=[.25,1,1],centering='node')
        with SourceSnapshot(path) as source:
            _,_,_,ref=self.evaluate(dict(object='f',mode='grid_line',channel=dict(channel='value'),range=dict(axis='native_time',start=0,end=4),spatial=dict(start=[-.125,0,0],end=[5.125,0,0],bins=21,space='data_local',units='m'),max_gap=1.0),source)
        rows=[row for _,row in self.cache.rows(ref,Context())]
        for k,t in enumerate(times):
            sample=rows[k*21:(k+1)*21];peak=max(range(21),key=lambda i:float(sample[i]['value']))
            self.assertEqual(peak*.25,t)
        support=self.cache.page(ref,kind='support',offset=63,limit=1)['rows'][0]
        self.assertTrue(support['gap_from_previous'])
        from wavez_export.analysis.heatmap_preview import preview,DTYPE
        preview_data=preview(self.cache,dict(result=ref,width=21,height=64),Context())
        self.assertEqual([r['first_time'] for r in preview_data['native_rows']],['0','0.25','1','2.5','4'])
        self.assertEqual([r['row'] for r in preview_data['native_rows']],[0,4,16,40,63])
        raster=np.frombuffer(bytes.fromhex(preview_data['pixels']),dtype=DTYPE).reshape(64,21)
        self.assertEqual(int(raster['finite'].sum()),105)
        self.assertEqual(int(np.count_nonzero(raster[5:16]['finite'])),0)
        self.assertEqual(np.argmax(raster[40]['high']),10)
        with self.assertRaisesRegex(AnalysisError,'16384'):preview(self.cache,dict(result=ref,width=1024,height=512),Context())


if __name__=='__main__':unittest.main()

import copy,hashlib,json,tempfile,unittest
from pathlib import Path
from simscope_export.analysis import SourceSnapshot,AnalysisError
from simscope_export.analysis import selectors as S
from simscope_export.analysis.jobs import execute
from simscope_export.analysis.member_assets import MemberAssets
from simscope_export.analysis.result_store import ResultCache
from simscope_export.analysis.recipes import pack,unpack
from tests.g4.fixtures import traveling_pulse


class MatchedRenderTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.assets=MemberAssets(self.root/'owner/members');self.cache=ResultCache(self.root/'owner/results')
        self.paths=[traveling_pulse(self.root/(side+'.ssc'),time_scale=1 if side=='left' else 2,time_offset=0 if side=='left' else 10) for side in ('left','right')]
        self.hashes=[hashlib.sha256(p.read_bytes()).hexdigest() for p in self.paths]
        self.camera=dict(camera_transform=[[1,0,0],[0,1,0],[0,0,1],[1,0,8]],camera_target=[1,0,0],camera=dict(fov=45,near=.01,far=100,keep_aspect=1),camera_distance=8,yaw=0,pitch=0)
        self.inputs=[]
        for n,path in enumerate(self.paths):
            with SourceSnapshot(path,assets=self.assets) as source:
                definition=S.define(source,dict(key='endpoints',object='p',kind='particle_ids',selector=dict(ids=['0','40'])))
                base=dict(kind='simscope-inspection',version=2,source={k:v for k,v in source.identity().items() if k not in ('uuid','complete_records')}|dict(complete_frames=8),visual=copy.deepcopy(self.camera),sample=dict(requested_time=0 if n==0 else 10),frame_index=0,alpha=0,history_indices=[],layers=[],selections=[])
                payload=dict(base=base,selections=dict(version=1,revision=1,active='endpoints',definitions=[definition],groups=[],overlay=dict(visible=True,show_hidden=True,maximum=256)),analysis=dict(summaries=[],current={},left={},right={},bindings=[],bookmarks=[],layout=dict(series={},member_address='',plot_bins=512,heatmap_width=128,heatmap_height=64)))
                recipe=dict(kind='simscope-inspection',version=3,source=source.identity(),payload=pack(payload),members=[],results=[],bundled_results=True)
                folder=self.root/('recipe-'+str(n));folder.mkdir();file=folder/'inspection.json';file.write_text(json.dumps(recipe))
                self.inputs.append(dict(source=source.identity(),recipe_path=str(file),recipe_sha256=hashlib.sha256(file.read_bytes()).hexdigest(),selection_keys=['endpoints'],object='p',channel='value',time=pack(dict(units='s',reference='common physical origin',scale=1. if n==0 else .5,offset=0. if n==0 else 5.)),value=pack(dict(units='unknown',reference='scalar',scale=1. if n==0 else 2.,offset=0. if n==0 else 1.))))
        self.common=dict(camera=self.camera,coordinates=dict(units='m',reference='same origin and Cartesian axes'),range=[0.,1.],colormap='viridis',timing=dict(start_time=0.,end_time=.75,fps=4,playback_rate=1.),width=640,height=360,quality='high',quota_bytes=256*1024**2)
        self.args=dict(left=self.inputs[0],right=self.inputs[1],common=pack(self.common),opened_paths=[str(p) for p in self.paths],destination=str(self.root/'pair'))

    def tearDown(self):
        self.assertEqual(self.hashes,[hashlib.sha256(p.read_bytes()).hexdigest() for p in self.paths]);self.tmp.cleanup()

    def run_job(self,args=None,**kwargs):
        return execute(dict(version=1,id='matched',scene_revision=1,selection_revision=1,operation='prepare_matched_render',source=self.inputs[0]['source'],arguments=args or self.args),assets=self.assets,results=self.cache,**kwargs)

    def test_independent_exact_clocks_values_identity_and_portable_jobs(self):
        result=self.run_job()['data']['matched_render'];self.assertEqual(result['frames'],3)
        comparison=unpack(json.loads(Path(result['path']).read_text()))
        self.assertNotEqual(comparison['inputs'][0]['source']['uuid'],comparison['inputs'][1]['source']['uuid'])
        jobs=[json.loads(Path(j['path']).read_text()) for j in result['jobs']]
        self.assertEqual([unpack(j['exact_timing'])['start_time'] for j in jobs],[0.,10.])
        self.assertEqual([unpack(j['exact_timing'])['playback_rate'] for j in jobs],[1.,2.])
        self.assertEqual([j['state']['manual_min'] for j in jobs],[0.,-.5]);self.assertEqual([j['state']['manual_max'] for j in jobs],[1.,0.])
        for j in jobs:
            for key in self.camera:self.assertEqual(unpack(j['exact_state'])[key],self.camera[key])
            self.assertEqual(hashlib.sha256(Path(j['inspection_path']).read_bytes()).hexdigest(),j['inspection_sha256'])
            state=unpack(json.loads(Path(j['inspection_path']).read_text())['payload'])
            self.assertEqual(state['selections']['definitions'][0]['selector']['ids'],['0','40']);self.assertEqual(state['analysis']['summaries'],[])
        self.assertFalse((self.root/'pair/status.json').exists())

    def test_explicit_correspondence_source_permissions_units_and_ranges(self):
        cases=[]
        a=copy.deepcopy(self.args);a['right']['selection_keys']=[];cases.append(a)
        a=copy.deepcopy(self.args);a['right']['selection_keys']=['guessed'];cases.append(a)
        a=copy.deepcopy(self.args);a['opened_paths']=a['opened_paths'][:1];cases.append(a)
        a=copy.deepcopy(self.args);a['right']['value']['units']='different';cases.append(a)
        a=copy.deepcopy(self.args);a['right']['value']=pack(dict(units='unknown',reference='scalar',scale=-1.));cases.append(a)
        a=copy.deepcopy(self.args);a['right']['channel']='particle_id';cases.append(a)
        a=copy.deepcopy(self.args);c=copy.deepcopy(self.common);c['quota_bytes']=2*1024**2;a['common']=pack(c);cases.append(a)
        a=copy.deepcopy(self.args);c=copy.deepcopy(self.common);c['timing']['end_time']=5.;a['common']=pack(c);cases.append(a)
        a=copy.deepcopy(self.args);c=copy.deepcopy(self.common);c['coordinates']['units']='mm';a['common']=pack(c);cases.append(a)
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(AnalysisError):self.run_job(args)
                self.assertFalse((self.root/'pair').exists())

    def test_changed_recipe_and_no_replace_publication(self):
        path=Path(self.inputs[1]['recipe_path']);path.write_bytes(path.read_bytes()+b' ')
        with self.assertRaises(AnalysisError):self.run_job()
        self.inputs[1]['recipe_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        self.run_job()
        before=(self.root/'pair/comparison.json').read_bytes()
        with self.assertRaises(AnalysisError):self.run_job()
        self.assertEqual((self.root/'pair/comparison.json').read_bytes(),before)

    def test_cancelled_preparation_never_publishes(self):
        from simscope_export.analysis.contracts import Context
        context=Context(cancelled=lambda:True)
        with self.assertRaises(AnalysisError):self.run_job(context=context)
        self.assertFalse((self.root/'pair').exists())

    def test_recipe_race_after_initial_hash_refuses(self):
        from unittest.mock import patch
        from simscope_export.analysis import recipes
        original=recipes.load
        def changed(*args,**kwargs):
            path=Path(args[1]['path']);path.write_bytes(path.read_bytes()+b' ')
            return original(*args,**kwargs)
        with patch.object(recipes,'load',changed):
            with self.assertRaisesRegex(AnalysisError,'between pin'):self.run_job()
        self.assertFalse((self.root/'pair').exists())


if __name__=='__main__':unittest.main()

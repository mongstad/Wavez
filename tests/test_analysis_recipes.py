import copy,hashlib,json,struct,tempfile,unittest
from pathlib import Path
import numpy as np
import zlib
from wavez_export.analysis import SourceSnapshot,AnalysisError
from wavez_export.analysis import selectors as S
from wavez_export.analysis.recipes import pack,unpack
from wavez_export.analysis.native_analysis import run
from wavez_export.analysis.jobs import execute
from wavez_export.analysis.result_store import ResultCache
from wavez_export.analysis.member_assets import MemberAssets
from tests.g4.fixtures import scene,HIGH_ID


class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.path=scene(self.root/'source.ssc')
        self.assets=MemberAssets(self.root/'owner'/'members');self.cache=ResultCache(self.root/'owner'/'results');self.source=SourceSnapshot(self.path,assets=self.assets)
        self.digest=hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.selection=S.define(self.source,dict(key='exact',object='p',kind='particle_ids',selector=dict(ids=[str(HIGH_ID),str(2**63-1)])))
        self.request=dict(selections=[self.selection],mode='trace',range=dict(axis='native_time',start=0.,end=3.),channels=[dict(channel='value')])
        self.result=run(self.source,self.request,self.cache)['result']
        source={k:v for k,v in self.source.identity().items() if k not in ('uuid','complete_records')}|dict(complete_frames=8)
        base=dict(kind='simscope-inspection',version=2,source=source,visual={},sample=dict(requested_time=.5000000000000001),frame_index=1,alpha=.00000000000000011102230246251565,history_indices=[],layers=[],selections=[])
        selection=dict(version=1,revision=1,active='exact',definitions=[self.selection],groups=[dict(key='group-1',name='Group',revision=1,members=[dict(key='exact',revision=1)])],overlay=dict(visible=True,show_hidden=False,maximum=256))
        summary=dict(result=self.result,request=self.request,operation='analyze',source=self.source.identity(),rows=8,label='Trace',selection_revision=1)
        analysis=dict(summaries=[summary],current=self.result,left={},right={},bindings=[],bookmarks=[],layout=dict(series={},member_address='',plot_bins=512,heatmap_width=128,heatmap_height=64))
        self.recipe=dict(kind='simscope-inspection',version=3,source=self.source.identity(),payload=pack(dict(base=base,selections=selection,analysis=analysis)),members=[],results=[self.result],bundled_results=True)

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0);self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(),self.digest);self.tmp.cleanup()

    def job(self,op,args,*,cache=None,assets=None):
        args=dict(args,opened_paths=[str(self.path)])
        return execute(dict(version=1,id='recipe',scene_revision=1,selection_revision=1,operation=op,source=self.source.identity(),arguments=args),assets=assets or self.assets,results=cache or self.cache)['data']

    def save(self):return self.job('save_recipe',dict(recipe=self.recipe,destination=str(self.root/'bundle')))
    def load(self,**kw):return self.job('load_recipe',dict(path=str(self.root/'bundle'/'inspection.json')),**kw)

    def test_portable_fresh_cache_full_results_exact_times_ids_groups(self):
        self.save();assets=MemberAssets(self.root/'fresh'/'members');cache=ResultCache(self.root/'fresh'/'results')
        loaded=self.load(cache=cache,assets=assets)['recipe'];self.assertEqual(loaded,self.recipe)
        value=unpack(loaded['payload']);self.assertEqual(struct.pack('<d',value['base']['sample']['requested_time']),struct.pack('<d',.5000000000000001))
        self.assertEqual(value['selections']['definitions'][0]['selector']['ids'],[str(HIGH_ID),str(2**63-1)])
        self.assertEqual(cache.page(self.result)['rows'],self.cache.page(self.result)['rows'])
        self.assertFalse((self.root/'bundle'/'status.json').exists())

    def test_asset_backed_members_round_trip_and_missing_refusal(self):
        ref=self.assets.put(np.arange(1025,dtype='i8'),self.source.context)
        definition=S.define(self.source,dict(key='large',object='p',kind='particle_ids',selector=dict(ids_asset=ref)))
        payload=unpack(self.recipe['payload']);payload['selections']['definitions'].append(definition);self.recipe['payload']=pack(payload);self.recipe['members']=[ref]
        self.save();assets=MemberAssets(self.root/'fresh'/'members');cache=ResultCache(self.root/'fresh'/'results');self.load(assets=assets,cache=cache)
        np.testing.assert_array_equal(assets.read(ref,self.source.context),np.arange(1025))
        (self.root/'bundle'/'members'/(ref['sha256']+'.i8')).unlink()
        with self.assertRaises(AnalysisError):self.load()

    def test_unknown_fields_stale_group_and_source_refuse(self):
        cases=[]
        bad=copy.deepcopy(self.recipe);bad['execute']='anything';cases.append(bad)
        bad=copy.deepcopy(self.recipe);bad['source']['uuid']='changed';cases.append(bad)
        bad=copy.deepcopy(self.recipe);payload=unpack(bad['payload']);payload['base']['version']=1;bad['payload']=pack(payload);cases.append(bad)
        bad=copy.deepcopy(self.recipe);bad['payload']['selections']['groups'][0]['members'][0]['revision']=2;cases.append(bad)
        bad=copy.deepcopy(self.recipe);bad['payload']['analysis']['summaries'][0]['request']['guess_clock']=True;cases.append(bad)
        for recipe in cases:
            with self.subTest(recipe=recipe):
                with self.assertRaises(AnalysisError):self.job('save_recipe',dict(recipe=recipe,destination=str(self.root/'refused')))
                self.assertFalse((self.root/'refused').exists())

    def test_exact_float_bits_are_authoritative_and_mismatch_refuses(self):
        with self.assertRaises(AnalysisError):unpack({'x':.1})
        value=pack(.1);value['text']='0.2'
        with self.assertRaises(AnalysisError):unpack(value)
        with self.assertRaises(AnalysisError):unpack(2**63-1)

    def test_result_hash_corruption_and_symlink_escape_refuse(self):
        self.save();directory=self.root/'bundle'/'results'/self.result['id'];manifest=json.loads((directory/'manifest.json').read_text())
        chunk=directory/manifest['artifacts'][0]['path'];chunk.write_bytes(b'corrupt')
        with self.assertRaises(AnalysisError):self.load() # A valid existing cache cannot conceal a damaged bundle.
        assets=MemberAssets(self.root/'fresh'/'members');cache=ResultCache(self.root/'fresh'/'results')
        with self.assertRaises(AnalysisError):self.load(assets=assets,cache=cache)
        chunk.unlink();chunk.symlink_to(self.path)
        with self.assertRaises(AnalysisError):self.load(assets=assets,cache=cache)

    def test_unopened_bookmark_source_refuses_without_read(self):
        payload=unpack(self.recipe['payload']);ref=dict(self.source.identity(),path=str(self.root/'never-opened.ssc'))
        payload['analysis']['bookmarks']=[dict(label='Manual',source=ref,raw_time=dict(text='0',f64_le_hex='0000000000000000'),visual={})]
        self.recipe['payload']=pack(payload)
        with self.assertRaisesRegex(AnalysisError,'Open/select'):self.save()

    def test_optional_results_require_explicit_existing_verified_references(self):
        self.recipe['bundled_results']=False;self.save();self.assertFalse((self.root/'bundle'/'results').exists());self.load()
        cache=ResultCache(self.root/'fresh'/'results')
        with self.assertRaisesRegex(AnalysisError,'unavailable'):self.load(cache=cache)

    def test_frame_sidecar_uses_one_explicit_child_asset_bundle(self):
        self.save();record=dict(self.recipe,asset_directory='bundle');path=self.root/'inspection-00000000.json';path.write_text(json.dumps(record))
        result=self.job('load_recipe',dict(path=str(path)))
        self.assertEqual(result['recipe']['asset_directory'],'bundle')
        for invalid in ['../bundle','..','/bundle','bundle/members']:
            record['asset_directory']=invalid;path.write_text(json.dumps(record))
            with self.assertRaises(AnalysisError):self.job('load_recipe',dict(path=str(path)))

    def test_linked_plot_labels_bindings_and_current_series_round_trip(self):
        row=self.cache.page(self.result)['rows'][0]
        series={k:row[k] for k in ['selection_key','channel','component','statistic','member_key']}
        binding=dict(result=self.result,source=self.source.identity(),series=series,time=dict(units='s',reference='native fixture'),value=dict(units=row['units'],reference='source value'))
        payload=unpack(self.recipe['payload']);payload['analysis']['left']=binding;payload['analysis']['bindings']=[dict(label='Exact member',binding=binding)];payload['analysis']['layout']['series']=series;self.recipe['payload']=pack(payload)
        self.save();self.assertEqual(unpack(self.load()['recipe']['payload'])['analysis'],payload['analysis'])

    def test_png_and_state_bundle_hash_and_changed_image_refusal(self):
        def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
        png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',2,2,8,6,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+b'\xff\xaa\0\xff'*2)*2))+chunk(b'IEND',b'')
        image=self.root/'staging.png';image.write_bytes(png)
        result=self.job('save_recipe',dict(recipe=self.recipe,destination=str(self.root/'bundle'),image=dict(path=str(image))))
        self.assertEqual(result['saved_recipe']['image']['sha256'],hashlib.sha256(png).hexdigest());self.assertEqual((self.root/'bundle/image.png').read_bytes(),png)
        loaded=self.load()['recipe']
        with self.assertRaisesRegex(AnalysisError,'explicit captured PNG'):self.job('save_recipe',dict(recipe=loaded,destination=str(self.root/'dangling')))
        self.assertFalse((self.root/'dangling').exists())
        (self.root/'bundle/image.png').write_bytes(png[:-1]+b'x')
        with self.assertRaisesRegex(AnalysisError,'PNG changed'):self.load()


if __name__=='__main__':unittest.main()

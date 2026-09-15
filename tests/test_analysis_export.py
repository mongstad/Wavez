import csv,hashlib,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
from simscope_export.analysis import SourceSnapshot,Context,AnalysisError
from simscope_export.analysis import selectors as S
from simscope_export.analysis.native_analysis import run as analyze
from simscope_export.analysis.diagnostics import run as import_csv
from simscope_export.analysis.comparisons import run as compare
from simscope_export.analysis.jobs import execute
from simscope_export.analysis.result_store import ResultCache
from simscope_export.analysis.member_assets import MemberAssets
from simscope_export.analysis.atomic_output import Output
from simscope_export.analysis.contracts import MIB
from simscope_export.analysis.input_provenance import verify_inputs
from tests.g4.fixtures import scene,HIGH_ID


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.path=scene(self.root/'source.ssc')
        self.assets=MemberAssets(self.root/'owner'/'members');self.cache=ResultCache(self.root/'owner'/'results');self.source=SourceSnapshot(self.path,assets=self.assets)
        self.original=hashlib.sha256(self.path.read_bytes()).hexdigest()
        self.selection=S.define(self.source,dict(object='p',kind='particle_ids',selector=dict(ids=[str(HIGH_ID),str(2**63-1)])))
        self.result=analyze(self.source,dict(selections=[self.selection],mode='trace',range=dict(axis='native_time',start=0,end=3),channels=[dict(channel='value')]),self.cache)['result']

    def tearDown(self):
        self.source.close();self.assertEqual(self.source.context.used,0);self.assertEqual(self.original,hashlib.sha256(self.path.read_bytes()).hexdigest());self.tmp.cleanup()

    def export(self,result=None,destination='export',context=None,**extra):
        request=dict(version=1,id='export',scene_revision=1,selection_revision=1,operation='export_analysis',source=self.source.identity(),arguments=dict(result=result or self.result,destination=str(self.root/destination))|extra)
        return execute(request,results=self.cache,assets=self.assets,context=context)

    def test_full_csv_exact_ids_values_support_hashes_and_provenance(self):
        reply=self.export();root=self.root/'export';manifest=json.loads((root/'analysis.json').read_text())
        self.assertEqual(reply['data']['export']['completion'],'complete');self.assertEqual(manifest['completion'],'complete')
        self.assertEqual(manifest['row_count'],8)
        with (root/'values.csv').open(newline='') as file:rows=list(csv.DictReader(file))
        expected=self.cache.page(self.result)['rows'];self.assertEqual(rows,expected)
        self.assertEqual({r['entity_id'] for r in rows},{str(HIGH_ID),str(2**63-1)})
        self.assertEqual(len((root/'support.jsonl').read_text().splitlines()),manifest['support_count'])
        for artifact in manifest['artifacts']:self.assertEqual(hashlib.sha256((root/artifact['path']).read_bytes()).hexdigest(),artifact['sha256'])
        self.assertEqual(hashlib.sha256((root/'analysis.json').read_bytes()).hexdigest(),reply['data']['export']['manifest_sha256'])
        self.assertFalse(list(self.root.glob('.export.partial-*')))

    def test_member_assets_portable_or_explicitly_external(self):
        ref=self.assets.put(np.arange(1025,dtype='i8'),self.source.context)
        selection=S.define(self.source,dict(object='p',kind='particle_ids',selector=dict(ids_asset=ref)))
        result=analyze(self.source,dict(selections=[selection],mode='population',range=dict(axis='native_time',start=0,end=0)),self.cache)['result']
        self.export(result);manifest=json.loads((self.root/'export'/'analysis.json').read_text())
        self.assertEqual(manifest['members'][0]['reference'],ref);self.assertFalse(manifest['requires_external_member_assets'])
        self.export(result,destination='without-assets',include_members=False)
        manifest=json.loads((self.root/'without-assets'/'analysis.json').read_text());self.assertTrue(manifest['requires_external_member_assets']);self.assertEqual(manifest['external_members'],[ref])

    def test_existing_destination_and_quota_refuse_without_overwrite(self):
        target=self.root/'existing';target.mkdir();(target/'user.txt').write_text('preserve')
        with self.assertRaisesRegex(AnalysisError,'already exists'):self.export(destination='existing')
        self.assertEqual((target/'user.txt').read_text(),'preserve')
        with self.assertRaisesRegex(AnalysisError,'quota'):self.export(quota_bytes=MIB)
        self.assertFalse((self.root/'export').exists());self.assertFalse(list(self.root.glob('.export.partial-*')))

    def test_concurrent_destination_creation_cannot_be_overwritten(self):
        original=Output.commit
        def claim(output):output.target.mkdir();(output.target/'user.txt').write_text('raced');return original(output)
        with patch.object(Output,'commit',claim):
            with self.assertRaises(AnalysisError):self.export()
        self.assertEqual((self.root/'export'/'user.txt').read_text(),'raced')
        stage=next(self.root.glob('.export.partial-*'))
        self.assertEqual(json.loads((stage/'status.json').read_text())['completion'],'failed')
        self.assertFalse((self.root/'export'/'analysis.json').exists())

    def test_cancellation_leaves_only_explicit_partial_status(self):
        context=Context(cancelled=lambda:bool(list(self.root.glob('.export.partial-*'))))
        with self.assertRaises(AnalysisError):self.export(context=context)
        self.assertFalse((self.root/'export').exists());stage=next(self.root.glob('.export.partial-*'))
        self.assertEqual(json.loads((stage/'status.json').read_text())['completion'],'failed');self.assertEqual(context.used,0)

    def csv_binding(self,source,name,values):
        path=self.root/(name+'.csv');path.write_text('time,value\n'+''.join(f'{i},{v}\n' for i,v in enumerate(values)))
        ref=import_csv(source,dict(path=str(path),key=name,time_column='time',time_units='s',delimiter=',',values=[dict(column='value',dtype='f8',units='K')]),self.cache)['result']
        return dict(source=source.identity(),result=ref,series=dict(selection_key=name,channel='value',component='',statistic='supplied_diagnostic',member_key=''),time=dict(units='s',reference='manual'),value=dict(units='K',reference='manual'))

    def test_transitive_comparison_input_changes_are_detected(self):
        other=SourceSnapshot(scene(self.root/'other.ssc'))
        try:
            left=self.csv_binding(self.source,'left',[1,2]);right=self.csv_binding(other,'right',[2,3])
            comparison=compare(self.source,dict(left=left,right=right,operation='difference',join=dict(mode='exact')),self.cache)['result']
            (self.root/'right.csv').write_text('time,value\n0,5\n1,6\n')
            with self.assertRaisesRegex(AnalysisError,'transitive diagnostic'):self.export(comparison)
            # Reusing the comparison itself in another operation also verifies
            # both original inputs, beyond the primary capture binding.
            with self.assertRaisesRegex(AnalysisError,'transitive diagnostic'):verify_inputs(self.source,self.cache,[comparison])
            self.assertFalse((self.root/'export').exists())
        finally:other.close()

    def test_different_verified_extents_of_same_path_are_all_checked(self):
        path=self.root/'stamp.bin';path.write_bytes(b'first')
        def stamp():
            s=path.stat();return (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
        context=Context();context.verified_source(path,stamp(),('long-prefix',5));path.write_bytes(b'other-data')
        context.verified_source(path,stamp(),('short-prefix',2))
        with self.assertRaisesRegex(AnalysisError,'final verification'):context.verify_publication()


if __name__=='__main__':unittest.main()

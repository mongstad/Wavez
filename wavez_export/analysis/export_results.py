"""Full numerical CSV/support plus provenance manifests, staged off the UI."""
import csv,io,platform
import numpy as np
from .contracts import AnalysisError,MIB,MAX_CONTROL,integer
from .result_store import COLUMNS,read_checked,encoded,CHUNK_BYTES
from .atomic_output import Output
from .input_provenance import verify_inputs
from . import selectors as S


def run(source,arguments,cache,*,provenance=None):
    S.keys(arguments,['result','destination','quota_bytes','include_members'],['result','destination'])
    members=arguments.get('include_members',True)
    if type(members) is not bool:raise AnalysisError('invalid_export','Member asset inclusion must be explicit boolean')
    context=source.context;reference=arguments['result']
    with context.allocation(32*MIB):
        manifest=cache.manifest(reference,context)
        if manifest.get('source')!=source.identity():raise AnalysisError('source_changed','Choose the result\'s explicit source binding for export')
        quota=integer(arguments.get('quota_bytes',256*MIB),'declared export bytes',MIB,64*1024*MIB)
        asset_refs=cache.member_references([reference],context)
        estimated=sum(a['bytes'] for a in manifest['artifacts'])+sum(len(encoded(m)) for _,m in cache.dependencies([reference],context))+MAX_CONTROL+4096
        if members:estimated+=sum(int(a['bytes']) for a in asset_refs)
        if estimated>quota:raise AnalysisError('export_limit','Estimated full numerical export exceeds the explicit output quota')
        verify_inputs(source,cache,[reference])
        output=Output(arguments['destination'],quota,context)
        try:
            directory=cache.directory(reference)
            def chunks(kind):
                if kind=='rows':
                    buffer=io.StringIO(newline='');csv.writer(buffer,lineterminator='\n').writerow(COLUMNS);yield buffer.getvalue().encode()
                for chunk in manifest['artifacts']:
                    if chunk['kind']!=kind:continue
                    context.progress('export_'+kind,chunk['first'],manifest['row_count' if kind=='rows' else 'support_count'])
                    content=read_checked(directory/chunk['path'],chunk['sha256'],CHUNK_BYTES,context)
                    if len(content)!=chunk['bytes']:raise AnalysisError('invalid_result','Result chunk size differs')
                    if kind=='rows':
                        header,separator,content=content.partition(b'\n')
                        if not separator or next(csv.reader([header.decode().rstrip('\r')]),None)!=list(COLUMNS):raise AnalysisError('invalid_result','Invalid source CSV header')
                    yield content
            values=output.write('values.csv',chunks('rows'));support=output.write('support.jsonl',chunks('support'))
            graph=[]
            for ref,base in cache.dependencies([reference],context):
                path=cache.directory(ref)/'manifest.json'
                artifact=output.copy('provenance/'+ref['id']+'.json',path,ref['manifest_sha256'],MAX_CONTROL)
                graph.append(dict(result=ref,artifact=artifact))
            assets=[]
            if members:
                if asset_refs and source.assets is None:raise AnalysisError('invalid_asset','Member asset store unavailable for portable export')
                for ref in asset_refs:
                    path,_shape,size=source.assets.path(ref)
                    artifact=output.copy('members/'+ref['sha256']+'.i8',path,ref['sha256'],size)
                    assets.append(dict(reference=ref,artifact=artifact))
            final=dict(kind='wavez-numerical-export',version=1,completion='complete',result=reference,source=source.identity(),row_count=manifest['row_count'],support_count=manifest['support_count'],
                       values=values,support=support,provenance_graph=graph,members=assets,external_members=asset_refs if not members else [],requires_external_member_assets=bool(asset_refs and not members),
                       columns=[dict(name=name,type='string',interpretation='exact decimal identity; import as text' if name=='entity_id' else 'float64 bit identity (little endian)' if name.endswith('f64_le_hex') else 'locale-independent numerical text, label or explicit status') for name in COLUMNS],
                       scientific_values='Full requested source-derived rows; not plot/GPU previews. Blank numerical cells are unavailable and have explicit reasons; source nonfinite tokens remain explicit.',
                       input_policy='All pinned capture prefixes and supplied CSV hashes verified; exported result does not read future appended records',exporter=dict(provenance=provenance or {},python=platform.python_version(),numpy=np.__version__),artifacts=list(output.artifacts))
            if len(encoded(final))>MAX_CONTROL:raise AnalysisError('control_limit','Export index exceeds 1 MiB; reduce the declared result dependency set')
            index=output.write('analysis.json',[encoded(final)+b'\n'])
            verify_inputs(source,cache,[reference]);source.verify();source.verify_members()
            return dict(export=dict(path=str(output.target),manifest_sha256=index['sha256'],row_count=manifest['row_count'],support_count=manifest['support_count'],bytes=str(output.used),completion='complete'))
        except Exception as exc:
            context.abort_publications(exc)
            raise AnalysisError(getattr(exc,'code','export_failed'),str(exc)+'; incomplete staging: '+str(output.stage)) from exc

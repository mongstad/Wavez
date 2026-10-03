"""Inspection v3: bounded control, explicit opened sources and portable assets.

The native viewer separately validates visual fields against its current schema
before requesting this transaction and again before the first UI mutation.
Scientific arrays are optional immutable result artifacts, never JSON payloads.
"""
from contextlib import contextmanager
import hashlib,json,math,os,re,struct
from pathlib import Path
import numpy as np
from .contracts import AnalysisError,MIB,MAX_CONTROL,integer,request_float,float_token
from . import selectors as S
from .source import SourceSnapshot
from .member_assets import MemberAssets,references_in as member_refs,asset_stamp
from .result_store import ResultCache,references_in,encoded,read_checked,regular,CHUNK_BYTES
from .atomic_output import Output,no_replace
from .input_provenance import verify_inputs

BASE_FIELDS={'kind','version','source','visual','sample','frame_index','alpha','history_indices','layers','normalization','geometry','particle_identity','selections','render'}
PAYLOAD_FIELDS={'base','selections','analysis'}
ANALYSIS_FIELDS={'summaries','current','left','right','bindings','bookmarks','layout'}
ENVELOPE_FIELDS={'kind','version','source','payload','members','results','bundled_results','asset_directory'}


def unpack(value,depth=0):
    if depth>32:raise AnalysisError('invalid_recipe','Inspection nesting exceeds 32')
    if isinstance(value,dict):
        if set(value)=={'text','f64_le_hex'}:
            # Godot uses e.g. "0.0" where Python uses "0". Retain the exact
            # binary value and canonicalize its equivalent text in v3 only.
            if not isinstance(value['f64_le_hex'],str) or not re.fullmatch('[a-f0-9]{16}',value['f64_le_hex']):raise AnalysisError('invalid_recipe','Invalid exact number')
            number=struct.unpack('<d',bytes.fromhex(value['f64_le_hex']))[0]
            try:matching=isinstance(value['text'],str) and float(value['text'])==number
            except ValueError:matching=False
            if not math.isfinite(number) or not matching:raise AnalysisError('invalid_recipe','Exact number text/bits differ')
            return float_token(number)
        if '$f64' in value:
            S.keys(value,['$f64','text'],['$f64','text'])
            if not isinstance(value['$f64'],str) or not re.fullmatch('[a-f0-9]{16}',value['$f64']):raise AnalysisError('invalid_recipe','Invalid exact float token')
            number=struct.unpack('<d',bytes.fromhex(value['$f64']))[0]
            if not math.isfinite(number) or not isinstance(value['text'],str) or float(value['text'])!=number:raise AnalysisError('invalid_recipe','Exact float text/bits differ or are nonfinite')
            return number
        return {k:unpack(v,depth+1) for k,v in value.items()}
    if isinstance(value,list):return [unpack(v,depth+1) for v in value]
    if isinstance(value,float):raise AnalysisError('invalid_recipe','Floating recipe values require binary64 tokens')
    if isinstance(value,int) and not isinstance(value,bool) and abs(value)>2**53-1:raise AnalysisError('invalid_recipe','Large integers require exact decimal strings')
    return value


def pack(value):
    if isinstance(value,float):
        if not math.isfinite(value):raise AnalysisError('invalid_recipe','Nonfinite saved state')
        return {'$f64':struct.pack('<d',value).hex(),'text':format(value,'.17g')}
    if isinstance(value,dict):return {k:pack(v) for k,v in value.items()}
    if isinstance(value,list):return [pack(v) for v in value]
    return value


def opened(arguments):
    paths=arguments.get('opened_paths')
    if not isinstance(paths,list) or not 1<=len(paths)<=128 or any(not isinstance(p,str) or len(p)>4096 or not Path(p).is_absolute() for p in paths):raise AnalysisError('unopened_source','Explicit session-opened paths are required')
    return set(paths)


def authorize(ref,allowed):
    if not isinstance(ref,dict) or ref.get('path') not in allowed:raise AnalysisError('unopened_source','Open/select every referenced capture or CSV explicitly before loading this recipe')


@contextmanager
def bound_source(parent,ref,allowed):
    authorize(ref,allowed)
    if ref==parent.identity():yield parent
    else:
        S.keys(ref,['path','format','uuid','sha256','committed_bytes','complete_records'],['path','format','uuid','sha256','committed_bytes','complete_records'])
        with SourceSnapshot(ref['path'],committed_bytes=ref['committed_bytes'],sha256=ref['sha256'],context=parent.context,memo=parent.memo,assets=parent.assets) as other:
            if other.identity()!=ref:raise AnalysisError('source_changed','Saved source identity differs')
            yield other
            other.verify();other.verify_members()


def selection_state(source,state,allowed):
    S.keys(state,['version','revision','active','definitions','groups','overlay'],['version','revision','active','definitions','groups','overlay'])
    integer(state['version'],'selection version',1,1);integer(state['revision'],'selection revision',0,2**31-1)
    definitions=state['definitions'];groups=state['groups']
    if not isinstance(definitions,list) or len(definitions)>256 or not isinstance(groups,list) or len(groups)>64:raise AnalysisError('invalid_recipe','Selection/group count exceeds bounds')
    found={}
    for definition in definitions:
        candidate=S.validate(source,definition)
        if candidate['kind']=='derived_surface':
            reference=candidate['selector'].get('artifact')
            authorize(reference,allowed)
            from .derived import preview
            preview(source,candidate,candidate['selector']['index'],1)
        if candidate['key'] in found:raise AnalysisError('invalid_recipe','Duplicate selection key')
        found[candidate['key']]=candidate
    if state['active']!='' and state['active'] not in found:raise AnalysisError('invalid_recipe','Unknown active selection')
    seen=set()
    for group in groups:
        S.keys(group,['key','revision','name','members'],['key','revision','name','members'])
        if not isinstance(group['key'],str) or not re.fullmatch('[A-Za-z0-9_-]{1,80}',group['key']) or group['key'] in seen or not isinstance(group['name'],str) or not 1<=len(group['name'])<=128:raise AnalysisError('invalid_recipe','Invalid/duplicate group key/name')
        seen.add(group['key']);integer(group['revision'],'group revision',1,2**31-1)
        if not isinstance(group['members'],list) or len(group['members'])>256:raise AnalysisError('invalid_recipe','Group membership limit')
        members=set()
        for member in group['members']:
            S.keys(member,['key','revision'],['key','revision']);integer(member['revision'],'member revision',1,2**31-1)
            if member['key'] not in found or member['key'] in members or found[member['key']]['revision']!=member['revision']:raise AnalysisError('invalid_recipe','Unknown, duplicate or stale group member')
            members.add(member['key'])
    overlay=state['overlay'];S.keys(overlay,['visible','show_hidden','maximum'],['visible','show_hidden','maximum'])
    if type(overlay['visible']) is not bool or type(overlay['show_hidden']) is not bool:raise AnalysisError('invalid_recipe','Overlay switches must be boolean')
    integer(overlay['maximum'],'combined overlay markers',1,512)


def validate_request(source,operation,request,cache):
    if 'result_bytes' in request:integer(request['result_bytes'],'result byte quota',MIB,2*1024*MIB)
    if operation in ('analyze','space_time'):
        from . import native_analysis,space_time
        (native_analysis if operation=='analyze' else space_time).run(source,request,cache,validate_only=True)
        if operation=='analyze':
            from . import channel_semantics as U
            from .reductions import UNWEIGHTED,WEIGHTED,quantile_parameter
            U.time_unit(source,request.get('time_units'))
            for metric in request.get('metrics',[]):
                if not isinstance(metric,str) or metric not in UNWEIGHTED|WEIGHTED and not quantile_parameter(metric):raise AnalysisError('invalid_recipe','Unsupported saved statistic')
            for definition in request['selections']:
                U.position_unit(source,definition['object'],request.get('position_units'))
                if 'weight' in request:
                    weight=request['weight']
                    if isinstance(weight,dict) and 'geometric' in weight:
                        S.keys(weight,['geometric'],['geometric'])
                        if weight['geometric']!='face_area' or definition['association']!='face':raise AnalysisError('invalid_recipe','Face-area weights require source faces')
                    else:U.declaration(source,definition['object'],weight)
    elif operation=='import_csv':
        from .diagnostics import mapping
        mapping(request)
    elif operation=='estimate_period':
        from .periods import parameters
        from .series_input import validate_selector
        S.keys(request,['result','series','window','options','result_bytes'],['result','series','window','options'])
        validate_selector(request['series']);parameters(request['options']);window=request['window']
        if not isinstance(window,list) or len(window)!=2 or request_float(window[0])>request_float(window[1]):raise AnalysisError('invalid_recipe','Invalid period window')
    elif operation=='compare_series':
        from .comparisons import binding
        from .scheduled_series import schedule
        S.keys(request,['left','right','operation','join','result_bytes'],['left','right','operation','join'])
        if request['operation'] not in ('difference','ratio'):raise AnalysisError('invalid_recipe','Unknown comparison operation')
        left,_=binding(cache,request['left'],source.context);right,_=binding(cache,request['right'],source.context)
        if any(left[p][k]!=right[p][k] for p in ('time','value') for k in ('units','reference')):raise AnalysisError('invalid_recipe','Comparison units/reference differ')
        if request['join'].get('mode')=='schedule':next(schedule(request['join']))
        else:
            S.keys(request['join'],['mode'],['mode'])
            if request['join']['mode']!='exact':raise AnalysisError('invalid_recipe','Unknown comparison join')
    else:raise AnalysisError('invalid_recipe','Unsupported saved analysis operation')


def validate(source,recipe,cache,allowed):
    S.keys(recipe,ENVELOPE_FIELDS,ENVELOPE_FIELDS-{'asset_directory'})
    if 'asset_directory' in recipe and (not isinstance(recipe['asset_directory'],str) or not re.fullmatch('[A-Za-z0-9_-][A-Za-z0-9_.-]{0,79}',recipe['asset_directory'])):raise AnalysisError('invalid_recipe','Asset directory must be a single bounded child name')
    if recipe['kind']!='wavez-inspection':raise AnalysisError('invalid_recipe','Unknown inspection kind')
    integer(recipe['version'],'inspection version',3,3)
    if recipe['source']!=source.identity():raise AnalysisError('source_changed','Open the exact saved source extent; no automatic rebinding')
    payload=unpack(recipe['payload']);S.keys(payload,PAYLOAD_FIELDS,PAYLOAD_FIELDS)
    base=payload['base'];S.keys(base,BASE_FIELDS,['kind','version','source','visual','sample','frame_index','alpha','history_indices','layers','selections'])
    if base['kind']!='wavez-inspection' or base['version']!=2 or base['selections']!=[] or not isinstance(base['visual'],dict):raise AnalysisError('invalid_recipe','Invalid nested native scene state')
    if base['source']!={k:v for k,v in source.identity().items() if k not in ('uuid','complete_records')}|{'complete_frames':base['source'].get('complete_frames')}:raise AnalysisError('source_changed','Nested visual source differs')
    integer(base['source']['complete_frames'],'visual frame count',1,10_000_000)
    integer(base['frame_index'],'visual frame index',0,base['source']['complete_frames']-1)
    if not 0<=request_float(base['alpha'])<=1:raise AnalysisError('invalid_recipe','Invalid display alpha')
    if not isinstance(base['sample'],dict) or not isinstance(base['layers'],list) or len(base['layers'])>64:raise AnalysisError('invalid_recipe','Invalid layer/sample snapshot')
    if not isinstance(base['history_indices'],list) or len(base['history_indices'])>5:raise AnalysisError('invalid_recipe','Invalid visual history')
    for n,index in enumerate(base['history_indices']):
        if integer(index,'history index',0,base['source']['complete_frames']-1)!=base['frame_index']-n-1:raise AnalysisError('invalid_recipe','History must be contiguous preceding frames')
    selection_state(source,payload['selections'],allowed)
    analysis=payload['analysis'];S.keys(analysis,ANALYSIS_FIELDS,ANALYSIS_FIELDS)
    if not isinstance(analysis['summaries'],list) or len(analysis['summaries'])>64 or not isinstance(analysis['bindings'],list) or len(analysis['bindings'])>16 or not isinstance(analysis['bookmarks'],list) or len(analysis['bookmarks'])>256:raise AnalysisError('invalid_recipe','Saved analysis count exceeds bounds')
    expected=references_in(analysis)
    if sorted(recipe['results'],key=lambda r:r['id'])!=sorted(expected,key=lambda r:r['id']):raise AnalysisError('invalid_recipe','Result reference inventory differs')
    # Authorize ALL paths in the graph before opening ANY secondary input.
    for _,manifest in cache.dependencies(expected,source.context):
        authorize(manifest.get('source'),allowed)
        if 'diagnostic_source' in manifest:authorize(manifest['diagnostic_source'],allowed)
    verify_inputs(source,cache,expected)
    seen=set()
    for summary in analysis['summaries']:
        S.keys(summary,['result','request','operation','label','source','rows','selection_revision'],['result','request','operation','label','source','rows','selection_revision'])
        if summary['result']['id'] in seen or not isinstance(summary['label'],str) or len(summary['label'])>256:raise AnalysisError('invalid_recipe','Duplicate result or invalid label')
        seen.add(summary['result']['id']);integer(summary['selection_revision'],'saved selection revision',0,2**31-1)
        manifest=cache.manifest(summary['result'],source.context)
        if summary['source']!=manifest['source'] or integer(summary['rows'],'saved row count',0,100_000_000)!=manifest['row_count']:raise AnalysisError('invalid_recipe','Saved summary differs from its immutable result')
        with bound_source(source,summary['source'],allowed) as current:
            validate_request(current,summary['operation'],summary['request'],cache)
        if summary['operation'] in ('analyze','space_time','estimate_period') and manifest.get('request')!=summary['request']:raise AnalysisError('invalid_recipe','Saved request differs from computed result provenance')
        if summary['operation']=='import_csv':
            from .diagnostics import mapping
            if mapping(summary['request'])!=manifest.get('mapping') or summary['request']['path']!=manifest.get('diagnostic_source',{}).get('path'):raise AnalysisError('invalid_recipe','CSV mapping differs from result provenance')
        if summary['operation']=='compare_series':
            from .comparisons import binding
            inputs=[binding(cache,summary['request'][side],source.context)[0] for side in ('left','right')]
            if inputs!=manifest.get('inputs') or summary['request']['join']!=manifest.get('join') or summary['request']['operation']!=manifest.get('operation'):raise AnalysisError('invalid_recipe','Comparison request differs from provenance')
    if analysis['current'] and analysis['current'].get('id') not in seen:raise AnalysisError('invalid_recipe','Current result must be a saved summary')
    from .comparisons import binding
    for item in [analysis['left'],analysis['right']]:
        if item:binding(cache,item,source.context,arithmetic=False)
    for item in analysis['bindings']:
        S.keys(item,['label','binding'],['label','binding'])
        if not isinstance(item['label'],str) or not 1<=len(item['label'])<=128:raise AnalysisError('invalid_recipe','Each linked plot needs a label')
        binding(cache,item['binding'],source.context,arithmetic=False)
    for bookmark in analysis['bookmarks']:
        S.keys(bookmark,['label','source','raw_time','visual','origin'],['label','source','raw_time','visual'])
        if bookmark.get('origin','manual bookmark')!='manual bookmark':raise AnalysisError('invalid_recipe','Only manual bookmarks belong to G4')
        if not isinstance(bookmark['label'],str) or len(bookmark['label'])>256 or not isinstance(bookmark['visual'],dict):raise AnalysisError('invalid_recipe','Invalid manual bookmark')
        authorize(bookmark['source'],allowed);request_float(bookmark['raw_time'])
        with bound_source(source,bookmark['source'],allowed):pass
    S.keys(analysis['layout'],['series','member_address','plot_bins','heatmap_width','heatmap_height'],['series','member_address','plot_bins','heatmap_width','heatmap_height'])
    from .series_input import validate_selector
    if analysis['layout']['series']:validate_selector(analysis['layout']['series'])
    if not isinstance(analysis['layout']['member_address'],str) or len(analysis['layout']['member_address'])>256:raise AnalysisError('invalid_recipe','Invalid plot member address')
    integer(analysis['layout']['plot_bins'],'plot bins',1,2048);integer(analysis['layout']['heatmap_width'],'heatmap width',1,1024);integer(analysis['layout']['heatmap_height'],'heatmap height',1,512)
    refs=member_refs([payload,*cache.member_references(expected,source.context)])
    if sorted(refs,key=lambda r:r['sha256'])!=sorted(recipe['members'],key=lambda r:r['sha256']):raise AnalysisError('invalid_recipe','Member reference inventory differs')
    if type(recipe['bundled_results']) is not bool:raise AnalysisError('invalid_recipe','Result bundle flag must be boolean')
    for ref in refs:source.member_array(ref)
    source.verify();source.verify_members()
    return payload


def save(source,arguments,cache,*,provenance=None):
    S.keys(arguments,['recipe','destination','quota_bytes','opened_paths','image'],['recipe','destination','opened_paths'])
    with source.context.allocation(32*MIB):
        recipe=arguments['recipe'];allowed=opened(arguments)
        # Include transitive member dependencies even if an input result was
        # forgotten in the viewer but is still required by a retained result.
        if isinstance(recipe,dict) and isinstance(recipe.get('results'),list) and 'payload' in recipe:
            recipe=dict(recipe,members=member_refs([unpack(recipe['payload']),*cache.member_references(recipe['results'],source.context)]))
        validate(source,recipe,cache,allowed)
        if 'image' not in arguments and unpack(recipe['payload'])['base'].get('render',{}).get('image') is not None:raise AnalysisError('invalid_image','Resaving image-backed state requires an explicit captured PNG input; no dangling image reference is published')
        recipe=dict(recipe);recipe.pop('asset_directory',None)
        if len(encoded(recipe))>MAX_CONTROL-65536:raise AnalysisError('control_limit','Recipe exceeds its bounded control allowance')
        output=Output(arguments['destination'],arguments.get('quota_bytes',256*MIB),source.context)
        try:
            image=None
            if 'image' in arguments:
                S.keys(arguments['image'],['path'],['path']);path=Path(arguments['image']['path'])
                if not path.is_absolute():raise AnalysisError('invalid_image','Explicit absolute screenshot input required')
                before=regular(path)
                if before[2]>257*MIB:raise AnalysisError('invalid_image','PNG exceeds bounded screenshot size')
                with path.open('rb') as file:
                    header=file.read(24)
                    if len(header)!=24 or header[:8]!=b'\x89PNG\r\n\x1a\n' or header[12:16]!=b'IHDR':raise AnalysisError('invalid_image','Expected a captured PNG')
                    width,height=struct.unpack('>II',header[16:24])
                    if not 1<=width<=8192 or not 1<=height<=8192:raise AnalysisError('invalid_image','PNG dimensions exceed 8192')
                    file.seek(0);digest=hashlib.sha256()
                    while block:=file.read(MIB):source.context.check();digest.update(block)
                if regular(path)!=before:raise AnalysisError('source_changed','Screenshot changed before bundling')
                artifact=output.copy('image.png',path,digest.hexdigest(),257*MIB)
                image=dict(file='image.png',sha256=artifact['sha256'],width=width,height=height)
                payload=unpack(recipe['payload']);payload['base'].setdefault('render',{})['image']=image;recipe['payload']=pack(payload)
            for ref in recipe['members']:
                path,_,size=source.assets.path(ref);output.copy('members/'+path.name,path,ref['sha256'],size)
            if recipe['bundled_results']:
                for ref,manifest in cache.dependencies(recipe['results'],source.context):
                    directory=cache.directory(ref)
                    output.copy('results/'+ref['id']+'/manifest.json',directory/'manifest.json',ref['manifest_sha256'],MAX_CONTROL)
                    for artifact in manifest['artifacts']:output.copy('results/'+ref['id']+'/'+artifact['path'],directory/artifact['path'],artifact['sha256'],CHUNK_BYTES)
            data=encoded(recipe)
            if len(data)>MAX_CONTROL-65536:raise AnalysisError('control_limit','Image recipe exceeds its control budget')
            descriptor=output.write('inspection.json',[data])
            verify_inputs(source,cache,recipe['results'],members=True)
            return dict(saved_recipe=dict(path=str(output.target/'inspection.json'),sha256=descriptor['sha256'],bytes=descriptor['bytes'],image=image))
        except Exception as exc:source.context.abort_publications(exc);raise


def import_result(cache,bundle,ref,context):
    manifest=bundle.manifest(ref,context);destination=cache.root/ref['id']
    existing=os.path.lexists(destination)
    if existing:cache.manifest(ref,context)
    stage=cache.root/('.pending-'+ref['id'])
    artifacts=[dict(path='manifest.json',sha256=ref['manifest_sha256'],bytes=regular(bundle.directory(ref)/'manifest.json')[2]),*manifest['artifacts']]
    size=sum(int(a['bytes']) for a in artifacts)+4096
    if not existing:
        with cache.quota.reserve(size,len(artifacts)+1,context):
            stage.mkdir();(stage/'reservation.json').write_bytes(encoded(dict(bytes=size,files=len(artifacts)+1)))
    try:
        for artifact in artifacts:
            origin=bundle.directory(ref)/artifact['path'];before=regular(origin)
            data=read_checked(origin,artifact['sha256'],MAX_CONTROL if artifact['path']=='manifest.json' else CHUNK_BYTES,context)
            if existing:read_checked(destination/artifact['path'],artifact['sha256'],MAX_CONTROL if artifact['path']=='manifest.json' else CHUNK_BYTES,context)
            else:
                with (stage/artifact['path']).open('xb') as file:file.write(data);file.flush();os.fsync(file.fileno())
            context.verified_source(origin,before)
        if existing:return
        context.check();context.verify_publication();no_replace(stage,destination)
        (destination/'reservation.json').unlink()
    except Exception:
        if stage.is_dir():
            for path in stage.iterdir():path.unlink()
            stage.rmdir()
        raise


def load(source,arguments,cache,*,provenance=None):
    S.keys(arguments,['path','opened_paths'],['path','opened_paths']);allowed=opened(arguments)
    path=Path(arguments['path'])
    if not path.is_absolute() or path.suffix!='.json' or path.is_symlink() or path.parent.is_symlink():raise AnalysisError('invalid_recipe','Select a JSON inspection within a regular recipe bundle')
    with source.context.allocation(48*MIB):
        before=regular(path)
        if before[2]>MAX_CONTROL-65536:raise AnalysisError('control_limit','Inspection exceeds its control budget')
        data=path.read_bytes()
        if regular(path)!=before:raise AnalysisError('source_changed','Recipe changed while reading')
        source.context.verified_source(path,before)
        try:recipe=json.loads(data)
        except ValueError as exc:raise AnalysisError('invalid_recipe','Malformed inspection JSON') from exc
        # Establish bounded structure/source authorization before reading assets.
        S.keys(recipe,ENVELOPE_FIELDS,ENVELOPE_FIELDS-{'asset_directory'})
        asset_directory=recipe.get('asset_directory')
        if asset_directory is not None and (not isinstance(asset_directory,str) or not re.fullmatch('[A-Za-z0-9_-][A-Za-z0-9_.-]{0,79}',asset_directory)):raise AnalysisError('invalid_recipe','Unsafe asset directory')
        bundle=path.parent/asset_directory if asset_directory else path.parent
        if bundle.is_symlink() or not bundle.is_dir():raise AnalysisError('invalid_recipe','Missing or linked asset bundle')
        if recipe['source']!=source.identity():raise AnalysisError('source_changed','Open the exact saved source extent before restore')
        if not isinstance(recipe['members'],list) or len(recipe['members'])>512 or not isinstance(recipe['results'],list) or len(recipe['results'])>64 or type(recipe['bundled_results']) is not bool:raise AnalysisError('invalid_recipe','Invalid asset inventory')
        for ref in recipe['members']:source.assets.path(ref)
        source.context.retained_members=member_refs([source.context.retained_members,recipe['members']])
        if recipe['members']:
            root=bundle/'members'
            if not root.is_dir() or root.is_symlink():raise AnalysisError('invalid_asset','Missing or linked member directory')
            incoming=MemberAssets(root)
            for ref in recipe['members']:
                asset,_,size=incoming.path(ref);stamp=asset_stamp(asset)
                with source.context.allocation(size*6+MIB):
                    values=incoming.read(ref,source.context)
                    if source.assets.put(values,source.context)!=ref:raise AnalysisError('invalid_asset','Member reference mismatch')
                source.context.verified_source(asset,stamp)
        if recipe['bundled_results'] and recipe['results']:
            root=bundle/'results'
            if not root.is_dir() or root.is_symlink():raise AnalysisError('invalid_result','Missing or linked result directory')
            incoming=ResultCache(root)
            for ref,manifest in incoming.dependencies(recipe['results'],source.context):
                authorize(manifest.get('source'),allowed)
                if 'diagnostic_source' in manifest:authorize(manifest['diagnostic_source'],allowed)
                import_result(cache,incoming,ref,source.context)
        validate(source,recipe,cache,allowed)
        saved=unpack(recipe['payload'])['base'].get('render',{}).get('image')
        if saved is not None:verify_image(path.parent,saved,source.context)
        return dict(recipe=recipe,recipe_sha256=hashlib.sha256(data).hexdigest(),source_stamp=source_stamp(source.path))


def verify_image(root,reference,context):
    S.keys(reference,['file','sha256','width','height','retained_after_encode'],['file','sha256','width','height'])
    if not isinstance(reference['file'],str):raise AnalysisError('invalid_image','Invalid image path')
    relative=Path(reference['file'])
    if relative.is_absolute() or '..' in relative.parts or not 1<=len(relative.parts)<=2:raise AnalysisError('invalid_image','Image must remain inside its selected bundle')
    path=root/relative
    if path.is_symlink() or path.parent.is_symlink():raise AnalysisError('invalid_image','Linked image artifact refused')
    if type(reference.get('retained_after_encode',True)) is not bool:raise AnalysisError('invalid_image','Invalid image retention declaration')
    width=integer(reference['width'],'image width',1,8192);height=integer(reference['height'],'image height',1,8192)
    if not isinstance(reference['sha256'],str) or not re.fullmatch('[a-f0-9]{64}',reference['sha256']):raise AnalysisError('invalid_image','Invalid image hash')
    if not path.exists() and reference.get('retained_after_encode') is False:return
    before=regular(path)
    if before[2]>257*MIB:raise AnalysisError('invalid_image','Image exceeds its size bound')
    with path.open('rb') as file:
        header=file.read(24)
        if len(header)!=24 or header[:8]!=b'\x89PNG\r\n\x1a\n' or header[12:16]!=b'IHDR' or struct.unpack('>II',header[16:24])!=(width,height):raise AnalysisError('invalid_image','PNG dimensions/header differ')
        file.seek(0);digest=hashlib.sha256()
        while block:=file.read(MIB):context.check();digest.update(block)
    if regular(path)!=before or digest.hexdigest()!=reference['sha256']:raise AnalysisError('invalid_image','PNG changed or checksum differs')
    context.verified_source(path,before)


def source_stamp(path):
    info=Path(path).stat()
    def time(ns):return str(ns//1_000_000_000)+'.'+str(ns%1_000_000_000).zfill(9)
    return dict(device=str(info.st_dev),inode=str(info.st_ino),size=str(info.st_size),mtime=time(info.st_mtime_ns),ctime=time(info.st_ctime_ns))

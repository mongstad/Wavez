"""Prepare two explicit, bounded G4 scene jobs for sequential native rendering.

Only control and member assets are copied. Source arrays, clocks and transforms
remain immutable. This is a two-job document, not a persistent render service.
"""
import copy,hashlib,json,math
from pathlib import Path
from . import recipes as R,selectors as S,channel_semantics as U
from .comparisons import mapping
from .contracts import AnalysisError,MIB,MAX_CONTROL,integer,request_float,float_token
from .atomic_output import Output
from .member_assets import references_in
from .result_store import encoded,regular,read_checked

CAMERA={'camera_transform','camera_target','camera','camera_distance','yaw','pitch'}


def common_settings(value):
    value=R.unpack(value)
    S.keys(value,['camera','coordinates','range','colormap','timing','width','height','quality','quota_bytes'],['camera','coordinates','range','colormap','timing','width','height','quality','quota_bytes'])
    camera=value['camera'];S.keys(camera,CAMERA,CAMERA)
    vectors=camera['camera_transform']+[camera['camera_target']] if isinstance(camera.get('camera_transform'),list) else []
    if len(vectors)!=5 or any(not isinstance(v,list) or len(v)!=3 for v in vectors):raise AnalysisError('invalid_comparison','Choose a complete shared camera')
    for vector in vectors:
        for number in vector:request_float(number)
    for key in ('camera_distance','yaw','pitch'):request_float(camera[key])
    S.keys(camera['camera'],['fov','near','far','keep_aspect'],['fov','near','far','keep_aspect'])
    if not 1<=request_float(camera['camera']['fov'])<179 or not 0<request_float(camera['camera']['near'])<request_float(camera['camera']['far']):raise AnalysisError('invalid_comparison','Invalid shared camera clipping/FOV')
    integer(camera['camera']['keep_aspect'],'camera aspect',0,1)
    coordinates=value['coordinates'];S.keys(coordinates,['units','reference'],['units','reference']);U.unit(coordinates['units'])
    if not isinstance(coordinates['reference'],str) or not 1<=len(coordinates['reference'])<=256:raise AnalysisError('invalid_comparison','Declare common viewer-world origin and axes')
    bounds=value['range']
    if not isinstance(bounds,list) or len(bounds)!=2 or request_float(bounds[0])>=request_float(bounds[1]):raise AnalysisError('invalid_comparison','Choose a finite increasing shared value range')
    palettes=json.loads((Path(__file__).resolve().parents[2]/'viewer/colormaps.json').read_text())
    if value['colormap'] not in palettes:raise AnalysisError('invalid_comparison','Unknown shared colormap')
    timing=value['timing'];S.keys(timing,['start_time','end_time','fps','playback_rate'],['start_time','end_time','fps','playback_rate'])
    start,end,rate=(request_float(timing[k]) for k in ('start_time','end_time','playback_rate'))
    fps=integer(timing['fps'],'render FPS',1,240)
    if end<start or rate<=0:raise AnalysisError('invalid_comparison','Invalid aligned render interval/rate')
    count=(end-start)*fps/rate
    if not math.isfinite(count) or count>4000:raise AnalysisError('render_limit','Matched G4 clips are limited to 4000 frames per input')
    frames=max(1,math.ceil(count-1e-9))
    for key in ('width','height'):
        if integer(value[key],key,64,8192)%2:raise AnalysisError('invalid_comparison','Render dimensions must be even')
    if value['quality'] not in ('high','balanced','compact'):raise AnalysisError('invalid_comparison','Unknown render quality')
    quota=integer(value['quota_bytes'],'total pair output quota',2*MIB,64*1024*MIB)
    required=2*(frames*(value['width']*value['height']*8+2*MIB)+16*MIB)+MIB
    if required>quota:raise AnalysisError('render_limit','Pair quota cannot hold the complete requested frame sequences and encoding headroom')
    return value,frames


def prepare_input(parent,item,cache,allowed,common):
    S.keys(item,['source','recipe_path','recipe_sha256','selection_keys','object','channel','time','value'],['source','recipe_path','recipe_sha256','selection_keys','object','channel','time','value'])
    item=dict(item,time=R.unpack(item['time']),value=R.unpack(item['value']))
    R.authorize(item['source'],allowed)
    path=Path(item['recipe_path'])
    if not path.is_absolute():raise AnalysisError('invalid_recipe','Explicit absolute inspection path required')
    before=regular(path);read_checked(path,item['recipe_sha256'],MAX_CONTROL-65536,parent.context)
    parent.context.verified_source(path,before)
    with R.bound_source(parent,item['source'],allowed) as source:
        coordinate_units={oid:U.position_unit(source,oid) for oid in source.objects}
        if any(unit!='unknown' and unit!=common['coordinates']['units'] for unit in coordinate_units.values()):raise AnalysisError('incompatible_units','Known world coordinate units must match; G4 matched scenes do not register or rescale geometry')
        loaded=R.load(source,dict(path=str(path),opened_paths=list(allowed)),cache)
        if loaded['recipe_sha256']!=item['recipe_sha256']:raise AnalysisError('source_changed','Inspection changed between pin verification and validation')
        recipe=loaded['recipe']
        payload=R.unpack(recipe['payload']);keys=item['selection_keys']
        if not isinstance(keys,list) or not 1<=len(keys)<=256 or any(not isinstance(k,str) for k in keys) or len(set(keys))!=len(keys):raise AnalysisError('invalid_comparison','Explicit nonduplicate selection keys are required on both sides')
        found={d['key']:d for d in payload['selections']['definitions']}
        if any(k not in found for k in keys):raise AnalysisError('invalid_comparison','Selection correspondence names an unknown source-scoped key')
        oid=item['object']
        if oid not in source.objects:raise AnalysisError('unknown_object','Choose the scalar display object in each run')
        channel=U.declaration(source,oid,dict(channel=item['channel']))
        if channel['semantic'] not in ('continuous','signed'):raise AnalysisError('unsupported_semantics','Matched affine ranges require continuous or signed scalar channels')
        kind=source.objects[oid]['kind'];found_channel=False
        for row in source.samples[oid]:
            source.context.check()
            for a in row['descriptor']['arrays']:
                if a['name']!=item['channel']:continue
                found_channel=True
                if len(a['shape'])!=(3 if kind=='volume' else 1):raise AnalysisError('invalid_channel','Choose a scalar source channel')
        if not found_channel:raise AnalysisError('invalid_channel','Chosen source channel is unavailable')
        time=mapping(item['time'],time=True);value=mapping(item['value'],time=False)
        for part,original in [('time',U.time_unit(source)),('value',channel['units'])]:
            if original!=item[part]['units'] and 'scale' not in item[part]:raise AnalysisError('incompatible_units','Unit declarations/conversions require an explicit scale')
        scale,offset=request_float(value['scale']),request_float(value['offset'])
        if scale<=0:raise AnalysisError('unsupported_semantics','Matched rendering requires positive value scales; negative mappings remain available in numerical comparisons')
        bounds=[(request_float(v)-offset)/scale for v in common['range']]
        if not all(math.isfinite(v) for v in bounds) or bounds[1]<=bounds[0]:raise AnalysisError('invalid_comparison','Mapped source range is nonfinite or collapsed')
        visual=payload['base']['visual'];visual.update(copy.deepcopy(common['camera']))
        visual.update(orbit_enabled=False,show_legend=False)
        if kind=='particles':
            visual.update(color_channel=item['channel'],normalization_mode='manual',auto_range=False,manual_min=bounds[0],manual_max=bounds[1],colormap_name=common['colormap'],logarithmic=False,cyclic=False,invert_map=False,clamp_map=True)
        else:
            layers=visual.get('scene',{}).get('layers',{})
            if oid not in layers:raise AnalysisError('invalid_recipe','Selected object has no saved layer display state')
            layers[oid].update(channel=item['channel'],lower=bounds[0],upper=bounds[1],colormap=common['colormap'])
        selection=payload['selections'];selection['definitions']=[found[k] for k in keys];selection['active']=keys[0]
        selection['groups']=[dict(g,members=[m for m in g['members'] if m['key'] in keys]) for g in selection['groups'] if any(m['key'] in keys for m in g['members'])]
        payload['analysis']=dict(summaries=[],current={},left={},right={},bindings=[],bookmarks=[],layout=dict(series={},member_address='',plot_bins=512,heatmap_width=128,heatmap_height=64))
        payload['base'].pop('render',None) # A new scene job does not claim the old PNG.
        recipe=dict(recipe,payload=R.pack(payload),results=[],bundled_results=True,members=references_in(payload));recipe.pop('asset_directory',None)
        R.validate(source,recipe,cache,allowed)
        ts,to=request_float(time['scale']),request_float(time['offset']);timing=common['timing']
        raw=dict(start_time=(request_float(timing['start_time'])+to)/ts,end_time=(request_float(timing['end_time'])+to)/ts,fps=timing['fps'],playback_rate=request_float(timing['playback_rate'])/ts)
        if not all(math.isfinite(v) for v in raw.values()):raise AnalysisError('invalid_comparison','Mapped render times are nonfinite')
        first=math.inf;last=-math.inf
        for rows in source.samples.values():
            for row in rows:
                source.context.check();first=min(first,row['time']);last=max(last,row['time'])
        if raw['start_time']<first or raw['end_time']>last:raise AnalysisError('invalid_comparison','Mapped interval is outside the pinned capture clock extent')
        description=dict(source=source.identity(),recipe=dict(path=str(path),sha256=item['recipe_sha256']),selections=selection['definitions'],object=oid,channel=channel,time=time,value=value,source_range=[float_token(v) for v in bounds],source_data_to_world=source.objects[oid]['data_to_world'],source_coordinate_units=coordinate_units)
        return recipe,raw,description


def run(source,arguments,cache,*,provenance=None):
    S.keys(arguments,['left','right','common','opened_paths','destination'],['left','right','common','opened_paths','destination'])
    allowed=R.opened(arguments);common,frames=common_settings(arguments['common'])
    for side in ('left','right'):R.authorize(arguments[side]['source'],allowed)
    if source.identity() not in [arguments[s]['source'] for s in ('left','right')]:raise AnalysisError('source_changed','Current source must be one explicit matched input')
    with source.context.allocation(48*MIB):
        inputs=[prepare_input(source,arguments[s],cache,allowed,common) for s in ('left','right')]
        descriptions=[i[2] for i in inputs]
        for part in ('time','value'):
            if any(descriptions[0][part][k]!=descriptions[1][part][k] for k in ('units','reference')):raise AnalysisError('incompatible_units','Both runs must declare the same common units and reference')
        output=Output(arguments['destination'],common['quota_bytes'],source.context)
        try:
            comparison=dict(kind='simscope-matched-render',version=1,inputs=descriptions,common=common,frames=frames,provenance=provenance or {},selection_correspondence='explicit source-scoped lists; no automatic ID match',coordinate_policy='same declared viewer_world origin/axes/units; original object transforms unchanged',sampling='independent source brackets; scalar hold; position interpolation only where provided by G2/G3',legend='shared mapped bounds and units in comparison.json; native per-source legends suppressed')
            paths=[]
            for side,(recipe,timing,_) in zip(('left','right'),inputs):
                initial_bytes=output.used
                folder=side+'/recipe.inspection/'
                for ref in recipe['members']:
                    path,_,size=source.assets.path(ref);output.copy(folder+'members/'+path.name,path,ref['sha256'],size)
                data=encoded(recipe)
                if len(data)>MAX_CONTROL-65536:raise AnalysisError('control_limit','Matched recipe exceeds control budget')
                artifact=output.write(folder+'inspection.json',[data]);base=R.unpack(recipe['payload'])['base']
                job=dict(version=2,capture_path=recipe['source']['path'],source=base['source'],state=base['visual'],exact_state=R.pack(base['visual']),**timing,exact_timing=R.pack(timing),width=common['width'],height=common['height'],output_path=str(output.target/side/'matched.mp4'),camera_mode='locked',orbit_speed=0.,quality=common['quality'],keep_frames=True,inspection_sidecars=True,inspection_path=str(output.target/folder/'inspection.json'),inspection_sha256=artifact['sha256'],opened_paths=sorted(allowed),output_quota_bytes=str((common['quota_bytes']-MIB)//2),comparison=R.pack(dict(comparison,side=side)))
                raw=encoded(job)
                if len(raw)>MAX_CONTROL-65536:raise AnalysisError('control_limit','Matched job exceeds control budget')
                job_artifact=output.write(side+'/job.json',[raw]);paths.append(dict(path=str(output.target/side/'job.json'),sha256=job_artifact['sha256']))
                if output.used-initial_bytes+frames*(common['width']*common['height']*8+2*MIB)+16*MIB>int(job['output_quota_bytes']):raise AnalysisError('render_limit','Member/control assets and full rendering exceed this input quota')
            artifact=output.write('comparison.json',[encoded(R.pack(comparison))])
            return dict(matched_render=dict(path=str(output.target/'comparison.json'),sha256=artifact['sha256'],jobs=paths,frames=frames,quota_bytes=str(common['quota_bytes'])))
        except Exception as exc:source.context.abort_publications(exc);raise

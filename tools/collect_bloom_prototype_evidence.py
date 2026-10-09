"""Verify and collect #306's bounded experiment; never change captures or images."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image,ImageDraw


def pixels(path):return np.asarray(Image.open(path).convert('RGB'))
def difference(a,b):
    delta=np.abs(pixels(a).astype(int)-pixels(b).astype(int))
    return dict(mean_absolute_rgb_codes=float(delta.mean()),maximum_rgb_codes=int(delta.max()),p99_rgb_codes=float(np.percentile(delta,99)))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runs',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args();base=args.runs;output=args.output_dir;output.mkdir(parents=True,exist_ok=True)
    paths={'source':base/'forward-prototype/prototype.json','package':base/'forward-package/isolation.json','transitions':base/'forward-prototype/transitions.json','native_transitions':base/'accepted-native-transitions/transitions.json','exports':base/'export-prototype-final/report.json'}
    reports={name:json.loads(path.read_text()) for name,path in paths.items()}
    assert reports['source']['cases']==reports['package']['cases']
    screenshot_pairs=[]
    for renderer in ['forward','compatibility']:
        for path in sorted((base/('accepted-'+renderer)).glob('baseline-*.png')):
            result=difference(path,base/('candidate-'+renderer)/path.name);assert result['maximum_rgb_codes']==0
            screenshot_pairs.append(dict(renderer=renderer,image=path.name,**result))
        for kind in ['accepted','candidate']:
            directory=base/(kind+'-'+renderer)
            for suffix in ['json','log']:shutil.copyfile(directory/('baseline.'+suffix),output/(kind+'-'+renderer+'.'+suffix))
    scientific=[]
    source=base/'forward-prototype'
    for case in reports['source']['cases']:
        name=case['scene'];result=difference(source/f'prototype-{name}-Scientific.png',source/f'prototype-{name}-native-Scientific.png')
        assert result['maximum_rgb_codes']==0;scientific.append(dict(scene=name,**result))
    png=difference(source/'prototype-real-image.png',source/'prototype-particles-defaults.png');assert png['maximum_rgb_codes']==0
    calibration=difference(source/'prototype-particles-black-native.png',source/'prototype-particles-black-defaults.png');assert calibration['maximum_rgb_codes']<=1
    backdrop=difference(source/'prototype-particles-native-Cinematic.png',source/'prototype-particles-defaults.png')
    assert backdrop['maximum_rgb_codes']>1 # Disclose the remaining appearance gate.
    changes={}
    for category in ['particles','fields','meshes']:
        changes[category]=difference(source/'prototype-overlap-all.png',source/f'prototype-overlap-zero-{category}.png')
        assert changes[category]['maximum_rgb_codes']>0
    telemetry=json.loads((source/'prototype-device-telemetry.json').read_text())
    benchmarks=[]
    for row in reports['source']['benchmarks']:
        values=[int(sample['process_vram'].split()[0]) for sample in telemetry if row['unix_start']<=sample['time']<=row['unix_end'] and sample['process_vram']]
        benchmarks.append(dict(row,process_vram_peak_mib=max(values) if values else None,process_vram_samples=len(values)))
    summary=dict(accepted_main='65fd8fae15a1b8dd37c75eca3a197d75003ee4ee',candidate_build=80,source_package_hdr_records_identical=True,screenshot_pairs=screenshot_pairs,scientific_bypass_pairs=scientific,native_png_comparison=png,particle_black_calibration=calibration,full_Cinematic_background_difference=backdrop,visible_zero_contribution_changes=changes,benchmarks=benchmarks,process_vram_peak_mib=max(int(sample['process_vram'].split()[0]) for sample in telemetry if sample['process_vram']),device_vram_peak_mib=max(int(sample['gpu'].split(',')[1]) for sample in telemetry if sample['gpu']),device_vram_min_free_mib=min(int(sample['gpu'].split(',')[2]) for sample in telemetry if sample['gpu']),recommendation='Hold production integration: full Cinematic appearance and resource/transition costs need owner review and another bounded prototype.')
    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    for name,path in paths.items():shutil.copyfile(path,output/(name+'.json'))
    for name,path in [('source-native.log',source/'prototype.log'),('transition-native.log',source/'transitions.log'),('accepted-transition-native.log',base/'accepted-native-transitions/transitions.log'),('package-native.log',base/'forward-package/isolation.log'),('device-telemetry.json',source/'prototype-device-telemetry.json'),('temporary-worker.patch',base/'export-prototype-final/temporary-worker.patch')]:shutil.copyfile(path,output/name)
    for directory in (base/'export-prototype-final').iterdir():
        if directory.is_dir() and (directory/'native.log').exists():
            destination=output/'exports'/directory.name;destination.mkdir(parents=True,exist_ok=True)
            for name in ['native.log','timing.jsonl','progress.json','metrics.json']:shutil.copyfile(directory/name,destination/name)
    for name in ['overlap-all','overlap-zero-particles','overlap-zero-fields','overlap-zero-meshes','occluded-all','slice-all','iso-all','overlap-Scientific','particles-native-Cinematic','particles-defaults','particles-black-native','particles-black-defaults','real-image','heavy-3840-all']:
        shutil.copyfile(source/('prototype-'+name+'.png'),output/(name+'.png'))
    # A labeled crop contact sheet from actual screenshots, without synthesized pixels.
    sheet=Image.new('RGB',(1200,660),'#10111b');draw=ImageDraw.Draw(sheet)
    for i,(file,label) in enumerate([('overlap-all','P=1.35 F=1 M=1'),('overlap-zero-particles','P=0 F=1 M=1'),('overlap-zero-fields','P=1.35 F=0 M=1'),('overlap-zero-meshes','P=1.35 F=1 M=0'),('slice-all','Slice + particles + mesh'),('iso-all','Derived isosurface + P + M'),('occluded-all','Opaque occlusion: P/F=0 radiance'),('overlap-Scientific','Scientific: native pixels, no targets')]):
        x=(i%4)*300;y=(i//4)*330
        image=Image.open(output/(file+'.png')).convert('RGB').crop((330,170,630,470));sheet.paste(image,(x,y+30));draw.text((x+8,y+8),label,fill='white')
    sheet.save(output/'mixed-scenes.png')
    sheet=Image.new('RGB',(1200,330),'#10111b');draw=ImageDraw.Draw(sheet)
    for i,(file,label) in enumerate([('particles-black-native','Native: black calibration'),('particles-black-defaults','Prototype: P=1.35 (max delta 1)'),('particles-native-Cinematic','Native: full Cinematic'),('particles-defaults','Prototype: background gate open')]):
        image=Image.open(output/(file+'.png')).convert('RGB').crop((330,170,630,470));sheet.paste(image,(i*300,30));draw.text((i*300+8,8),label,fill='white')
    sheet.save(output/'particle-calibration.png')
    os.environ.setdefault('MPLCONFIGDIR','/tmp/wavez-306-matplotlib')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    rows=[row for row in benchmarks if not row['moving_samples'] and row['resolution']==[3840,2160] and row['label'] in ['accepted-native-render-only','particle-default-render-only','all-enabled-render-only','all-zero-render-only']]
    fig,axes=plt.subplots(1,2,figsize=(10,3.8),layout='constrained')
    labels=['Native Cine','P default','P/F/M enabled','All zero']
    axes[0].bar(labels,[row['gpu_ms_median'] for row in rows],color=['#777a9d','#8387ee','#ba7fdc','#629faf']);axes[0].set_ylabel('GPU milliseconds (median)');axes[0].set_title('True offscreen 3840 x 2160, RTX 3070 Ti')
    axes[1].bar(labels,[(row['texture_bytes']+row['buffer_bytes'])/2**20 for row in rows],color=['#777a9d','#8387ee','#ba7fdc','#629faf']);axes[1].set_ylabel('Godot reported texture + buffer MiB');axes[1].set_title('GPU resource accounting, not total process VRAM')
    for ax in axes:ax.tick_params(axis='x',rotation=15);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
    fig.savefig(output/'4k-costs.png',dpi=160);plt.close(fig)
    inventory={str(path.relative_to(output)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(output.rglob('*')) if path.is_file() and path.name!='sha256.json'}
    (output/'sha256.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print('Collected verified HDR, pixels, native exports, telemetry and visual evidence')


if __name__=='__main__':main()

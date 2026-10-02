"""Progressive wheel zoom on all SSC layers, external mesh and Linux packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.validate_render_pacing import fixtures
from tools.validate_rounded_surfaces import run


def digest(path):
    with path.open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--capture', type=Path)
    p.add_argument('--renderer', choices=['forward_plus','gl_compatibility'], required=True)
    p.add_argument('--export', action='store_true')
    a = p.parse_args(); out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    for name, scale in [('small',.001),('large',10000.)]:
        with SceneCapture(out/(name+'.ssc'), objects=[dict(id='mesh',kind='mesh',identity='stable_topology',units='m')],compression='none') as writer:
            for time in [0.,.5,1.]:
                points = (np.array([[-2,0,0],[2,0,0],[0,3,1]],dtype='f8')+[0,0,time])*scale
                writer.add_mesh('mesh',time,points,np.array([[0,1,2]]),vertex_channels=dict(vertex_id=np.array([7,8,9],dtype='i8')))
    sources = list(out.glob('*.ssc')) + ([a.capture.resolve()] if a.capture else [])
    before = {str(p):digest(p) for p in sources}
    env = os.environ.copy(); env['XDG_CONFIG_HOME'] = str(out/'config')
    if a.export:
        project = out/'export-source'; shutil.copytree(ROOT/'viewer',project,ignore=shutil.ignore_patterns('.godot'))
        with (project/'project.godot').open('a') as f:f.write('\n[autoload]\nZoomValidation="*res://ui/shell/test_wheel_zoom.gd"\n')
        (project/'export_presets.cfg').write_text('[preset.0]\nname="Zoom validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        binary = out/'wavez.x86_64'
        for label, options in [('import',['--editor','--import','--quit']),('export',['--export-release','Zoom validation',str(binary)])]:
            run([a.godot,'--headless','--path',str(project),*options],out,label,env)
        command = [str(binary)]
    else:
        run([a.godot,'--headless','--path',str(ROOT/'viewer'),'--editor','--import','--quit'],out,'import',env)
        command = [a.godot,'--path',str(ROOT/'viewer'),'--script','res://ui/shell/run_wheel_zoom_tests.gd']
    env['XDG_DATA_HOME'] = str(out/'profile')
    command += ['--rendering-method',a.renderer,'--display-driver','wayland','--audio-driver','Dummy','--resolution','1440x900','--','--zoom-output='+str(out)]
    if a.capture: command.append('--zoom-capture='+str(a.capture.resolve()))
    diagnostics = run(command,out,'native',env,wayland=True,known_packaged_window_cleanup=a.export)
    report = json.loads((out/'zoom-report.json').read_text())
    assert not report['failures'], report['failures']
    assert report['packaged'] == a.export
    assert before == {str(p):digest(p) for p in sources}
    report.update(source_hashes_unchanged=before,known_engine_diagnostics=diagnostics)
    (out/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Wheel zoom: {report["checks"]} PASS ({a.renderer}, packaged={a.export})')

if __name__ == '__main__': main()

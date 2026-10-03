"""Compare empty sky-only and loaded scientific pixels with accepted main."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_render_pacing import fixtures
from tools.validate_rounded_surfaces import run


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--reference-root', type=Path)
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    p.add_argument('--export', action='store_true')
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    projects = [('candidate', ROOT)]
    if a.reference_root:
        projects.insert(0, ('reference', a.reference_root.resolve()))
        for name in ['test_empty_background.gd', 'run_empty_background_tests.gd']:
            shutil.copy2(ROOT/'viewer/ui/shell'/name, a.reference_root/'viewer/ui/shell'/name)
    reports = {}
    for name, project in projects:
        folder = out/name; folder.mkdir(); fixtures(folder)
        (folder/'invalid.wvz').write_bytes(b'not a WVZ1 capture')
        before = {x.name: hashlib.sha256(x.read_bytes()).hexdigest() for x in folder.glob('*.wvz')}
        env = os.environ.copy(); env['XDG_CONFIG_HOME'] = str(folder/'config')
        if a.export:
            exported = folder/'export-source'; shutil.copytree(project/'viewer', exported, ignore=shutil.ignore_patterns('.godot'))
            with (exported/'project.godot').open('a') as f:
                f.write('\n[autoload]\nEmptyValidation="*res://ui/shell/test_empty_background.gd"\n')
            (exported/'export_presets.cfg').write_text('[preset.0]\nname="Empty validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
            binary = folder/'wavez.x86_64'
            for label, options in [('import', ['--editor', '--import', '--quit']), ('export', ['--export-release', 'Empty validation', str(binary)])]:
                run([a.godot, '--headless', '--path', str(exported), *options], folder, label, env)
            command = [str(binary)]
        else:
            run([a.godot, '--headless', '--path', str(project/'viewer'), '--editor', '--import', '--quit'], folder, 'import', env)
            command = [a.godot, '--path', str(project/'viewer'), '--script', 'res://ui/shell/run_empty_background_tests.gd']
        env['XDG_DATA_HOME'] = str(folder/'profile')
        command += ['--rendering-method', a.renderer, '--display-driver', 'wayland', '--audio-driver', 'Dummy', '--resolution', '1440x900', '--', '--empty-output='+str(folder)]
        if name == 'reference': command.append('--reference')
        diagnostics = run(command, folder, 'native', env, wayland=True, known_packaged_window_cleanup=a.export)
        report = json.loads((folder/'empty-report.json').read_text())
        assert not report['failures'], report['failures']
        assert report['packaged'] == a.export
        assert before == {x.name: hashlib.sha256(x.read_bytes()).hexdigest() for x in folder.glob('*.wvz')}
        report.update(source_hashes_unchanged=before, known_engine_diagnostics=diagnostics)
        (folder/'validation.json').write_text(json.dumps(report, indent=2)+'\n'); reports[name] = report
    comparisons = {}
    if 'reference' in reports:
        assert reports['reference']['sky_shader'] == reports['candidate']['sky_shader']
        assert reports['reference']['environment'] == reports['candidate']['environment']
        assert reports['reference']['loaded'] == reports['candidate']['loaded']
        for picture in [*['empty-'+x for x in ['1440-1.0', '3840-2.0', '3840-2.5']], *[k+'-'+m for k in ['particles','field','mesh','mixed'] for m in ['cinematic','scientific']]]:
            # Exclude shell/status and any BUILD text; compare the actual scene area.
            left = np.asarray(Image.open(out/'reference'/(picture+'.png')))
            right = np.asarray(Image.open(out/'candidate'/(picture+'.png')))
            scale = 2 if '3840-2.0' in picture else 2.5 if '3840-2.5' in picture else 1
            crop = (slice(int(80*scale), int(720*scale)), slice(int(32*scale), int(1000*scale)))
            assert left.shape == right.shape and np.array_equal(left[crop], right[crop]), 'Scene pixels differ: '+picture
            comparisons[picture] = int(left[crop].size)
    summary = dict(renderer=a.renderer, packaged=a.export, checks={k:v['checks'] for k,v in reports.items()}, exact_scene_pixel_comparisons=comparisons, idle={k:v['idle'] for k,v in reports.items()}, failures=[])
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, indent=2))

if __name__ == '__main__': main()

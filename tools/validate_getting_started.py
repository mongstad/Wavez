"""Run the four onboarding scripts, verify source values, then inspect GPU output."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
from wavez_export import SceneReader
from tools.verify_wvz import verify
from tools.package_linux import stage, build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--example-python', default=sys.executable,
                        help='Python with installed wavez-export; scripts run outside checkout')
    parser.add_argument('--godot', help='Omit for Python-only verification')
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    if args.package and not args.godot: parser.error('--package requires --godot')
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ)
    env.pop('PYTHONPATH', None)
    expected = {'particles': {'points': 3}, 'field': {'field': 3},
                'mesh': {'triangle': 3}, 'combined': {'points': 3, 'field': 2, 'triangle': 1}}
    captures = {}
    for name, counts in expected.items():
        path = out / (name+'.wvz')
        command = [args.example_python, str(ROOT / 'examples' / ('getting_started_'+name+'.py')), '--output', str(path)]
        run = subprocess.run(command, cwd=out, env=env, text=True, capture_output=True, timeout=30)
        (out / (name+'-python.txt')).write_text(run.stdout+run.stderr)
        assert run.returncode == 0, run.stderr
        assert verify(path) == sum(counts.values())
        with SceneReader(path) as reader:
            assert reader.audit_identity()
            assert {key:len(value) for key,value in reader.samples.items()} == counts
            assert reader.times == [0.0, 0.5, 1.0]
            for object_id, records in reader.samples.items():
                for i, record in enumerate(records):
                    data = reader.read_sample(object_id, i)
                    time = record['time']
                    assert data['position' if object_id != 'field' else 'amplitude'].dtype == np.dtype('f8')
                    if object_id == 'points':
                        base = np.array([[-.8,0,.7], [0,.4,.7], [.8,0,.7]]) if name == 'combined' else np.array([[-.8,0,0], [0,.4,0], [.8,0,0]])
                        np.testing.assert_array_equal(data['position'], base+[0,time*(.2 if name == 'combined' else 1),0])
                        np.testing.assert_array_equal(data['particle_id'], [10,20,30])
                    elif object_id == 'field':
                        assert data['amplitude'].shape == (5,7,11)
                        assert record['descriptor']['geometry']['origin'] == [-1,-.75,-.5]
                        assert record['descriptor']['geometry']['spacing'] == [.2,.25,.25]
                        # A known node catches an xyz/zyx mix-up independently of rendering.
                        expected_value = np.exp(-4*((0-.3*time)**2 + 0**2 + 0**2))
                        assert np.isclose(reader.probe('field', i, 'amplitude', [0,0,0]), expected_value)
                    else:
                        np.testing.assert_array_equal(data['triangles'], [[0,1,2]])
                        if name == 'mesh':
                            np.testing.assert_array_equal(data['vertex_id'], [100,200,300])
                            np.testing.assert_array_equal(data['position'], [[-.8,-.5,0],[.8,-.5,0],[.4*time,.7,0]])
                        else:
                            np.testing.assert_array_equal(data['position'], [[-1,-.9,-.8],[0,-.9,1],[1,-.9,-.8]])
            if name == 'combined':
                assert reader.bracket('field', .5)[0] == 0
                assert reader.bracket('triangle', .5)[3] == 'static'
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        repeat = subprocess.run(command, cwd=out, env=env, text=True, capture_output=True, timeout=30)
        assert repeat.returncode != 0 and 'FileExistsError' in repeat.stderr
        assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
        captures[name] = {'records':sum(counts.values()), 'sha256':digest,
                          'strict_integrity_identity_source_values_and_overwrite_refusal':'passed'}
    summary = {'captures':captures, 'python':subprocess.check_output([args.example_python,'--version'], text=True).strip()}
    if args.godot:
        runtime_env = dict(env, XDG_CONFIG_HOME=str(out/'config'), XDG_DATA_HOME=str(out/'profile'))
        if args.package:
            project = out/'export-source'
            stage(project)
            with (project/'project.godot').open('a') as config:
                config.write('\n[autoload]\nGettingStarted="*res://layers/test_getting_started.gd"\n')
            executable = out/'WAVEZ.x86_64'
            build(args.godot, project, executable, out/'build-logs')
            shutil.rmtree(project)
            # Empty PATH proves this route cannot find an external Godot/Python.
            (out/'empty-path').mkdir()
            runtime_env.update(PATH=str(out/'empty-path'), PYTHONPATH='')
            command = [str(executable)]
        else:
            command = [args.godot, '--path',str(ROOT/'viewer'), '--script','res://layers/run_getting_started_tests.gd']
        command += ['--rendering-method',args.renderer, '--resolution','1200x800', '--audio-driver','Dummy', '--', '--getting-output='+str(out)]
        run = subprocess.run(command, cwd=out, env=runtime_env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (out/'viewer.txt').write_text(run.stdout)
        summary['viewer'] = json.loads((out/'viewer-report.json').read_text())
        summary['process_exit_code'] = run.returncode
        summary['runtime_log_clean'] = not any(word in run.stdout for word in ['ERROR:', 'WARNING:'])
        summary['capture_hashes_unchanged'] = all(hashlib.sha256((out/(name+'.wvz')).read_bytes()).hexdigest() == item['sha256'] for name,item in captures.items())
        if args.package:
            summary['package_sha256'] = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [executable,executable.with_suffix('.pck')]}
        (out/'validation.json').write_text(json.dumps(summary,indent=2)+'\n')
        assert run.returncode == 0 and not summary['viewer']['failures'], run.stdout[-4000:]
        assert summary['capture_hashes_unchanged']
        assert summary['runtime_log_clean'], f'Checks passed but runtime diagnostics prevent a clean result: {out}/viewer.txt'
    else:
        (out/'validation.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(f'Getting Started: four examples / 15 records verified; GPU={bool(args.godot)}, packaged={args.package}')


if __name__ == '__main__':
    main()

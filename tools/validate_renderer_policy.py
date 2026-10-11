"""Exercise real source/release startup and worker refusals without a scene load."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REQUIREMENT = 'Wavez requires Forward+ Vulkan'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--packaged-binary', type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, XDG_CONFIG_HOME=str(out/'profile/config'), XDG_DATA_HOME=str(out/'profile/data'))
    checks = []

    def check(ok, label):
        checks.append(dict(ok=bool(ok), label=label))
        if not ok: print('FAIL: ' + label, flush=True)

    def run(name, command, environment=None):
        result = subprocess.run(command, env=env if environment is None else environment, cwd=out, capture_output=True, text=True, timeout=45)
        log = result.stdout + result.stderr
        (out/(name+'.log')).write_text(log)
        check('SCRIPT ERROR:' not in log, name + ': no script errors')
        return result.returncode, log

    base = [args.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy']
    for name, flags in [('cpu', ['--headless']), ('gpu', ['--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan'])]:
        folder = out/name
        folder.mkdir()
        code, log = run(name, base+flags+['--script', 'test_renderer_policy.gd', '--', str(folder)])
        report = json.loads((folder/'report.json').read_text())
        check(code == 0 and report['failures'] == 0, name + ': policy assertions pass')
        checks.extend(report['checks'])
    runtimes = [('source', base)]
    if args.packaged_binary:
        runtimes.append(('release', [str(args.packaged_binary.resolve()), '--audio-driver', 'Dummy']))
    # Capture and dismiss only this deliberately injected engine startup alert.
    # No Vulkan ICD is visible to these child processes; the host is unchanged.
    dialogs = out/'engine-dialog-stubs'
    dialogs.mkdir()
    for name in ['zenity', 'kdialog', 'xmessage']:
        stub = dialogs/name
        # Paths come from this fresh output directory. Shell quote apostrophes.
        alert_path = "'" + str(out/'engine-alert.txt').replace("'", "'\\''") + "'"
        stub.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> '+alert_path+'\nexit 0\n')
        stub.chmod(0o755)
    unavailable = dict(env, VK_DRIVER_FILES=str(out/'missing-icd.json'),
                       VK_ICD_FILENAMES=str(out/'missing-icd.json'), PATH=str(dialogs)+':'+env['PATH'])
    for runtime, command in runtimes:
        # No renderer override: defaults in the real project/PCK must be enough.
        code, log = run(runtime+'-default', command+['--quit-after', '8'])
        check(code == 0 and 'Vulkan' in log and 'Forward+' in log, runtime + ': default starts Forward+ Vulkan')
        code, log = run(runtime+'-missing-vulkan', command+['--quit-after', '8'], unavailable)
        check(code == 1 and 'Could not initialize vulkan' in log and 'OpenGL API' not in log, runtime + ': unavailable Vulkan exits without OpenGL fallback')
        for method, flags in [('compatibility', ['--rendering-method', 'gl_compatibility']),
                              ('mobile', ['--rendering-method', 'mobile', '--rendering-driver', 'vulkan']),
                              ('headless', ['--headless'])]:
            code, log = run(runtime+'-'+method, command+flags+['--quit-after', '8'])
            check(code == 1 and REQUIREMENT in log, runtime + ': unsupported '+method+' exits with explanation')
            folder = out/(runtime+'-worker-'+method)
            folder.mkdir()
            job = folder/'job.json'
            job.write_text('{}')
            code, log = run(runtime+'-worker-'+method, command+flags+['--', '--wavez-render-job='+str(job)])
            progress = json.loads((folder/'progress.json').read_text())
            check(code == 1 and progress['stage'] == 'failed' and REQUIREMENT in progress['message'], runtime + ': worker '+method+' records refusal')
            check(not (folder/'frames').exists(), runtime + ': rejected worker makes no rendered frames')
    failures = sum(not row['ok'] for row in checks)
    (out/'report.json').write_text(json.dumps(dict(checks=checks, failures=failures), indent=2)+'\n')
    print(f'Renderer startup: {len(checks)} checks, {failures} failures', flush=True)
    raise SystemExit(bool(failures))


if __name__ == '__main__': main()

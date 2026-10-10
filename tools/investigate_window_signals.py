"""Reproduce #335 without suppressing diagnostics; Linux source/debug/release probes.

Use --source-root with a read-only git archive for matched accepted-main runs.
Nonzero exit means diagnostics or functional failures remain, even when expected.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, PRESET


def diagnostic_counts(log):
    counts = {}
    for operation, pattern in {
        'disconnect': r"ERROR: Attempt to disconnect a nonexistent connection from 'root:<Window#\d+>'\. Signal: '(focus_entered|tree_exited)', callable: '.*'\.",
        'duplicate_connect': r"ERROR: Signal '(focus_entered|tree_exited)' is already connected to given callable '.*' in that object\.",
    }.items():
        counts[operation] = {signal: len(re.findall(pattern.replace('(focus_entered|tree_exited)', signal), log))
                             for signal in ['focus_entered', 'tree_exited']}
    classified = sum(sum(group.values()) for group in counts.values())
    return dict(classified=counts, classified_total=classified,
                error_total=len(re.findall(r'^ERROR:', log, re.M)),
                warning_total=len(re.findall(r'^WARNING:', log, re.M)),
                script_error_total=len(re.findall(r'^SCRIPT ERROR:', log, re.M)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    parser.add_argument('--mode', choices=['minimal', 'baseline-smoke', 'workflow'], required=True)
    parser.add_argument('--runtime', choices=['source', 'debug', 'release'], required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    project = out / 'project'
    source = args.source_root.resolve()
    probe = ROOT / 'viewer/ui/shell/test_window_signals.gd'
    if args.mode == 'minimal':
        project.mkdir()
        (project / 'project.godot').write_text('[application]\nconfig/name="Window signal probe"\nrun/main_scene="res://Probe.tscn"\n')
        (project / 'Probe.tscn').write_text('[gd_scene format=3]\n[node name="Probe" type="Node"]\n')
        (project / 'export_presets.cfg').write_text(PRESET)
    else:
        stage(project, source)
        scene(out / 'mixed.wvz')
        fixture(out / 'fields.wvz', ['volume'])
    shutil.copyfile(probe, project / 'signal_probe.gd')
    with (project / 'project.godot').open('a') as config:
        config.write('\n[autoload]\nWindowSignalProbe="*res://signal_probe.gd"\n')
    env = dict(os.environ, XDG_CONFIG_HOME=str(out / 'config'))
    binary = out / 'WAVEZ.x86_64'
    for name, arguments in [('import', ['--editor', '--import'])] + ([] if args.runtime == 'source' else
            [('export', ['--export-'+args.runtime, 'Wavez Linux', str(binary)])]):
        run = subprocess.run([args.godot, '--headless', '--path', str(project), *arguments], env=env,
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        (out / (name+'.log')).write_text(run.stdout)
        if run.returncode or 'ERROR:' in run.stdout:
            raise RuntimeError(f'{name} failed: {out / (name+".log")}')
    command = [args.godot, '--path', str(project)] if args.runtime == 'source' else [str(binary)]
    command += ['--audio-driver', 'Dummy', '--rendering-method', args.renderer, '--resolution', '1440x900',
                '--', '--signals-mode='+args.mode, '--signals-output='+str(out)]
    # Linux line buffering preserves action/error order. Keep every raw diagnostic.
    command = ['stdbuf', '-oL', '-eL', *command]
    env['XDG_DATA_HOME'] = str(out / 'profile')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    run = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    (out / 'native.log').write_text(run.stdout)
    report = json.loads((out / 'report.json').read_text())
    counts = diagnostic_counts(run.stdout)
    changed = hashes != {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    paths = [probe] if args.mode == 'minimal' else [probe, *[source / p for p in
             ['viewer/main.gd', 'viewer/ui/shell/viewer_shell.gd', 'viewer/selection/selection_controller.gd', 'viewer/project.godot']]]
    summary = dict(mode=args.mode, runtime=args.runtime, renderer=args.renderer, command=command,
                   process_exit_code=run.returncode, source_sha256=hashes, source_changed=changed,
                   source_files_sha256={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
                   diagnostics=counts, report=report)
    if args.runtime != 'source':
        summary['artifacts'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [binary, binary.with_suffix('.pck')]}
    failed = bool(run.returncode or report['failures'] or changed or counts['error_total'] or
                  counts['warning_total'] or counts['script_error_total'])
    summary['strict_exit_code'] = int(failed)
    (out / 'validation.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(f'{args.mode}/{args.runtime}/{args.renderer}: {report["checks"]} functional checks, '
          f'{len(report["failures"])} failures, {counts["error_total"]} errors; strict exit {int(failed)}')
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())

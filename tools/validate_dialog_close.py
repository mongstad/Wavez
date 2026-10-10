"""Focused shared dialog-close visuals, input and geometry checks for issue #314."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build


def compare_layouts(before, after):
    """Only the candidate identity and orbit X glyph may change in the layouts."""
    assert before.keys() == after.keys()
    for name, original in before.items():
        actual = after[name]
        assert original['size'] == actual['size'], name
        assert original['close_size'] == actual['close_size'], name
        assert original['focus_owner'] == actual['focus_owner'], name
        assert len(original['layout']) == len(actual['layout']), name
        for old, new in zip(original['layout'], actual['layout']):
            assert old[:3] == new[:3], (name, old, new)
            if name.startswith('about-') and old[0] == 'Label' and re.fullmatch(r'WAVEZ v\d+\.\d+\.\d+\.\d+', old[3]):
                assert re.fullmatch(r'WAVEZ v\d+\.\d+\.\d+\.\d+', new[3])
            elif name.startswith('orbit-') and old[0] == 'Button' and old[3] == '×':
                assert new[3] == ''
            else:
                assert old[3] == new[3], (name, old, new)
    return len(before)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--package', action='store_true')
    parser.add_argument('--packaged-binary', type=Path, help='Reuse an already exported close-review package')
    parser.add_argument('--compare-report', type=Path, help='Assert unchanged layout/content/focus against a baseline report')
    args = parser.parse_args()
    source = args.source.resolve()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    capture = out / 'mixed.wvz'
    fixture(capture, ['particles', 'volume', 'mesh'])
    digest = hashlib.sha256(capture.read_bytes()).hexdigest()
    environment = dict(os.environ, XDG_DATA_HOME=str(out / 'profile'), XDG_CONFIG_HOME=str(out / 'config'))
    if args.packaged_binary:
        command = [str(args.packaged_binary.resolve())]
    elif args.package:
        with tempfile.TemporaryDirectory(prefix='wavez-close-package-') as temporary:
            project = Path(temporary) / 'viewer'
            stage(project, source)
            test = (ROOT / 'viewer/ui/shell/test_dialog_close.gd').read_text()
            test = test.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
            test = test.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
            (project / 'CloseReview.gd').write_text(test)
            (project / 'CloseReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://CloseReview.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
            config = project / 'project.godot'
            config.write_text(config.read_text().replace('res://Main.tscn', 'res://CloseReview.tscn'))
            binary = out / 'WAVEZ.x86_64'
            build(args.godot, project, binary, out / 'build-logs')
        command = [str(binary)]
    else:
        imported = subprocess.run([args.godot, '--headless', '--path', str(source / 'viewer'), '--editor', '--import', '--quit'], env=environment, capture_output=True, text=True, timeout=180)
        import_log = imported.stdout + imported.stderr
        (out / 'import.log').write_text(import_log)
        if imported.returncode or 'ERROR:' in import_log:
            raise RuntimeError(f'Import failed: {out / "import.log"}')
        command = [args.godot, '--path', str(source / 'viewer'), '--script', str(ROOT / 'viewer/ui/shell/test_dialog_close.gd')]
    if args.headless:
        command.append('--headless')
    command += ['--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--resolution', '1440x900', '--', str(out)]
    if args.baseline:
        command.append('baseline')
    result = subprocess.run(command, cwd=out, env=environment, capture_output=True, text=True, timeout=210)
    log = result.stdout + result.stderr
    (out / 'run.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Dialog close audit failed: {out / "run.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashlib.sha256(capture.read_bytes()).hexdigest() == digest
    geometry_cases = 0
    if args.compare_report:
        geometry_cases = compare_layouts(json.loads(args.compare_report.read_text())['measurements'], report['measurements'])
    packaged = args.package or args.packaged_binary is not None
    (out / 'summary.json').write_text(json.dumps(dict(checks=report['checks'], geometry_cases=geometry_cases, failures=report['failures'], renderer=args.renderer, headless=args.headless, packaged=packaged, baseline=args.baseline, source_sha256_unchanged=digest), indent=2) + '\n')
    print(f'Dialog close: {report["checks"]} PASS ({args.renderer}, headless={args.headless}, package={packaged}, baseline={args.baseline}); source unchanged')


if __name__ == '__main__':
    main()

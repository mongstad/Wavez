"""Measure issue #306's HDR source gate without changing the production viewer.

Exit 0: source gate passed. Exit 1: valid observations, architecture gate failed.
Harness, build and native runtime failures raise an error instead.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.package_linux import stage, build

SCRIPT = 'scene/prototype_category_bloom_hdr.gd'


def package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-bloom-hdr-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project)
        code = (project / SCRIPT).read_text()
        code = code.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        code = code.replace('func _initialize()', 'func _ready()')
        code = code.replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'BloomHDR.gd').write_text(code)
        (project / 'BloomHDR.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://BloomHDR.gd" id="1"]\n[node name="Prototype" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://BloomHDR.tscn'))
        binary = output / 'WAVEZ.x86_64'
        build(godot, project, binary, output / 'build-logs')
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    script_hash = hashlib.sha256((ROOT / 'viewer' / SCRIPT).read_bytes()).hexdigest()
    executable = package(args.godot, output) if args.package else args.godot
    command = [executable]
    if not args.package:
        command += ['--path', str(ROOT / 'viewer'), '--script', 'res://' + SCRIPT]
    command += ['--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--disable-vsync',
                '--resolution', '192x128', '--', str(output / 'report.json')]
    env = dict(os.environ, XDG_DATA_HOME=str(output / 'profile'), XDG_CONFIG_HOME=str(output / 'profile'))
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    (output / 'native.log').write_text(log)
    if result.returncode not in [0, 1] or any(word in log for word in ['ERROR:', 'WARNING:']):
        raise RuntimeError(f'HDR harness/runtime failed: {output}/native.log')
    report = json.loads((output / 'report.json').read_text())
    if report['harness_failures'] or report['renderer'] != args.renderer:
        raise RuntimeError(f'Invalid HDR observations: {output}/report.json')
    if result.returncode != (0 if report['gate_passed'] else 1):
        raise RuntimeError('Native exit status disagrees with architecture gate')
    if script_hash != hashlib.sha256((ROOT / 'viewer' / SCRIPT).read_bytes()).hexdigest():
        raise RuntimeError('Prototype source changed while running')
    report.update(packaged=args.package, native_exit=result.returncode, prototype_sha256=script_hash,
                  engine_version=subprocess.check_output([args.godot, '--version'], text=True).strip(),
                  native_command=command, production_integration=False)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{args.renderer}, package={args.package}: {report["checks"]} observation checks, '
          f'0 harness failures; HDR gate {"PASS" if report["gate_passed"] else "FAIL"}, '
          f'{len(report["gate_failures"])} failed samples')
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())

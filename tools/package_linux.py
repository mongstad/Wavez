"""Build a standalone Linux release with Wavez-owned analysis sources in its PCK.

Godot export templates, Python/NumPy and FFmpeg are external dependencies.
No third-party runtime is copied into the source tree.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PRESET = '''[preset.0]
name="Wavez Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.zip"
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
'''


def stage(project, source=ROOT):
    """Stage current resources and canonical first-party Python, without duplicates."""
    shutil.copytree(source / 'viewer', project, ignore=shutil.ignore_patterns('.godot', '__pycache__'))
    files = [source / 'tools/analyze_selection.py', source / 'viewer/colormaps.json']
    files += sorted((source / 'wavez_export').rglob('*.py'))
    archive = project / 'analysis/python_runtime.zip'
    inventory = {}
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(files):
            relative = path.relative_to(source).as_posix()
            contents = path.read_bytes()
            entry = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(entry, contents)
            inventory[relative] = hashlib.sha256(contents).hexdigest()
    (project / 'export_presets.cfg').write_text(PRESET)
    return inventory


def build(godot, project, binary, logs):
    logs.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_CONFIG_HOME=str(logs / 'editor-config'))
    for name, arguments in [('import', ['--editor', '--import']),
                            ('export', ['--export-release', 'Wavez Linux', str(binary)])]:
        with (logs / (name + '.log')).open('w') as output:
            result = subprocess.run([godot, '--headless', '--path', str(project), *arguments],
                                    stdout=output, stderr=subprocess.STDOUT, env=env, timeout=180)
        log = (logs / (name + '.log')).read_text()
        if result.returncode or 'ERROR:' in log or 'SCRIPT ERROR:' in log:
            raise RuntimeError(f'{name} failed: {logs / (name + ".log")}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binary = output / 'WAVEZ.x86_64'
    with tempfile.TemporaryDirectory(prefix='wavez-linux-') as temporary:
        project = Path(temporary) / 'viewer'
        inventory = stage(project)
        build(args.godot, project, binary, output / 'build-logs')
    (output / 'build.json').write_text(json.dumps(dict(
        version=json.loads(subprocess.check_output([sys.executable, str(ROOT / 'tools/application_version.py'), '--json'])),
        godot=subprocess.check_output([args.godot, '--version'], text=True).strip(),
        first_party_python=inventory,
        external_dependencies=['Python 3.10+ and NumPy for independent Selection/Analysis and Matched Views', 'FFmpeg for MP4 encoding'],
        artifacts={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [binary, binary.with_suffix('.pck')]}
    ), indent=2) + '\n')
    print(binary)


if __name__ == '__main__':
    main()

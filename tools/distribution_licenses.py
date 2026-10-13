"""Assemble and verify standalone ZIP notices without running the viewer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import zipfile

if __package__:
    from .sync_about_notices import SOURCES, resource_text
else:
    from sync_about_notices import SOURCES, resource_text

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ['LICENSE', 'THIRD_PARTY_LICENSES.md', 'TRADEMARKS.md', 'README.md',
            'licenses/GODOT_LICENSE.txt', 'licenses/GODOT_COPYRIGHT.txt', 'licenses/sources.json',
            'licenses/COLORMAPS_LICENSE.txt', 'licenses/LICENSE-DejaVu.txt',
            'licenses/README.md']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_notices(source=ROOT):
    inventory = json.loads((source / 'licenses/sources.json').read_text())
    for name, entry in inventory['notices'].items():
        data = (source / name).read_bytes()
        if not data or digest(data) != entry['sha256']:
            raise ValueError(f'Missing or changed upstream notice: {name}')
    if (source / 'viewer/ui/about/notices.tres').read_text() != resource_text(source):
        raise ValueError('About notices are stale; run tools/sync_about_notices.py')
    for name in REQUIRED:
        if not (source / name).is_file() or not (source / name).stat().st_size:
            raise ValueError(f'Missing distribution file: {name}')
    return inventory


def inventory_links(text):
    for target in re.findall(r'\]\(([^)]+)\)', text):
        if not re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            yield target.split('#', 1)[0]


def verify_runtime(binary, godot_version, inventory):
    if godot_version != inventory['godot']:
        raise ValueError('Godot version is not the audited version in licenses/sources.json')
    if digest(binary.read_bytes()) != inventory['linux_release_x86_64_sha256']:
        raise ValueError('Linux release template is not the audited official binary')


def verify_exported_notices(godot, pack, output, source=ROOT):
    """Read the actual exported resource headlessly, without starting Main."""
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='wavez-notice-check-') as temporary:
        project = Path(temporary)
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Offline notice verification"\n')
        env = dict(os.environ, XDG_CONFIG_HOME=str(output / 'config'),
                   XDG_DATA_HOME=str(output / 'data'))
        result = subprocess.run([godot, '--headless', '--path', str(project),
                                 '--script', str(source / 'tools/check_packed_notices.gd'),
                                 '--', '--pack=' + str(pack.resolve()),
                                 '--output=' + str(output / 'texts.json')],
                                env=env, capture_output=True, text=True, timeout=30)
    log = result.stdout + result.stderr
    (output / 'native.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise ValueError(f'Offline exported notice check failed: {output / "native.log"}')
    texts = json.loads((output / 'texts.json').read_text())
    expected = {title: (source / name).read_text() for title, name in SOURCES.items()}
    if texts != expected:
        raise ValueError('Actual PCK notice texts differ from canonical source texts')
    report = dict(texts=len(texts), sha256={title: digest(text.encode())
                                         for title, text in texts.items()},
                  exported_resource_identity='PASS', viewer_or_gpu_started=False)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def assemble(output, build_info, source=ROOT):
    """Copy original texts, make the versioned ZIP, then verify its actual members."""
    inventory = source_notices(source)
    verify_runtime(output / 'WAVEZ.x86_64', build_info['godot'], inventory)
    for name, expected in build_info['artifacts'].items():
        if digest((output / name).read_bytes()) != expected:
            raise ValueError(f'Build artifact changed before packaging: {name}')
    files = set(REQUIRED + ['WAVEZ.x86_64', 'WAVEZ.pck', 'GETTING_STARTED.md'])
    files.update(str(p.relative_to(source)) for p in (source / 'docs').rglob('*.md')
                 if not {'evidence', 'documentation-audit'}.intersection(p.relative_to(source).parts))
    files.update(['viewer/ui/about/Wavez_Banner_No_Slogan_No_Border_Dark.png',
                  'viewer/ui/about/Wavez_Banner_No_Slogan_No_Border_White.png'])
    for name in sorted(files - {'WAVEZ.x86_64', 'WAVEZ.pck'}):
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, destination)
        destination.chmod(0o644)
    (output / 'WAVEZ.x86_64').chmod(0o755)
    (output / 'WAVEZ.pck').chmod(0o644)
    install = output / 'INSTALL.txt'
    install.write_text('''Extract the entire folder; keep WAVEZ.x86_64 and WAVEZ.pck together.
Run ./WAVEZ.x86_64. Restore permission with chmod +x WAVEZ.x86_64 if needed.
Viewing needs a graphical Linux x86_64 desktop and working Forward+ Vulkan GPU/
drivers, not a separately installed Godot or Python. Standard OS libraries and
utilities remain required. MP4 needs external FFmpeg with libx264. Independent
experimental Selection/Analysis needs external Python/NumPy and, for isosurfaces,
scikit-image. See README.md and GETTING_STARTED.md for dependency details.

Open THIRD_PARTY_LICENSES.md for the inventory. Open the plain-text files in
licenses/ directly with a text editor if your Markdown reader blocks local links.
Wavez LICENSE and TRADEMARKS.md remain in the package root.
Help → About → Licenses and notices also provides offline notices. Full source,
examples and historical evidence belong to the corresponding tagged GitHub source
archives. GitHub-hosted README images need access to their original URLs.
''')
    files.add('INSTALL.txt')
    manifest = dict(build_info, files={})
    for name in sorted(files):
        data = (output / name).read_bytes()
        if not data:
            raise ValueError(f'Empty distribution file: {name}')
        manifest['files'][name] = dict(bytes=len(data), sha256=digest(data))
    (output / 'BUILD_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    files.add('BUILD_MANIFEST.json')
    folder = f"Wavez-{build_info['version']['full']}-linux-x86_64"
    archive = output / (folder + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(files):
            z.write(output / name, folder + '/' + name)
    try:
        report = verify_archive(archive, source)
    except Exception:
        archive.unlink()
        raise
    (output / 'SHA256SUMS.txt').write_text(digest(archive.read_bytes()) + '  ' + archive.name + '\n')
    (output / 'archive-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    return archive


def verify_archive(archive, source=ROOT):
    """Fail on inaccessible paths, altered texts or incomplete manifest coverage."""
    inventory = source_notices(source)
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('ZIP integrity failure')
        names = z.namelist()
        if len(set(names)) != len(names):
            raise ValueError('Duplicate ZIP members')
        roots = {Path(n).parts[0] for n in names}
        if len(roots) != 1:
            raise ValueError('ZIP must have one package directory')
        prefix = roots.pop() + '/'
        members = {n.removeprefix(prefix): n for n in names}
        for relative, name in members.items():
            if Path(relative).is_absolute() or '..' in Path(relative).parts or '\\' in relative:
                raise ValueError(f'Unsafe ZIP member: {name}')
            mode = z.getinfo(name).external_attr >> 16
            if stat.S_ISLNK(mode) or not mode & stat.S_IROTH or not z.read(name):
                raise ValueError(f'Unreadable, empty or symlinked member: {name}')
        for name in REQUIRED:
            if name not in members or z.read(members[name]) != (source / name).read_bytes():
                raise ValueError(f'Missing or altered canonical distribution file: {name}')
        for target in inventory_links(z.read(members['THIRD_PARTY_LICENSES.md']).decode()):
            if target and target not in members:
                raise ValueError(f'Unresolved local inventory link: {target}')
        manifest = json.loads(z.read(members['BUILD_MANIFEST.json']))
        if prefix != f"Wavez-{manifest['version']['full']}-linux-x86_64/":
            raise ValueError('Archive directory and application version differ')
        if manifest['godot'] != inventory['godot']:
            raise ValueError('Archive runtime is not audited')
        if set(manifest['files']) != set(members) - {'BUILD_MANIFEST.json'}:
            raise ValueError('Manifest does not cover every ZIP member')
        for name, expected in manifest['files'].items():
            data = z.read(members[name])
            if len(data) != expected['bytes'] or digest(data) != expected['sha256']:
                raise ValueError(f'Manifest/content mismatch: {name}')
        if digest(z.read(members['WAVEZ.x86_64'])) != inventory['linux_release_x86_64_sha256']:
            raise ValueError('Archive executable differs from audited template')
        if not (z.getinfo(members['WAVEZ.x86_64']).external_attr >> 16) & 0o111:
            raise ValueError('Archive executable permission is missing')
    return dict(archive=archive.name, sha256=digest(archive.read_bytes()),
                bytes=archive.stat().st_size, files=len(names), required_files=len(REQUIRED),
                canonical_notice_digests='PASS', local_license_links='PASS',
                archive_integrity='PASS', readable_members='PASS')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify_archive(args.archive), indent=2))

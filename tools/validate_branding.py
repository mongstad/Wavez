"""Verify old/new user-data identity and inspect live WAVEZ shell surfaces."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene

PROBE = '''extends SceneTree
func _initialize():
    var args = OS.get_cmdline_user_args()
    var path = "user://file_dialog_preferences.cfg"
    var cfg = ConfigFile.new()
    if args[0] == "seed":
        cfg.set_value("navigation", "favorites", PackedStringArray([args[2]]))
        cfg.set_value("navigation", "recent", PackedStringArray([args[2]]))
        assert(cfg.save(path) == OK)
    else:
        assert(cfg.load(path) == OK)
        assert(cfg.get_value("navigation", "favorites") == PackedStringArray([args[2]]))
        assert(cfg.get_value("navigation", "recent") == PackedStringArray([args[2]]))
    var file = FileAccess.open(args[1], FileAccess.WRITE)
    file.store_string(JSON.stringify({"user_data_dir":OS.get_user_data_dir(), "preferences_sha256":FileAccess.get_sha256(path)}))
    file.close()
    quit()
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config'))
    legacy = out/'legacy'; legacy.mkdir()
    # Same native runtime and OS resolve the accepted project's actual old directory.
    (legacy/'project.godot').write_text(subprocess.check_output(
        ['git', 'show', 'd6e4bd8:viewer/project.godot'], cwd=ROOT, text=True))
    probe = out/'probe.gd'; probe.write_text(PROBE)
    def run(label, command):
        r = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
        log = r.stdout+r.stderr; (out/(label+'.log')).write_text(log)
        assert r.returncode == 0 and 'ERROR:' not in log and 'SCRIPT ERROR:' not in log, log[-5000:]
    for label, project, mode in [('old', legacy, 'seed'), ('new', ROOT/'viewer', 'read')]:
        run(label, [a.godot, '--headless', '--path', str(project), '--script', str(probe), '--', mode, str(out/(label+'.json')), str(out)+'/'])
    old = json.loads((out/'old.json').read_text()); new = json.loads((out/'new.json').read_text())
    assert old == new, 'Renaming must retain the actual directory and existing preferences byte-for-byte'
    source = scene(out/'scene.ssc'); digest = hashlib.sha256(source.read_bytes()).hexdigest()
    run('surfaces', [a.godot, '--path', str(ROOT/'viewer'), '--rendering-method', a.renderer,
        '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script', 'ui/test_branding.gd', '--', str(out)])
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'] and hashlib.sha256(source.read_bytes()).hexdigest() == digest
    report.update(old_new_preferences=old, source_sha256=digest)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Branding: {report["checks"]} UI checks PASS ({a.renderer}); old/new user data and preference bytes identical')


if __name__ == '__main__':
    main()

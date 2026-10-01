"""PID-scoped KWin checks for borderless resize/minimize/maximize/fullscreen/close.

Requires a KDE session, qdbus6, PyGObject and Spectacle. Never operates on another
window. Native pointer dragging remains an owner check; geometry/state checks
use the real compositor and production window controls.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--display-driver', choices=['wayland', 'x11'], default='wayland')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    capture = scene(out / 'scene.ssc')
    digest = hashlib.sha256(capture.read_bytes()).hexdigest()
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    service = 'org.wavez.ChromeReview'
    conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', (service, 4)), None, Gio.DBusCallFlags.NONE, -1, None)
    received = []
    xml = '<node><interface name="org.wavez.Review"><method name="Record"><arg type="s" direction="in"/></method></interface></node>'
    def record(_c, _s, _p, _i, _m, values, invocation):
        received.append(json.loads(values.unpack()[0])); invocation.return_value(None)
    registration = conn.register_object('/Review', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], record, None, None)
    qdbus = shutil.which('qdbus6') or '/usr/lib64/qt6/bin/qdbus'
    plugin = 'wavez-143-chrome-review'
    def dbus(path, *parameters):
        return subprocess.check_output([qdbus, 'org.kde.KWin', path, *parameters], text=True).strip()
    def probe(pid, action=''):
        received.clear()
        mutation = {'resize': 'w.frameGeometry={x:w.frameGeometry.x,y:w.frameGeometry.y,width:1200,height:760};', 'unminimize': 'w.minimized=false; workspace.activeWindow=w;', 'activate': 'workspace.activeWindow=w;'}.get(action, '')
        script = out / 'kwin-probe.js'
        script.write_text('function rect(r){return {x:r.x,y:r.y,width:r.width,height:r.height};}\n'
            'var windows=workspace.windowList().filter(function(w){return w.pid===' + str(pid) + ';});\n'
            'windows.forEach(function(w){' + mutation + '});\n'
            'callDBus("' + service + '","/Review","org.wavez.Review","Record",JSON.stringify(windows.map(function(w){return {pid:w.pid,active:w.active,fullscreen:w.fullScreen,minimized:w.minimized,resizable:w.resizeable,noBorder:w.noBorder,frame:rect(w.frameGeometry),client:rect(w.clientGeometry),screen:rect(w.output.geometry)};})));\n')
        identifier = dbus('/Scripting', 'loadScript', str(script), plugin)
        try:
            dbus('/Scripting/Script' + identifier, 'run')
            until = time.monotonic() + 5
            context = GLib.MainContext.default()
            while not received and time.monotonic() < until:
                while context.pending(): context.iteration(False)
                time.sleep(.01)
            assert received and len(received[0]) == 1, 'Test window unavailable or ambiguous'
            return received[0][0]
        finally:
            dbus('/Scripting', 'unloadScript', plugin)
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--display-driver', args.display_driver,
               '--rendering-method', args.renderer, '--resolution', '1440x900', '--audio-driver', 'Dummy',
               '--script', 'ui/shell/test_window_chrome.gd', '--', str(out), str(capture)]
    reports = []
    with (out / 'godot.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            seen = set(); deadline = time.monotonic() + 150
            while process.poll() is None:
                assert time.monotonic() < deadline, 'Native chrome review timed out'
                path = out / 'stage.json'
                if not path.exists(): time.sleep(.05); continue
                try: stage = json.loads(path.read_text())
                except json.JSONDecodeError: continue
                label = stage['stage']
                if label in seen: time.sleep(.05); continue
                native = probe(process.pid)
                if stage['expected_mode'] != 1 and not native['active']:
                    probe(process.pid, 'activate'); time.sleep(.3); native = probe(process.pid)
                    stage['reactivated_test_window'] = True
                assert not stage['failures'], stage['failures']
                # KWin may retain the fullscreen flag on a minimized X11
                # surface; Wayland can clear it. Verify actual minimization
                # here and require restored fullscreen in the next stage.
                if label != 'minimized-fullscreen':
                    assert native['fullscreen'] == (stage['expected_mode'] == 3), (label, native)
                assert native['minimized'] == (stage['expected_mode'] == 1), (label, native)
                assert native['frame'] == native['client'], (label, 'Native title bar/decorations remain', native)
                # KWin's noBorder is false for client-decorated Wayland surfaces,
                # even when Godot suppresses libdecor. Equal client/frame rectangles
                # plus the native Window.borderless assertion establish no chrome.
                if stage['restore']:
                    reference = next(item['kwin'] for item in reports if item['stage'] == stage['restore'])
                    assert native['frame'] == reference['frame'], (label, native, reference)
                if not native['minimized']:
                    assert native['active'], 'Test window lost focus; refuse capture of another application'
                if label in ['restored', 'maximized', 'max-fullscreen', 'restore-button']:
                    subprocess.run(['spectacle', '-a', '-b', '-n', '-o', str(out / (label + '-desktop.png'))], check=True, timeout=20)
                stage['kwin'] = native; reports.append(stage)
                (out / 'desktop-report.json').write_text(json.dumps(reports, indent=2) + '\n')
                if stage['action']: probe(process.pid, stage['action'])
                (out / (label + '.ack')).touch(); seen.add(label)
            expected_stages = 18
            assert process.returncode == 0 and len(reports) == expected_stages, 'Close handler or stage sequence failed'
            native_log = (out / 'godot.log').read_text()
            clean_log = native_log.replace('libdecor-gtk-WARNING: Failed to initialize GTK', '')
            assert not any(word in clean_log for word in ['ERROR:', 'WARNING:']), 'Godot diagnostic'
            (out / 'startup-notes.json').write_text(json.dumps({'libdecor_gtk_fallback_warning': 'libdecor-gtk-WARNING' in native_log}, indent=2) + '\n')
            assert hashlib.sha256(capture.read_bytes()).hexdigest() == digest
            assert reports[0]['kwin']['resizable'], 'Restored compositor window is not resizable'
            (out / 'source.json').write_text(json.dumps({'sha256': digest, 'unchanged': True}, indent=2) + '\n')
            print(f'Window chrome: {reports[-1]["checks"]} checks, {expected_stages} KWin stages PASS ({args.display_driver}, {args.renderer})')
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=10)
            conn.unregister_object(registration)
            conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ReleaseName', GLib.Variant('(s)', (service,)), None, Gio.DBusCallFlags.NONE, -1, None)


if __name__ == '__main__':
    main()

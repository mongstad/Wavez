"""KDE/Wayland real-capture review. Uses a temporary PID-scoped KWin script.

Requires system Python with PyGObject/Pillow, qdbus (Qt6), Spectacle and a physical KDE
session. Changes fullscreen only on the test process, then unloads its script.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
from gi.repository import Gio, GLib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    parser.add_argument('--window-restore', action='store_true', help='Check fullscreen mode/geometry restoration and unpinned visibility.')
    parser.add_argument('--legend-visibility', action='store_true', help='Also check independent legend/panel visibility and recipe restore at each window stage.')
    parser.add_argument('--display-driver', choices=['wayland', 'x11'], default='wayland')
    parser.add_argument('--screen', type=int, help='Request a specific Godot monitor index; verify actual placement in the KWin report.')
    args = parser.parse_args()
    if args.legend_visibility:
        args.window_restore = True
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    def digest():
        with args.capture.open('rb') as stream:
            return hashlib.file_digest(stream, 'sha256').hexdigest()
    source_hash = digest()
    qdbus = shutil.which('qdbus6') or shutil.which('qdbus') or '/usr/lib64/qt6/bin/qdbus'
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    service = 'org.wavez.FullscreenReview'
    conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                   'RequestName', GLib.Variant('(su)', (service, 4)), None, Gio.DBusCallFlags.NONE, -1, None)
    xml = '<node><interface name="org.wavez.Review"><method name="Record"><arg type="s" direction="in"/></method></interface></node>'
    received = []
    def record(_c, _s, _p, _i, _m, values, invocation):
        received.append(json.loads(values.unpack()[0])); invocation.return_value(None)
    registration = conn.register_object('/Review', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], record, None, None)
    def dbus(path, *args):
        return subprocess.check_output([qdbus, 'org.kde.KWin', path, *args], text=True).strip()
    plugin = 'wavez-issue46-review'
    def kwin(pid, leave=False):
        received.clear()
        script = out / 'kwin-probe.js'
        script.write_text('function rect(r) { return {x:r.x,y:r.y,width:r.width,height:r.height}; }\n'
            'var windows=workspace.windowList().filter(function(w) { return w.pid === ' + str(pid) + '; });\n'
            + ('windows.forEach(function(w) { w.fullScreen=false; });\n' if leave else '')
            + 'callDBus("' + service + '","/Review","org.wavez.Review","Record",JSON.stringify(windows.map(function(w) { return {pid:w.pid,active:w.active,fullscreen:w.fullScreen,frame:rect(w.frameGeometry),client:rect(w.clientGeometry),screen:rect(w.output.geometry)}; })));\n')
        script_id = dbus('/Scripting', 'loadScript', str(script), plugin)
        try:
            dbus('/Scripting/Script' + script_id, 'run')
            until = time.monotonic() + 5
            context = GLib.MainContext.default()
            while not received and time.monotonic() < until:
                while context.pending(): context.iteration(False)
                time.sleep(.01)
            assert received and len(received[0]) == 1, 'KWin test window unavailable or ambiguous'
            return received[0][0]
        finally:
            dbus('/Scripting', 'unloadScript', plugin)
    command = [args.godot, '--path', str(ROOT/'viewer'), '--display-driver', args.display_driver,
               '--rendering-method', args.renderer, '--resolution', '1440x900', '--audio-driver', 'Dummy',
               '--script', 'ui/shell/test_legend_visibility.gd' if args.legend_visibility else ('ui/shell/test_fullscreen_restore.gd' if args.window_restore else 'ui/shell/test_immersive_desktop.gd'), '--', '--review-output='+str(out),
               '--review-capture='+str(args.capture.resolve())]
    if args.screen is not None:
        command[1:1] = ['--screen', str(args.screen)]
    reports = []
    with (out/'godot.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            seen = set(); deadline = time.monotonic()+180
            while process.poll() is None:
                assert time.monotonic() < deadline, 'Native review timed out'
                path = out/'stage.json'
                if not path.exists(): time.sleep(.05); continue
                try: stage = json.loads(path.read_text())
                except json.JSONDecodeError: continue
                label = stage['stage']
                if label in seen: time.sleep(.05); continue
                native = kwin(process.pid)
                fullscreen = stage['expected_mode'] == 3 if args.window_restore else label not in ['windowed', 'restored-windowed', 'wm-recovered']
                assert native['fullscreen'] == fullscreen, (label, native)
                if fullscreen: assert native['frame'] == native['client'] == native['screen'], (label, native)
                if args.window_restore and stage['restore']:
                    reference = next(item['kwin'] for item in reports if item['stage'] == stage['restore'])
                    assert native['frame'] == reference['frame'] and native['client'] == reference['client'], (label, native, reference)
                if not native['active']:
                    (out/'focus-loss.json').write_text(json.dumps(dict(stage=label, kwin=native), indent=2)+'\n')
                    raise AssertionError('Test window lost focus; do not capture another application')
                subprocess.run(['spectacle','-a','-b','-n','-o',str(out/(label+'-desktop.png'))], check=True, timeout=20)
                if fullscreen:
                    subprocess.run(['spectacle','-m','-b','-n','-o',str(out/(label+'-monitor.png'))], check=True, timeout=20)
                stage['kwin'] = native; reports.append(stage)
                (out/'desktop-report.json').write_text(json.dumps(reports, indent=2)+'\n')
                assert not stage['failures'], stage['failures']
                if label == 'windowed-to-fullscreen': kwin(process.pid, leave=True)
                (out/(label+'.ack')).touch(); seen.add(label)
            assert process.returncode == 0, 'Godot review failed; inspect godot.log'
            if args.window_restore:
                assert len(reports) == 16, 'Incomplete fullscreen restore review'
                assert 'ERROR:' not in (out/'godot.log').read_text(), 'Godot error'
                assert digest() == source_hash, 'Source changed'
                (out/'source.json').write_text(json.dumps({'sha256':source_hash,'unchanged':True},indent=2)+'\n')
                print(f'Fullscreen restore: {reports[-1]["checks"]} checks, 16 KWin geometry stages PASS ({args.renderer})')
                return
            assert len(reports) == 8, 'Incomplete native review'
            assert 'ERROR:' not in (out/'godot.log').read_text(), 'Godot error'
            # Inspect actual rendered science as well as state and KWin geometry.
            # This common central region excludes shell chrome and the hint.
            references = {}
            pixels = []
            for label in ['fullscreen-entry', 'fullscreen-settled', 'fullscreen-clean',
                          'fullscreen-stable', 'windowed-to-fullscreen']:
                for kind in ['viewport', 'desktop']:
                    with Image.open(out / (label+'-'+kind+'.png')) as image:
                        width, height = image.size
                        box = (int(width*.35), int(height*.32), int(width*.65), int(height*.67))
                        region = image.convert('RGB').crop(box)
                        data = region.tobytes()
                        assert max(channel[1] for channel in region.getextrema()) > 100, 'Scientific region is unexpectedly blank'
                    # Compare like capture paths: the compositor may quantize
                    # RGB differently from Godot's viewport readback.
                    if kind not in references: references[kind] = data
                    assert data == references[kind], (label, kind, 'Scientific region changed during fullscreen presentation')
                    pixels.append(dict(stage=label, capture=kind, box=box, sha256=hashlib.sha256(data).hexdigest()))
            (out/'scientific-roi.json').write_text(json.dumps(pixels, indent=2)+'\n')
            assert digest() == source_hash, 'Real source changed'
            (out/'source.json').write_text(json.dumps({'capture':str(args.capture),'sha256':source_hash,'unchanged':True},indent=2)+'\n')
            print(f'Native immersive desktop: {reports[-1]["checks"]} checks, 8 KWin geometry checks, 5 matching scientific regions per capture method PASS ({args.renderer})')
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=10)
            conn.unregister_object(registration)
            conn.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','ReleaseName',GLib.Variant('(s)',(service,)),None,Gio.DBusCallFlags.NONE,-1,None)


if __name__ == '__main__':
    main()

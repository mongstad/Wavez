"""PID-scoped KWin resize probe for empty, paused, playing and recovery states.

The compositor changes only this test process's native frame geometry. This
provides repeatable configure events; a physical pointer drag remains an owner
acceptance check.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from tools.profile_parallel_preparation import process_sample


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--display-driver', choices=['wayland', 'x11'], default='wayland')
    parser.add_argument('--steps', type=int, default=32)
    parser.add_argument('--pointer', action='store_true', help='Use a temporary virtual mouse to drag the native right edge')
    parser.add_argument('--corner', action='store_true', help='Drag the bottom-right corner diagonally (requires --pointer)')
    parser.add_argument('--top-right', action='store_true', help='Drag the top-right corner inward (requires --pointer)')
    parser.add_argument('--oscillate', action='store_true', help='Reverse diagonal direction every 100 pointer steps for sustained high-rate resize')
    parser.add_argument('--capture', type=Path, help='Read-only external SSC source (default: small synthetic fixture)')
    parser.add_argument('--telemetry', action='store_true', help='Sample process, KWin and whole-device NVIDIA load')
    parser.add_argument('--size', default='1440x900', help='Native starting window size, WIDTHxHEIGHT')
    parser.add_argument('--empty-only', action='store_true', help='Profile the empty viewer without loading a capture')
    parser.add_argument('--playing-only', action='store_true', help='Profile playing and recovery without empty/paused phases')
    parser.add_argument('--seconds', type=float, default=3.0, help='Active drag duration')
    args = parser.parse_args()
    if (args.corner or args.top_right) and not args.pointer:
        parser.error('corner drag requires --pointer')
    if args.corner and args.top_right:
        parser.error('choose one corner')
    if args.oscillate and not args.pointer:
        parser.error('oscillation requires --pointer')
    if args.empty_only and args.playing_only:
        parser.error('choose one phase subset')
    initial_width, initial_height = map(int, args.size.lower().split('x'))
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    capture = args.capture.resolve() if args.capture else scene(out / 'scene.ssc')
    with capture.open('rb') as stream:
        source_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    source = {'path': str(capture), 'bytes': capture.stat().st_size, 'sha256': source_hash}
    (out / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--display-driver', args.display_driver,
               '--rendering-method', args.renderer, '--resolution', args.size, '--audio-driver', 'Dummy',
               '--script', 'ui/shell/test_resize_diagnostic.gd', '--', str(out), str(capture),
               'empty' if args.empty_only else ('playing' if args.playing_only else 'all')]
    (out / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    qdbus = shutil.which('qdbus6') or '/usr/lib64/qt6/bin/qdbus'
    service = 'org.wavez.ResizeProfile'
    plugin = 'wavez-158-resize-profile'
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                   'RequestName', GLib.Variant('(su)', (service, 4)), None,
                   Gio.DBusCallFlags.NONE, -1, None)
    received = []
    xml = '<node><interface name="org.wavez.Review"><method name="Record"><arg type="s" direction="in"/></method></interface></node>'

    def record(_c, _s, _p, _i, _m, values, invocation):
        received.append(json.loads(values.unpack()[0]))
        invocation.return_value(None)

    registration = conn.register_object('/Review', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], record, None, None)

    def dbus(path, *parameters):
        return subprocess.check_output([qdbus, 'org.kde.KWin', path, *parameters], text=True).strip()

    def kwin(pid, width=None, height=None, activate=False, x=None, y=None):
        received.clear()
        mutation = 'workspace.activeWindow=w;' if activate else ''
        if width is not None:
            px = 'w.frameGeometry.x' if x is None else x
            py = 'w.frameGeometry.y' if y is None else y
            mutation += f'w.frameGeometry={{x:{px},y:{py},width:{width},height:{height}}};'
        script = out / 'kwin-probe.js'
        script.write_text('var windows=workspace.windowList().filter(function(w){return w.pid===' + str(pid) + ';});\n'
                          'windows.forEach(function(w){' + mutation + '});\n'
                          'callDBus("' + service + '","/Review","org.wavez.Review","Record",'
                          'JSON.stringify(windows.map(function(w){return {pid:w.pid,active:w.active,'
                          'x:w.frameGeometry.x,y:w.frameGeometry.y,width:w.frameGeometry.width,'
                          'height:w.frameGeometry.height,clientX:w.clientGeometry.x,'
                          'clientY:w.clientGeometry.y,clientWidth:w.clientGeometry.width,'
                          'clientHeight:w.clientGeometry.height,cursorX:workspace.cursorPos.x,'
                          'cursorY:workspace.cursorPos.y,screen:w.output.geometry};})));\n')
        identifier = dbus('/Scripting', 'loadScript', str(script), plugin)
        try:
            dbus('/Scripting/Script' + identifier, 'run')
            until = time.monotonic() + 5
            context = GLib.MainContext.default()
            while not received and time.monotonic() < until:
                while context.pending():
                    context.iteration(False)
                time.sleep(.005)
            assert received and len(received[0]) == 1, 'Test window unavailable or ambiguous'
            return received[0][0]
        finally:
            dbus('/Scripting', 'unloadScript', plugin)

    pointer = None
    if args.pointer:
        from evdev import UInput, ecodes
        pointer = UInput({ecodes.EV_KEY: [ecodes.BTN_LEFT],
                          ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y]},
                         name='WAVEZ #158 isolated resize pointer')

    def move_pointer(pid, x, y):
        for _ in range(50):
            current = kwin(pid)
            dx = round(x - current['cursorX'])
            dy = round(y - current['cursorY'])
            if abs(dx) <= 2 and abs(dy) <= 2:
                return current
            pointer.write(ecodes.EV_REL, ecodes.REL_X, max(-80, min(80, round(dx * .5))))
            pointer.write(ecodes.EV_REL, ecodes.REL_Y, max(-80, min(80, round(dy * .5))))
            pointer.syn()
            time.sleep(.06)
        raise AssertionError(f'Virtual pointer missed requested position {(x, y)}: {kwin(pid)}')

    with (out / 'godot.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        telemetry = []
        phase_state = {'name': 'startup'}
        stop_telemetry = threading.Event()
        kwin_pids = subprocess.check_output(['pgrep', '-x', 'kwin_wayland'], text=True).split() if args.telemetry else []
        kwin_pid = int(kwin_pids[0]) if kwin_pids else None

        def sample_telemetry():
            while not stop_telemetry.is_set():
                row = {'seconds': time.monotonic(), 'phase': phase_state['name']}
                try:
                    row['wavez'] = process_sample(process.pid)
                    if kwin_pid is not None:
                        row['kwin'] = process_sample(kwin_pid)
                    gpu = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,memory.used',
                                          '--format=csv,noheader,nounits'], capture_output=True,
                                         text=True, timeout=2)
                    if gpu.returncode == 0:
                        row['gpu_percent'], row['gpu_mib'] = map(float, gpu.stdout.strip().split(', '))
                except (FileNotFoundError, ProcessLookupError, ValueError, subprocess.TimeoutExpired):
                    pass
                telemetry.append(row)
                stop_telemetry.wait(.5)

        sampler = threading.Thread(target=sample_telemetry, daemon=True) if args.telemetry else None
        if sampler is not None:
            sampler.start()
        try:
            phases = (['empty'] if args.empty_only else
                      ['playing', 'playing_idle', 'recovered'] if args.playing_only else
                      ['empty', 'paused', 'playing', 'playing_idle', 'recovered'])
            for phase in phases:
                deadline = time.monotonic() + 40
                while not (out / (phase + '.ready')).exists():
                    assert process.poll() is None, (phase, (out / 'godot.log').read_text()[-3000:])
                    assert time.monotonic() < deadline, 'Phase did not start: ' + phase
                    time.sleep(.05)
                content = json.loads((out / (phase + '.ready')).read_text())
                native = (kwin(process.pid, initial_width, initial_height, activate=True, x=0, y=0)
                          if args.size != '1440x900' else kwin(process.pid, activate=True))
                if args.size != '1440x900':
                    time.sleep(.35)
                    native = kwin(process.pid)
                    assert abs(native['width'] - initial_width) <= 10 and abs(native['height'] - initial_height) <= 35, native
                assert native['active'], 'Test window is not active; refuse desktop resize'
                (out / (phase + '-native.json')).write_text(json.dumps(native, indent=2) + '\n')
                phase_state['name'] = phase
                if phase not in ('playing_idle', 'recovered'):
                    if pointer is not None:
                        original_cursor = (native['cursorX'], native['cursorY'])
                        target = ((round(native['x'] + native['width'] - 3),
                                   round(native['y'] + 3)) if args.top_right else
                                  (round(native['x'] + native['width'] - 3),
                                   round(native['y'] + (native['height'] - 3 if args.corner
                                                        else native['height'] / 2))))
                        (out / (phase + '-pointer-target.json')).write_text(json.dumps(
                            {'content': content, 'native': native, 'target': target}, indent=2) + '\n')
                        post_drag = None
                        try:
                            move_pointer(process.pid, *target)
                            pointer.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 1)
                            pointer.syn()
                            time.sleep(.2)  # Let the compositor establish the edge grab.
                            (out / (phase + '.start')).touch()
                            started = time.monotonic()
                            for index in range(args.steps):
                                direction = -1 if not args.oscillate or (index // 100) % 2 == 0 else 1
                                pointer.write(ecodes.EV_REL, ecodes.REL_X, direction * max(1, 360 // args.steps))
                                if args.corner or args.top_right:
                                    pointer.write(ecodes.EV_REL, ecodes.REL_Y,
                                                  direction * max(1, 220 // args.steps) * (-1 if args.top_right else 1))
                                pointer.syn()
                                # Begin gently so the native handle is engaged,
                                # then increase the gesture speed.
                                fraction = (index + 1) / args.steps
                                time.sleep(max(0, started + args.seconds * fraction ** .7 - time.monotonic()))
                        finally:
                            pointer.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
                            pointer.syn()
                            (out / (phase + '.stop')).touch()
                            post_drag = kwin(process.pid)
                            (out / (phase + '-post-drag.json')).write_text(json.dumps(post_drag, indent=2) + '\n')
                            try:
                                move_pointer(process.pid, *original_cursor)
                            except AssertionError as error:
                                print('Pointer restore was imprecise:', error, file=sys.stderr)
                        kwin(process.pid, initial_width, initial_height)
                    else:
                        (out / (phase + '.start')).touch()
                        started = time.monotonic()
                        for index in range(args.steps):
                            fraction = (index + 1) / args.steps
                            width = round(initial_width - 360 * fraction)
                            height = round(initial_height - 220 * fraction)
                            kwin(process.pid, width, height)
                            time.sleep(max(0, started + args.seconds * fraction - time.monotonic()))
                        kwin(process.pid, initial_width, initial_height)
                        (out / (phase + '.stop')).touch()
                else:
                    (out / (phase + '.start')).touch()
                    time.sleep(3)
                    (out / (phase + '.stop')).touch()
                (out / (phase + '.done')).touch()
                if args.top_right and phase not in ('playing_idle', 'recovered'):
                    measured = json.loads((out / 'result.json').read_text())[-1]
                    width_range = measured['width_range']
                    height_range = measured['height_range']
                    assert (measured['native_size_events'] > 5 and
                            width_range[1] - width_range[0] > 5 and
                            height_range[1] - height_range[0] > 5), \
                        'Top-right native handle did not resize both axes'
            process.wait(timeout=40)
            assert process.returncode == 0, (out / 'godot.log').read_text()[-6000:]
            report = json.loads((out / 'result.json').read_text())
            (out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
            assert all(not row['scene_error'] and row['longest_callback_gap_ms'] < 2000
                       and row['camera_unchanged'] and row['records_unchanged']
                       for row in report), 'Resize stalled or changed camera/source state'
            for row in report:
                layouts = row['ui_profile'].get('shell_layout_inclusive', {}).get('calls', 0)
                if row['native_size_events'] > 400:
                    assert layouts < row['native_size_events'] * .75, 'Native resize was not coalesced'
            by_phase = {row['phase']: row for row in report}
            if 'paused' in by_phase:
                assert by_phase['paused']['source_loaded'] and not by_phase['paused']['playing']
            if 'playing' in by_phase:
                assert by_phase['playing']['source_loaded'] and by_phase['playing']['playing']
                assert by_phase['playing_idle']['playing'] and by_phase['playing_idle']['source_loaded']
                assert (by_phase['playing_idle']['playback_time'] !=
                        by_phase['playing']['playback_time']), 'Playback clock failed to recover'
                assert not by_phase['recovered']['playing'] and not by_phase['recovered']['buffering']
                post = json.loads((out / 'post-resize.json').read_text())
                assert all(value for key, value in post.items() if key != 'channel_available'), post
                if args.capture is None:
                    assert post['channel_available'], 'Synthetic fixture must test a channel switch'
            with capture.open('rb') as stream:
                source['unchanged'] = hashlib.file_digest(stream, 'sha256').hexdigest() == source_hash
            assert source['unchanged'], 'SSC source changed during validation'
            (out / 'source.json').write_text(json.dumps(source, indent=2) + '\n')
            for row in report:
                layouts = row['ui_profile'].get('shell_layout_inclusive', {}).get('calls', 0)
                print(f"{row['phase']}: {row['native_size_events']} native sizes, "
                      f"{layouts} layouts, {row['draws']} draws, "
                      f"{row['longest_callback_gap_ms']:.0f} ms max gap, "
                      f"clock={row['playback_time']}")
            print('Post-resize checks:', json.dumps(post) if 'playing' in by_phase else 'empty only')
        finally:
            stop_telemetry.set()
            if sampler is not None:
                sampler.join(timeout=3)
                (out / 'telemetry.json').write_text(json.dumps(telemetry, indent=2) + '\n')
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)
            conn.unregister_object(registration)
            if pointer is not None:
                pointer.close()
            conn.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                           'ReleaseName', GLib.Variant('(s)', (service,)), None,
                           Gio.DBusCallFlags.NONE, -1, None)


if __name__ == '__main__':
    main()

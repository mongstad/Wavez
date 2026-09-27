"""Issue #116: current SIMSCP4 layers, export clocks, strict reads and GPU evidence."""
import argparse
import bisect
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture, SceneReader


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def fixtures(out):
    objects = [dict(id='p', kind='particles', units='m', identity='persistent_i8'),
               dict(id='field', kind='volume', units='m'),
               dict(id='mesh', kind='mesh', units='m', identity='stable_topology')]
    for name, selected in [('particles', objects[:1]), ('late-particles', objects[:1]), ('field', objects[1:2]),
                           ('mesh', objects[2:]), ('mixed', objects), ('late', objects[1:2]),
                           ('overflow', objects[1:2]), ('budget', objects[2:])]:
        with SceneCapture(out / (name + '.ssc'), objects=selected) as writer:
            for obj in selected:
                if obj['kind'] == 'particles':
                    for t in ([0., .5, 1., 2.] if name == 'late-particles' else [0., 1., 2.]):
                        channels = {} if name == 'late-particles' and t == 0 else dict(color_value=np.array([.2, .8], 'f4'))
                        writer.add_particles('p', t, np.array([[-1+t, 0, 0], [1+t, 0, 0]], 'f8'),
                                             ids=[10, 20], **channels,
                                             visual_size=np.array([.3, .3], 'f4'))
                elif obj['kind'] == 'volume':
                    for i, t in enumerate([0., .5, 1., 1.5, 2.]):
                        values = (np.arange(8**3, dtype='f4') / 512 + i/8).reshape(8, 8, 8)
                        channels = dict(density=values, psi_imag=values.astype('f8') - .5)
                        if name == 'late' and i == 0: channels.pop('psi_imag')
                        if name == 'overflow' and i >= 1: channels['psi_imag'].fill(1e100)
                        writer.add_volume('field', t, channels, origin=[-1]*3, spacing=[2/7]*3)
                else:
                    for t in [0., 1., 2.]:
                        positions = np.array([[-1, -1, t/4], [1, -1, t/4], [0, 1, t/4]], 'f8')
                        triangles = np.array([[0, 1, 2]], 'u4')
                        if name == 'budget':
                            positions = np.tile(positions, (10000, 1))
                            triangles = np.arange(30000, dtype='u4').reshape(-1, 3)
                        writer.add_mesh('mesh', t, positions, triangles, vertex_channels=dict(
                            vertex_id=np.arange(len(positions), dtype='i8'),
                            scalar=np.full(len(positions), .25 + t/8, dtype='f4')))
    # Keep descriptors/commit valid; mutate a readable payload in a later sample.
    source = out/'field.ssc'
    with SceneReader(source) as reader:
        offset = reader.samples['field'][2]['offset']
    raw = bytearray(source.read_bytes());raw[offset] ^= 1
    (out/'corrupt.ssc').write_bytes(raw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', required=True, choices=['forward_plus', 'gl_compatibility'])
    parser.add_argument('--production', type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    checks = [];runs = []
    report = dict(renderer=args.renderer, checks=checks, runs=runs)
    def check(value, label):
        checks.append(dict(ok=bool(value), label=label))
        print(('PASS: ' if value else 'FAIL: ') + label, flush=True)
    command = [args.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy',
               '--rendering-method', args.renderer, '--resolution', '960x640', '--disable-vsync']
    def execute(extra, folder, timeout=180):
        start = time.monotonic();peak = swap = 0
        with (folder/'native.log').open('w') as log:
            process = subprocess.Popen(command+extra, stdout=log, stderr=subprocess.STDOUT)
            try:
                while process.poll() is None:
                    if time.monotonic()-start > timeout: raise TimeoutError(str(folder))
                    try:
                        fields = dict(line.split(':', 1) for line in Path(f'/proc/{process.pid}/status').read_text().splitlines() if ':' in line)
                        peak = max(peak, int(fields.get('VmRSS', '0 kB').split()[0]))
                        swap = max(swap, int(fields.get('VmSwap', '0 kB').split()[0]))
                    except FileNotFoundError: pass
                    time.sleep(.05)
            finally:
                if process.poll() is None: process.kill();process.wait()
        result = dict(name=folder.name, exit_code=process.returncode, seconds=time.monotonic()-start,
                      peak_rss_kib=peak, peak_swap_kib=swap)
        runs.append(result)
        check('ERROR:' not in (folder/'native.log').read_text(), folder.name+': clean native log')
        return result
    before = {str(p): digest(p) for p in out.glob('*.ssc')}
    if args.production:
        print('Hashing complete production capture before export…', flush=True)
        before[str(args.production)] = digest(args.production)
        (out/'production-path.txt').write_text(str(args.production.resolve()))
    try:
        execute(['--script', 'video/test_current_setup.gd', '--', str(out)], out)
        setup = json.loads((out/'setup.json').read_text())
        for item in setup['checks']: check(item['ok'], item['label'])
        cases = [('particles', 'complete'), ('late-particles', 'complete'), ('field', 'complete'), ('mesh', 'complete'), ('mixed', 'complete'),
                 ('mixed-repeat', 'complete'), ('mixed-ui', 'complete'), ('late', 'complete'),
                 ('overflow', 'failed'), ('budget', 'failed'), ('corrupt', 'failed')]
        if args.production: cases.append(('production', 'complete'))
        images = {}
        for name, expected in cases:
            kind = 'mixed' if name.startswith('mixed') else ('field' if name == 'corrupt' else name)
            folder = out/name;folder.mkdir()
            state = json.loads((out/(kind+'-state.json')).read_text())
            state['overlay_visible'] = name == 'mixed-ui'
            source = args.production if name == 'production' else out/((name if name == 'corrupt' else kind)+'.ssc')
            job = dict(version=1, capture_path=str(source), state=state, start_time=.75, end_time=1.25,
                       fps=4, playback_rate=1., width=960, height=540, output_path=str(folder/'result.mp4'),
                       camera_mode='orbit', orbit_speed=.08, quality='high', keep_frames=True,
                       inspection_sidecars=True, ffmpeg_path=shutil.which('ffmpeg'),
                       presentation=dict(workspace=1, scroll=0, remaining=True))
            if name == 'mixed-repeat': job['test_frame_delay_ms'] = 80
            if name == 'production':
                job.update(start_time=.1, end_time=.2, fps=30, width=1920, height=1080, inspection_sidecars=False)
            path = folder/'job.json';path.write_text(json.dumps(job))
            result = execute(['--script', 'video/test_current_worker.gd', '--', str(path)], folder, 300)
            progress = json.loads((folder/'progress.json').read_text())
            check(progress['stage'] == expected, name+': '+expected+' (got '+progress['stage']+')')
            if expected == 'failed':
                check(not Path(job['output_path']).exists(), name+': no misleading MP4 published')
                check(any(word in progress['message'].lower() for word in
                          {'overflow': ['float32'], 'budget': ['budget'], 'corrupt': ['checksum']}[name]), name+': actionable failure')
                continue
            if progress['stage'] != 'complete': continue
            check(result['exit_code'] == 0, name+': successful worker exit')
            result['frames_per_second_including_startup_and_encode'] = progress['current_frame']/result['seconds']
            info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                '-show_entries', 'stream=width,height,nb_frames,avg_frame_rate', '-of', 'json', job['output_path']]))['streams'][0]
            count = 3 if name == 'production' else 2
            check((info['width'], info['height'], int(info['nb_frames']), info['avg_frame_rate']) ==
                  (job['width'], job['height'], count, str(job['fps'])+'/1'), name+': MP4 dimensions/count/FPS')
            rows = [json.loads(line) for line in (folder/'timing.jsonl').read_text().splitlines()]
            check(np.allclose([r['capture_time'] for r in rows], [job['start_time']+n/job['fps'] for n in range(count)], rtol=0, atol=1e-14), name+': half-open output times within JSON decimal precision')
            evidence = json.loads((folder/'evidence.json').read_text())['frames']
            for n, frame in enumerate(evidence):
                t = job['start_time']+n/job['fps']
                check(frame['strict'] and not any(frame['async_workers']), name+f'/{n}: strict bounded synchronous offline path')
                check(frame['backend'] == args.renderer, name+f'/{n}: requested backend')
                check(frame['legends_visible'] == (name == 'mixed-ui'), name+f'/{n}: explicit scientific legend gate')
                initial = np.array(state['camera_transform'][3]);target = np.array(state['camera_target'])
                angle = .08*n/job['fps'];c, s = np.cos(angle), np.sin(angle)
                expected_camera = target+np.array([[c,0,s],[0,1,0],[-s,0,c]])@(initial-target)
                check(np.allclose(frame['camera'], expected_camera, atol=1e-5), name+f'/{n}: deterministic orbit')
                if name == 'production':
                    with SceneReader(source) as reader:
                        index = bisect.bisect_right([r['time'] for r in reader.samples['field']], t)-1
                        sample = reader.read_sample('field', index)
                        values = sample['psi_imag']
                    check(frame['field']['channel'] == 'psi_imag' and frame['field']['sha256'] == hashlib.sha256(values.tobytes()).hexdigest(), name+f'/{n}: exact requested production field source bytes')
                    if args.renderer == 'forward_plus':
                        check(frame['field']['texture_sha256'] == hashlib.sha256(values.astype('f4').tobytes()).hexdigest(), name+f'/{n}: exact uploaded float32 plane bytes')
                    check(frame['field']['lod'] == 1 and values.shape == (192,192,192), name+f'/{n}: full 192-cubed display')
                else:
                    if 'p' in frame:
                        check(rows[n]['color_channel'] == 'color_value', name+f'/{n}: requested particle mapping survives start-time restore')
                        check(frame['p']['ids'] == ['10', '20'] and np.allclose(frame['p']['positions'], [[-1+t,0,0],[1+t,0,0]]), name+f'/{n}: exact IDs and interpolated particle positions')
                    if 'mesh' in frame:
                        check(np.allclose(frame['mesh']['positions'], [[-1,-1,t/4],[1,-1,t/4],[0,1,t/4]]) and frame['mesh']['triangles'] == [0,2,1], name+f'/{n}: mesh interpolation and display winding')
                    if 'field' in frame:
                        values = (np.arange(512, dtype='f4')/512 + int(t/.5)/8).astype('f8')-.5
                        check(frame['field']['channel'] == 'psi_imag' and frame['field']['sha256'] == hashlib.sha256(values.tobytes()).hexdigest(), name+f'/{n}: selected exact float64 source channel')
                        if args.renderer == 'forward_plus':
                            check(frame['field']['texture_sha256'] == hashlib.sha256(values.astype('f4').tobytes()).hexdigest(), name+f'/{n}: exact uploaded float32 plane bytes')
                        check(frame['field']['lod'] == 1 and np.allclose(frame['field']['opacity'], [.15, .85, .4]) and frame['field']['range'] == [-.5, 1.], name+f'/{n}: full field and requested transfer state')
            images[name] = [Image.open(f).convert('RGB').tobytes() for f in sorted((folder/'frames').glob('*.png'))]
            check(sum(value > 20 for value in images[name][0]) > 100, name+': nonempty rendered image')
            if name == 'mixed-repeat':
                check(images['mixed'] == images[name], 'same-backend delayed mixed export has identical pixels')
                check((out/'mixed/timing.jsonl').read_bytes() == (folder/'timing.jsonl').read_bytes(), 'delayed mixed timing manifest identical')
            if name == 'mixed-ui': check(images[name] != images['mixed'], 'production UI and legends affect pixels')
        for path, checksum in before.items(): check(digest(Path(path)) == checksum, Path(path).name+': source bytes unchanged')
    except BaseException as exc:
        report['error'] = type(exc).__name__+': '+str(exc)
        raise
    finally:
        report['failures'] = sum(not c['ok'] for c in checks)
        report['status'] = 'FAIL' if report['failures'] or 'error' in report else 'PASS'
        (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f"CURRENT VIDEO: {len(checks)} checks, {report['failures']} failures", flush=True)
    return bool(report['failures'])


if __name__ == '__main__': sys.exit(main())

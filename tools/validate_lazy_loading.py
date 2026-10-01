"""Lazy startup, deferred corruption, bounded lookahead and explicit verification regression."""
import argparse
import hashlib
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader
from tests.scene_mutation import rewrite
from verify_ssc import verify


def prepare(out):
    with SceneCapture(out / 'channels.ssc', objects=[dict(id='field', kind='volume', units='u')]) as writer:
        for index in range(6):
            channels = {'rho': np.ones((2, 2, 2), dtype='f4')}
            if index == 5: channels['later'] = np.ones((2, 2, 2), dtype='f8') * 3
            writer.add_volume('field', index, channels, origin=[0, 0, 0], spacing=[1, 1, 1])
    with SceneCapture(out / 'hidden.ssc', objects=[dict(id=name, kind='volume', units='u') for name in ['visible', 'hidden']]) as writer:
        for name in ['visible', 'hidden']:
            writer.add_volume(name, 0, {'rho': np.ones((2, 2, 2), dtype='f4')}, origin=[0, 0, 0], spacing=[1, 1, 1])
    def bad_hidden(seq, row, desc, payload):
        if seq == 1: desc['arrays'][0]['shape'][0] = 1000000000
    rewrite(out / 'hidden.ssc', bad_hidden)
    for kind in ['particles', 'volume', 'mesh']:
        path = out / (kind + '.ssc')
        obj = dict(id='object', kind=kind, units='u')
        if kind == 'particles': obj['identity'] = 'persistent_i8'
        if kind == 'mesh': obj['identity'] = 'none'
        with SceneCapture(path, objects=[obj]) as w:
            for i in range(20):
                if kind == 'particles': w.add_particles('object', i, np.ones((3, 3), dtype='f4') * i, ids=[1, 2, 3])
                elif kind == 'volume': w.add_volume('object', i, {'rho': np.ones((2, 2, 2), dtype='f4') * i}, origin=[0, 0, 0], spacing=[1, 1, 1])
                else: w.add_mesh('object', i, np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], dtype='f4'), np.array([[0, 1, 2]], dtype='u4'))
        assert verify(path) == 20
        with SceneReader(path) as reader: record = reader.records[3]
        for fault in ['chunk_bounds', 'descriptor', 'commit', 'shape', 'header']:
            target = out / f'{kind}-{fault}.ssc'
            shutil.copyfile(path, target)
            if fault in ('shape', 'chunk_bounds'):
                def change(seq, row, desc, payload):
                    if seq == 3:
                        if fault == 'shape':desc['arrays'][0]['shape'][0] = 1000000000
                        else:desc['arrays'][0]['chunks'][0]['offset'] = str(1<<50)
                rewrite(target, change)
            else:
                raw = bytearray(target.read_bytes())
                if fault == 'descriptor': raw[record['offset'] - 1] ^= 1
                elif fault == 'commit': raw[record['end'] - 1] ^= 1
                else:
                    # Complete header with an unsafe declared decoded allocation.
                    # Locate FRM4 by walking fixed headers, independent of JSON formatting.
                    start = 16 + struct.unpack_from('<I', raw, 12)[0]
                    for _ in range(3):
                        dlen, stored = struct.unpack_from('<IQ', raw, start + 4)
                        start += 128 + dlen + stored
                    struct.pack_into('<Q', raw, start + 16, 1 << 40)
                target.write_bytes(raw)
            try: verify(target)
            except ValueError: pass
            else: raise AssertionError(f'Explicit verifier accepted {target}')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', default='headless', choices=['headless', 'forward_plus', 'gl_compatibility'])
    a = p.parse_args(); out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    prepare(out)
    hashes = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.ssc')}
    cmd = [a.godot, '--path', str(ROOT / 'viewer'), '--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log')]
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '1280x800']
    cmd += ['--script', 'layers/test_lazy_loading.gd', '--', str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr; (out / 'native.log').write_text(log); print(log)
    assert result.returncode == 0 and 'ERROR:' not in log
    assert all(hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha for path, sha in hashes.items())


if __name__ == '__main__': main()

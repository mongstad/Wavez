"""Fast structural playback versus independent strict verification, #107."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader, codec
from tests.scene_mutation import rewrite
from tools.verify_wvz import verify


def fixtures(out):
    cases = [];oracles = [];strict = []
    for compression in ('none', 'zstd'):
        for kind in ('volume', 'particles', 'mesh'):
            name = f'{kind}-{compression}';path = out/(name+'.wvz')
            obj = dict(id='object', kind=kind, units='u')
            if kind == 'particles':obj['identity'] = 'persistent_i8'
            if kind == 'mesh':obj['identity'] = 'stable_topology'
            with SceneCapture(path, objects=[obj], compression=compression) as writer:
                for i in range(6):
                    if kind == 'volume':
                        exact = np.arange(24, dtype='f8').reshape(2, 3, 4)/7+i
                        exact.flat[1:5] = [np.nan, np.inf, -np.inf, -0.]
                        writer.add_volume('object', i*.1, dict(rho=exact.astype('f4'), exact=exact), origin=[0]*3, spacing=[1]*3)
                    else:
                        positions = np.array([[i, 0, 0], [1, 0, 0], [0, 1, 0]], dtype='f8')
                        if kind == 'particles':writer.add_particles('object', i*.1, positions, ids=[1, 2, 9007199254740993])
                        else:writer.add_mesh('object', i*.1, positions, np.array([[0, 1, 2]], dtype='u4'), vertex_channels=dict(vertex_id=np.array([1, 2, 9007199254740993], dtype='i8')))
            assert verify(path) == 6
            with SceneReader(path) as reader:
                rows = []
                for i in range(6):
                    arrays = reader.read_sample('object', i)
                    rows.append(dict(time=reader.records[i]['time'], channels={k:hashlib.sha256(v.tobytes()).hexdigest() for k,v in arrays.items()}))
            oracles.append(dict(file=path.name, kind=kind, rows=rows))
            for fault in ('sha_only', 'stored_hash', 'raw_hash', 'offset', 'shape', 'codec', 'descriptor', 'commit', 'header', 'decode', 'bad_id', 'triangle'):
                if fault == 'decode' and compression != 'zstd':continue
                if fault == 'bad_id' and kind == 'volume':continue
                if fault == 'triangle' and kind != 'mesh':continue
                target = out/(name+'-'+fault+'.wvz');shutil.copyfile(path, target)
                def change(seq, record, desc, payload):
                    if seq != 3:return
                    array = desc['arrays'][0]
                    if fault == 'bad_id':array = next(a for a in desc['arrays'] if a['name'] == ('particle_id' if kind == 'particles' else 'vertex_id'))
                    if fault == 'triangle':array = next(a for a in desc['arrays'] if a['name'] == 'triangles')
                    part = array['chunks'][0]
                    if fault in ('sha_only', 'decode', 'bad_id', 'triangle'):
                        start = int(part['offset']);end = start+int(part['stored']);stored = bytes(payload[start:end])
                        if fault == 'decode':
                            # Outer frame stays valid; its content checksum fails in native zstd.
                            assert stored[4]&4
                            changed = stored[:-1]+bytes([stored[-1]^1])
                            codec.validate_zstd_header(changed, int(part['decoded']))
                            try:codec.decode(changed, int(part['decoded']), 1)
                            except ValueError:pass
                            else:raise AssertionError('Expected native decoding failure')
                        else:
                            raw = bytearray(codec.decode(stored, int(part['decoded']), part['codec']))
                            if fault == 'bad_id':struct.pack_into('<q', raw, 0, -1)
                            elif fault == 'triangle':struct.pack_into('<I', raw, 0, 0xffffffff)
                            else:raw[0] ^= 1
                            changed = codec.encode(bytes(raw), part['codec'])
                        payload[start:end] = changed;part['stored'] = str(len(changed))
                        offset = 0
                        for array in desc['arrays']:
                            for chunk in array['chunks']:chunk['offset'] = str(offset);offset += int(chunk['stored'])
                        # SHA fields intentionally retain the original content digests.
                    elif fault in ('stored_hash', 'raw_hash'):part['stored_sha256' if fault == 'stored_hash' else 'raw_sha256'] = '0'*64
                    elif fault == 'offset':part['offset'] = str(1<<50)
                    elif fault == 'shape':desc['arrays'][0]['shape'][0] = 1000000000
                    elif fault == 'codec':part['codec'] = 999
                if fault in ('descriptor', 'commit', 'header'):
                    with SceneReader(path) as reader:record = reader.records[3]
                    raw = bytearray(target.read_bytes())
                    offset = record['offset']-1 if fault == 'descriptor' else record['end']-1
                    if fault == 'header':
                        start = 16+struct.unpack_from('<I', raw, 12)[0]
                        for _ in range(3):
                            dlen, stored = struct.unpack_from('<IQ', raw, start+4);start += 128+dlen+stored
                        struct.pack_into('<Q', raw, start+16, 1<<40)
                    else:raw[offset] ^= 1
                    target.write_bytes(raw)
                else:rewrite(target, change)
                try:verify(target)
                except ValueError as error:strict.append(dict(file=target.name, error=str(error)))
                else:raise AssertionError('Strict verifier accepted '+target.name)
                cases.append(dict(file=target.name, kind=kind, fault=fault, readable=fault in ('sha_only', 'stored_hash', 'raw_hash')))
    # Native malformed metadata is rejected before any payload operation.
    raw = bytearray((out/'volume-none.wvz').read_bytes());raw[16] = ord('[')
    (out/'bad-metadata.wvz').write_bytes(raw)
    # Same content under a different name/directory has identical semantics.
    (out/'moved').mkdir();shutil.copyfile(out/'volume-zstd.wvz', out/'moved/renamed.wvz')
    shutil.copyfile(out/'volume-zstd.wvz', out/'moved/renamed.data')
    shutil.copyfile(out/'volume-none.wvz', out/'working.wvz')
    report = dict(cases=cases, oracles=oracles, strict_rejections=strict)
    (out/'fixtures.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True);p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    report = fixtures(out)
    hashes = {str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in out.rglob('*.wvz') if f.name != 'working.wvz'}
    command = [a.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy']
    command += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '960x640']
    command += ['--script', 'layers/test_payload_integrity.gd', '--', str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    log = result.stdout+result.stderr;(out/'native.log').write_text(log);print(log)
    assert result.returncode == 0, log
    # Godot emits its own error on deliberately invalid zstd data. Nothing else is allowed.
    errors = [line for line in log.splitlines() if 'ERROR:' in line]
    assert all('decompress' in line.lower() for line in errors), errors
    native = json.loads((out/'checks.json').read_text());assert not native['failures']
    assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest() == digest for f,digest in hashes.items())
    (out/'summary.json').write_text(json.dumps(dict(native=native, strict_cases=len(report['strict_rejections']), expected_native_decode_errors=errors, unchanged_sources=True), indent=2)+'\n')


if __name__ == '__main__':main()

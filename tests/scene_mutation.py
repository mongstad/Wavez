"""Mutate disposable uncompressed scene fixtures with consistent checksums."""
import copy
import hashlib
import struct
import numpy as np
from wavez_export import SceneReader
from wavez_export import storage


def rewrite(path, change):
    with SceneReader(path) as reader:
        raw = path.read_bytes()
        start = 16 + struct.unpack_from('<I', raw, 12)[0]
        rows = [(copy.deepcopy(r), raw[r['offset']:r['end']-storage.COMMIT.size]) for r in reader.records]
        objects = list(reader.objects)
    output = bytearray(raw[:start])
    for seq, (record, payload) in enumerate(rows):
        desc = record['descriptor']
        payload = bytearray(payload)
        change(seq, record, desc, payload)
        encoded = storage.dumps(desc)
        header = storage.FRAME.pack(b'FRM4', len(encoded), len(payload), record['decoded'], record['time'],
                                    objects.index(record['object']), len(desc['arrays']), seq, hashlib.sha256(encoded).digest())
        output += header + encoded + payload + storage.COMMIT.pack(b'COMMIT4\0', seq, hashlib.sha256(header+encoded).digest())
    path.write_bytes(output)


def set_ids(seq, record, desc, payload, values):
    channel = next(a for a in desc['arrays'] if a['name'] == 'particle_id')
    chunk = channel['chunks'][0]
    assert chunk['codec'] == 0 and len(channel['chunks']) == 1
    raw = np.asarray(values, dtype='<i8').tobytes()
    assert len(raw) == int(chunk['decoded'])
    start = int(chunk['offset'])
    payload[start:start+len(raw)] = raw
    chunk['raw_sha256'] = chunk['stored_sha256'] = storage.sha(raw)

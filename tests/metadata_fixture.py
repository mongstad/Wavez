"""Small scientific payload with more than 32 MiB of real writer descriptors."""
import hashlib
import struct
import numpy as np
from simscope_export import SceneCapture


def arrays(index):
    # Includes exact float64 detail, nonfinite values and signed zero.
    values = np.array([-0., 1.+2**-40, -3., np.nan, np.inf, -np.inf, index, .25], dtype='<f8').reshape(2, 2, 2)
    return {f'field_{i:02d}': values for i in range(64)}


def generate(path, target=34*1024**2):
    charge = 0
    i = 0
    with SceneCapture(path, objects=[dict(id='field', kind='volume', units='u')]) as writer:
        while charge <= target:
            before = writer.file.tell()
            fields = arrays(i)
            writer.add_volume('field', i*.125, fields, origin=[0, 0, 0], spacing=[1, 2, 3])
            charge += writer.file.tell()-before-sum(a.nbytes for a in fields.values())
            i += 1
    chosen = sorted({0, i//2, i-1})
    report = dict(records=i, aggregate_descriptor_charge=charge, bytes=path.stat().st_size,
                  oracle=[dict(index=j, time=j*.125, sha256=hashlib.sha256(arrays(j)['field_00'].tobytes()).hexdigest()) for j in chosen])
    with path.open('rb') as f:
        _, _, n = struct.unpack('<8sII', f.read(16))
        offset = 16+n
        for j in range(i):
            f.seek(offset)
            _, dlen, stored, decoded, time, oi, count, seq, digest = struct.unpack('<4sIQQdIIQ32s', f.read(80))
            report['last'] = dict(header=offset, descriptor=offset+80, payload=offset+80+dlen, commit=offset+80+dlen+stored)
            offset += 128+dlen+stored
    return report

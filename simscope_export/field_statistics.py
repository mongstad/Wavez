"""Required SIMSCP4 statistics_v1: exact counts and binary float64 extrema."""
import math
import re
import struct

import numpy as np


def summarize(values):
    finite = np.isfinite(values)
    count = int(np.count_nonzero(finite))
    selected = values[finite]
    return dict(
        minimum=struct.pack('<d', float(selected.min())).hex() if count else None,
        maximum=struct.pack('<d', float(selected.max())).hex() if count else None,
        finite=count,
        nonfinite=int(values.size)-count,
        nonpositive=int(np.count_nonzero(selected <= 0)),
    )


def validate(summary, count):
    if not isinstance(summary, dict) or set(summary) != {
        'minimum', 'maximum', 'finite', 'nonfinite', 'nonpositive'
    }:
        raise ValueError('Invalid statistics_v1 fields')
    for key in ('finite', 'nonfinite', 'nonpositive'):
        if type(summary[key]) is not int or not 0 <= summary[key] <= count:
            raise ValueError('Invalid statistics_v1 count')
    n = summary['finite']
    if n + summary['nonfinite'] != count or summary['nonpositive'] > n:
        raise ValueError('Inconsistent statistics_v1 counts')
    extrema = []
    for key in ('minimum', 'maximum'):
        value = summary[key]
        if not n:
            if value is not None:
                raise ValueError('Empty statistics_v1 must have null extrema')
        else:
            if not isinstance(value, str) or not re.fullmatch('[a-f0-9]{16}', value):
                raise ValueError('Invalid statistics_v1 binary extremum')
            number = struct.unpack('<d', bytes.fromhex(value))[0]
            if not math.isfinite(number):
                raise ValueError('Nonfinite statistics_v1 extremum')
            extrema.append(number)
    if n and (extrema[0] > extrema[1]
              or (extrema[0] > 0) != (summary['nonpositive'] == 0)
              or (extrema[1] <= 0) != (summary['nonpositive'] == n)):
        raise ValueError('Inconsistent statistics_v1 extrema')


def verify(summary, values):
    """Recompute against authoritative source; signed-zero extrema are equivalent."""
    expected = summarize(values)
    for key, value in expected.items():
        if key in ('minimum', 'maximum') and value is not None:
            if struct.unpack('<d', bytes.fromhex(value))[0] == struct.unpack('<d', bytes.fromhex(summary[key]))[0]:
                continue
        if summary[key] != value:
            raise ValueError('statistics_v1 differs from source values: ' + key)

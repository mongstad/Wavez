"""Explicit, read-only whole-capture SSC verification (never part of viewer startup)."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from simscope_export import SceneReader
from simscope_export.field_statistics import verify as verify_statistics


def verify(path):
    # Strict scan checks every descriptor and commit; zero cache bounds residency
    # to the requested sample and its decoder temporaries.
    with SceneReader(path, strict=True, cache_bytes=0) as reader:
        count = 0
        for object_id, records in reader.samples.items():
            for index, record in enumerate(records):
                try:
                    arrays = reader.read_sample(object_id, index)
                    for spec in record['descriptor']['arrays']:
                        if 'statistics_v1' in spec:
                            verify_statistics(spec['statistics_v1'], arrays[spec['name']])
                except (ValueError, OSError) as error:
                    raise ValueError(f'{object_id} sample {index} (record {record["sequence"]}): {error}') from error
                count += 1
        return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    try:
        count = verify(args.capture)
    except (ValueError, OSError) as error:
        parser.exit(1, f'Verification failed: {error}\n')
    print(f'Verified {count} records: descriptors, commit proofs, decoded payload checksums, sample constraints and required field statistics.')


if __name__ == '__main__':
    main()

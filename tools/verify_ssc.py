"""Explicit, read-only whole-capture SSC verification (never part of viewer startup)."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wavez_export import SceneReader, MetadataCapacityError
from wavez_export.metadata_budget import DEFAULT_METADATA_BYTES
from wavez_export.field_statistics import verify as verify_statistics


def verify(path, *, metadata_bytes=DEFAULT_METADATA_BYTES):
    # Strict scan admits retained descriptors separately from decoded samples.
    with SceneReader(path, strict=True, cache_bytes=0, metadata_bytes=metadata_bytes) as reader:
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
    parser.add_argument('--metadata-mib', type=int, default=DEFAULT_METADATA_BYTES//1024**2)
    args = parser.parse_args()
    if args.metadata_mib <= 0:parser.error('--metadata-mib must be positive')
    try:
        count = verify(args.capture, metadata_bytes=args.metadata_mib*1024**2)
    except MetadataCapacityError as error:
        parser.exit(2, f'Reader capacity exceeded (capture validity undetermined): {error}\n')
    except (ValueError, OSError) as error:
        parser.exit(1, f'Verification failed: {error}\n')
    print(f'Verified {count} records: descriptors, commit proofs, decoded payload checksums, sample constraints and required field statistics.')


if __name__ == '__main__':
    main()

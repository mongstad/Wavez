"""Reader resource admission, independent of WVZ1 wire validity.

Charges cover owned Python objects, index bookkeeping and bounded JSON scratch.
They are allocation estimates, not a whole-process RSS or allocator guarantee.
"""
import sys

DEFAULT_METADATA_BYTES = 512 * 1024 * 1024
PARSE_FACTOR = 64
RECORD_OVERHEAD = 4096
MAX_READER_RECORDS = 1_000_000


class MetadataCapacityError(MemoryError):
    """A valid capture may need a larger reader metadata budget."""


def object_bytes(value):
    """Count a JSON/record object graph once, without recursive Python calls."""
    pending = [value]
    seen = set()
    total = 0
    while pending:
        item = pending.pop()
        key = id(item)
        if key in seen:
            continue
        seen.add(key)
        total += sys.getsizeof(item)
        if isinstance(item, dict):
            pending.extend(item.keys())
            pending.extend(item.values())
        elif isinstance(item, (list, tuple)):
            pending.extend(item)
    return total


class MetadataBudget:
    def __init__(self, limit=DEFAULT_METADATA_BYTES, *, acquire=None, release=None):
        if type(limit) is not int or limit <= 0:
            raise ValueError('metadata_bytes must be a positive integer')
        self.limit = limit
        self.used = self.peak = 0
        self.acquire = acquire
        self.release = release

    def reserve(self, wire_bytes):
        # Includes the raw/UTF buffers, parsed tree, hashing copies and the
        # object-size walk. Retained accounting replaces scratch after parsing.
        amount = PARSE_FACTOR * wire_bytes + RECORD_OVERHEAD
        if self.used + amount > self.limit:
            raise MetadataCapacityError(
                f'Reader metadata capacity exceeded: need {self.used + amount} bytes, '
                f'budget {self.limit}. Increase metadata_bytes; capture validity is unchanged.')
        if self.acquire is not None:
            self.acquire(amount)
        self.used += amount
        self.peak = max(self.peak, self.used)
        return amount

    def retain(self, reservation, value):
        amount = object_bytes(value) + RECORD_OVERHEAD
        if amount > reservation:
            raise MetadataCapacityError('Reader metadata exceeds its parsing workspace allowance')
        self._release(reservation - amount)

    def _release(self, amount):
        if self.release is not None:
            self.release(amount)
        self.used -= amount

    def clear(self):
        self._release(self.used)

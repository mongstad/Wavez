"""Three synthetic points with persistent identity; no physics solver required."""
import argparse
from pathlib import Path

import numpy as np
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("results/getting-started/particles.wvz"))
    path = parser.parse_args().output.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)

    # One particle object groups all three points in viewer-world coordinates.
    objects = [dict(id="points", kind="particles", units="example length",
                    identity="persistent_i8")]
    positions = np.array([[-0.8, 0, 0], [0, 0.4, 0], [0.8, 0, 0]], dtype="f8")
    # These IDs belong to this example and stay with the same points at every time.
    ids = np.array([10, 20, 30], dtype="i8")
    metadata = {"purpose": "synthetic positions, not a physical simulation",
                "time_unit": "s", "position_unit": "example length"}

    # A new destination is required; the context manager closes even on failure.
    with SceneCapture(path, objects=objects, metadata=metadata) as capture:
        for time in (0.0, 0.5, 1.0):
            # Float64 (N,3) positions move upward at recorded example times.
            capture.add_particles("points", time, positions + [0, time, 0], ids=ids)
    print(path.resolve())


if __name__ == "__main__":
    main()

"""A synthetic scalar mound on a small, noncubic uniform grid."""
import argparse
from pathlib import Path

import numpy as np
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("results/getting-started/field.wvz"))
    path = parser.parse_args().output.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)

    objects = [dict(id="field", kind="volume", units="dimensionless")]
    # Geometry uses xyz; storage uses (nz,ny,nx), with x varying fastest.
    origin = np.array([-1.0, -0.75, -0.5], dtype="f8")
    spacing = np.array([0.2, 0.25, 0.25], dtype="f8")
    z, y, x = np.indices((5, 7, 11), dtype="f8")
    x = origin[0] + spacing[0] * x
    y = origin[1] + spacing[1] * y
    z = origin[2] + spacing[2] * z
    metadata = {"purpose": "synthetic scalar shape, not density or mass",
                "time_unit": "s", "position_unit": "example length",
                "channel_metadata": {"field": {"amplitude": {
                    "units": "dimensionless", "meaning": "exp(-4*r_squared)"}}}}

    with SceneCapture(path, objects=objects, metadata=metadata) as capture:
        for time in (0.0, 0.5, 1.0):
            # This analytic mound shifts in x; it does not integrate any physics.
            amplitude = np.exp(-4 * ((x - 0.3 * time)**2 + y**2 + z**2))
            # Origin is the first node, not a cell face; fields share this grid.
            capture.add_volume("field", time, {"amplitude": amplitude},
                               origin=origin, spacing=spacing, centering="node")
    print(path.resolve())


if __name__ == "__main__":
    main()

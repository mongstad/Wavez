"""Synthetic points, scalar grid and static triangle on independent clocks."""
import argparse
from pathlib import Path

import numpy as np
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("results/getting-started/combined.wvz"))
    path = parser.parse_args().output.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)

    # All three objects share example coordinates, with no implied physical relation.
    objects = [
        dict(id="points", kind="particles", units="example length", identity="persistent_i8"),
        dict(id="field", kind="volume", units="dimensionless"),
        dict(id="triangle", kind="mesh", units="example length", identity="none", static=True),
    ]
    points = np.array([[-0.8, 0, 0.7], [0, 0.4, 0.7], [0.8, 0, 0.7]], dtype="f8")
    ids = np.array([10, 20, 30], dtype="i8")
    # The static triangle lies beneath the grid; its indices have upward winding.
    vertices = np.array([[-1, -0.9, -0.8], [0, -0.9, 1], [1, -0.9, -0.8]], dtype="f8")
    triangles = np.array([[0, 1, 2]], dtype="u4")
    origin = np.array([-1.0, -0.75, -0.5], dtype="f8")
    spacing = np.array([0.2, 0.25, 0.25], dtype="f8")
    # Build coordinates in storage order (z,y,x), then apply xyz geometry.
    z, y, x = np.indices((5, 7, 11), dtype="f8")
    x, y, z = origin[0] + spacing[0]*x, origin[1] + spacing[1]*y, origin[2] + spacing[2]*z
    metadata = {"purpose": "synthetic combined scene, not a physics model",
                "time_unit": "s", "position_unit": "example length",
                "channel_metadata": {"field": {"amplitude": {
                    "units": "dimensionless", "meaning": "exp(-4*r_squared)"}}}}

    with SceneCapture(path, objects=objects, metadata=metadata) as capture:
        # Static geometry has one sample and is reusable throughout the scene.
        capture.add_mesh("triangle", 0.0, vertices, triangles)
        for time in (0.0, 0.5, 1.0):
            capture.add_particles("points", time, points + [0, 0.2*time, 0], ids=ids)
            # Fields are recorded less often and hold between their source samples.
            if time in (0.0, 1.0):
                amplitude = np.exp(-4 * ((x - 0.3*time)**2 + y**2 + z**2))
                capture.add_volume("field", time, {"amplitude": amplitude},
                                   origin=origin, spacing=spacing, centering="node")
    print(path.resolve())


if __name__ == "__main__":
    main()

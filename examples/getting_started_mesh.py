"""A synthetic triangle whose top vertex moves, with unchanged topology."""
import argparse
from pathlib import Path

import numpy as np
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=Path("results/getting-started/mesh.wvz"))
    path = parser.parse_args().output.expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)

    objects = [dict(id="triangle", kind="mesh", units="example length",
                    identity="stable_topology")]
    vertices = np.array([[-0.8, -0.5, 0], [0.8, -0.5, 0], [0, 0.7, 0]], dtype="f8")
    # Zero-based indices wind counterclockwise when viewed from positive z.
    triangles = np.array([[0, 1, 2]], dtype="u4")
    vertex_ids = np.array([100, 200, 300], dtype="i8")
    metadata = {"purpose": "synthetic deformation, not a material surface",
                "time_unit": "s", "position_unit": "example length"}

    with SceneCapture(path, objects=objects, metadata=metadata) as capture:
        for time in (0.0, 0.5, 1.0):
            # Copy before deforming so the starting geometry remains unchanged.
            positions = vertices.copy()
            positions[2, 0] += 0.4 * time
            # Stable topology requires explicit int64 IDs associated with vertices.
            capture.add_mesh("triangle", time, positions, triangles,
                             vertex_channels={"vertex_id": vertex_ids})
    print(path.resolve())


if __name__ == "__main__":
    main()

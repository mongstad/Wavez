"""Generate the local stationary Gaussian used by volume_pixels_probe.gd."""
import argparse
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from wavez_export import SceneCapture


def generate(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    z, y, x = np.indices((65, 65, 65))
    xx, yy, zz = x * 1.5 - 48, y * 1.5 - 48, z * 1.5 - 48
    density = np.exp(-((xx - 12)**2 + (yy + 9)**2 + (zz - 6)**2) / (2 * 3**2)).astype("f8")
    with SceneCapture(path, objects=[dict(id="field", kind="volume", units="m")], compression="none") as writer:
        for time in (0., 1.):
            writer.add_volume("field", time, dict(density=density), origin=[-48] * 3, spacing=[1.5] * 3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    generate(parser.parse_args().output)

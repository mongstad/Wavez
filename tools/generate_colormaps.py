"""Development-only generator; Godot has no Python/Matplotlib dependency."""
import json
from pathlib import Path
import numpy as np
from matplotlib import colormaps
names = 'viridis plasma inferno magma cividis turbo coolwarm seismic twilight gray'.split()
output = {name: colormaps[name](np.linspace(0,1,256))[:,:3].round(7).tolist() for name in names}
Path('viewer/colormaps.json').write_text(json.dumps(output,separators=(',',':')))

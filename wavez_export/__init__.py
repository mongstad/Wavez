"""Native scientific scenes: SIMSCP4 / .ssc."""
from .scene import SceneCapture, SceneReader
from .metadata_budget import MetadataCapacityError

__all__ = ['SceneCapture', 'SceneReader', 'MetadataCapacityError']
__version__ = '2.0.0'

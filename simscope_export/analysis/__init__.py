"""Read-only scientific analysis; independent of viewer/GPU representations.

This package is an internal G4 interface. It is not a local control service.
"""

from .contracts import AnalysisError, Cancelled, Context
from .source import SourceSnapshot

__all__ = ["AnalysisError", "Cancelled", "Context", "SourceSnapshot"]

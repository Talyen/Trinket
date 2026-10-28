#!/usr/bin/env python3
"""Print an optional scope token; failures leave the lease conservative."""
import sys
import subprocess
from pathlib import Path
from internal.resource_lease import make_scope

try:
    print(make_scope(int(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]))
except (OSError, ValueError, IndexError, subprocess.SubprocessError):
    sys.exit(1)

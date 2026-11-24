"""Package entry point: python3 -m functions runs the full self-test."""

import sys

from .testing import run_all

sys.exit(run_all())

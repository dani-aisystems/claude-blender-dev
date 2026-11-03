"""Shared helpers for Blender Dev scripts.

Scripts add ``scripts/`` to ``sys.path`` and then ``from lib import ...``.
Works in headless Blender (``tools/bl``) and in a live session
(``runpy.run_path(path, run_name="__main__")`` via the MCP).
"""

from pathlib import Path

WORKSPACE = Path(__file__).resolve().parents[2]
SCRIPTS = WORKSPACE / "scripts"

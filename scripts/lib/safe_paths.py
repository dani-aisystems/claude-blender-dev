"""Path guards: outputs stay inside the workspace (or the system temp dir) and never overwrite."""

import re
import tempfile
from pathlib import Path

from . import WORKSPACE

_ALLOWED_ROOTS = (WORKSPACE.resolve(), Path(tempfile.gettempdir()).resolve(), Path("/private/tmp").resolve())


class UnsafePathError(RuntimeError):
    pass


def ensure_allowed(path) -> Path:
    """Resolve *path* and raise unless it is inside the workspace or temp dir."""
    p = Path(path).expanduser()
    if not p.is_absolute():
        p = WORKSPACE / p
    p = p.resolve()
    if not any(p == root or root in p.parents for root in _ALLOWED_ROOTS):
        raise UnsafePathError(f"Refusing to write outside the workspace/temp: {p}")
    return p


_VERSION_RE = re.compile(r"^(?P<stem>.+)_v(?P<n>\d{3,})$")


def next_version_path(directory, name: str, ext: str = ".blend") -> Path:
    """Return ``directory/name_vNNN.ext`` with NNN one above the highest existing version."""
    d = ensure_allowed(directory)
    d.mkdir(parents=True, exist_ok=True)
    highest = 0
    for f in d.glob(f"{name}_v*{ext}"):
        m = _VERSION_RE.match(f.stem)
        if m and m.group("stem") == name:
            highest = max(highest, int(m.group("n")))
    return d / f"{name}_v{highest + 1:03d}{ext}"


def no_overwrite(path) -> Path:
    """Return *path* (guarded) if it does not exist; otherwise raise."""
    p = ensure_allowed(path)
    if p.exists():
        raise FileExistsError(f"Refusing to overwrite existing file: {p} (ask the user first)")
    p.parent.mkdir(parents=True, exist_ok=True)
    return p

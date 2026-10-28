"""Owned, bounded scratch space for derived profiling XML; raw evidence is separate."""
from __future__ import annotations

from contextlib import contextmanager
import fcntl
import json
from pathlib import Path
import resource
import tempfile

PREFIX = "trinket-profile-exports-"
SCRATCH_BUDGET = 1024 ** 3


def limit_export_file(size: int) -> None:
    """Runs only in the export child, never changes the caller's resource limits."""
    resource.setrlimit(resource.RLIMIT_FSIZE, (size, size))


def scratch_bytes(root: Path) -> int:
    total = 0
    for directory in root.glob(PREFIX + "*"):
        if directory.is_symlink():
            raise ValueError("Symlink in profiling export scratch space; inspect it before exporting")
        if not directory.is_dir():
            continue
        for item in directory.rglob("*"):
            if item.is_symlink():
                raise ValueError("Symlink in profiling export scratch space; inspect it before exporting")
            if item.is_file():
                total += item.stat().st_size
                if total >= SCRATCH_BUDGET:
                    return total
    return total


@contextmanager
def measurement_exports(output: Path, retain: bool, limit: int, *, scratch: Path | None = None):
    """Default intermediates disappear on exit; retained exports have an explicit pin.

    Refuse a full scratch area rather than silently purging old or active data.
    The lock serializes new scratch export groups without process inspection.
    """
    if retain:
        destination = output / "exports"
        destination.mkdir(exist_ok=False)
        (destination / ".retention-keep").write_text("Explicit profiling investigation pin; release when finished.\n")
        (destination / "retention.json").write_text(json.dumps({
            "kind": "derived-profiling-exports", "pinned": True,
            "raw_trace": "../recording.trace", "maximum_file_bytes": limit,
        }, indent=2) + "\n")
        yield destination
        return
    temporary = scratch or Path(tempfile.gettempdir())
    with (temporary / "trinket-profile-exports.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError("Another temporary profiling export is active; raw traces remain available") from error
        # The producer creates at most three XML files. Existing crash remnants
        # are counted but never deleted by this command.
        if 3 * limit + scratch_bytes(temporary) > SCRATCH_BUDGET:
            raise ValueError("Profiling export scratch budget exceeded; inspect remnants or explicitly pin exports")
        with tempfile.TemporaryDirectory(prefix=PREFIX, dir=temporary) as name:
            yield Path(name)


class BoundedLog:
    """Keep a command's beginning and final diagnostics within a fixed byte budget."""
    marker = b"\n[profiling log clipped; final diagnostics follow]\n"

    def __init__(self, path: Path, maximum: int = 4 * 1024 ** 2):
        self.tail_limit = min(65536, maximum // 4)
        self.head_left = maximum - self.tail_limit - len(self.marker)
        if self.head_left < 1:
            raise ValueError("Profiling log budget is too small")
        self.stream = path.open("wb")
        self.tail = b""
        self.clipped = False

    def __enter__(self):
        return self

    def write(self, chunk: bytes) -> None:
        head = chunk[:self.head_left]
        self.stream.write(head)
        self.head_left -= len(head)
        remaining = chunk[len(head):]
        if remaining:
            self.clipped |= len(self.tail) + len(remaining) > self.tail_limit
            self.tail = (self.tail + remaining)[-self.tail_limit:]

    def flush(self) -> None:
        self.stream.flush()

    def __exit__(self, *exception):
        try:
            if self.clipped:
                self.stream.write(self.marker)
            self.stream.write(self.tail)
        finally:
            self.stream.close()

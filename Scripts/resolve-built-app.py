#!/usr/bin/env python3
"""Find the app identified by a successful Xcode build's own task output."""

from pathlib import Path
import shlex
import sys


def main() -> int:
    candidates = set()
    suffix = " (in target 'Trinket' from project 'Trinket')"
    try:
        with Path(sys.argv[1]).open(encoding='utf-8', errors='replace') as log:
            for line in log:
                line = line.rstrip('\n')
                if not line.endswith(suffix):
                    continue
                task = line[:-len(suffix)]
                if not task.startswith(('CopySwiftLibs ', 'CodeSign ', 'ProcessInfoPlistFile ', 'Touch ')):
                    continue
                fields = shlex.split(task)
                if len(fields) < 2:
                    return 1
                path = Path(fields[1])
                if fields[0] == 'ProcessInfoPlistFile':
                    if path.name != 'Info.plist':
                        continue
                    path = path.parent
                if path.is_absolute() and path.suffix == '.app':
                    candidates.add(path)
    except (IndexError, OSError, ValueError):
        return 1
    if len(candidates) != 1:
        return 1
    app = candidates.pop()
    if not app.is_dir() or not (app / 'Info.plist').is_file():
        return 1
    print(app)
    return 0


if __name__ == '__main__':
    sys.exit(main())

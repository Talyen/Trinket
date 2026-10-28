"""Enumerate registered task checkouts for guarded compiler-cache maintenance."""

from pathlib import Path
import subprocess

from internal import output_retention as retention


def task_worktrees(root: Path) -> list[Path]:
    result = subprocess.run(['git', '-C', str(root), 'worktree', 'list', '--porcelain', '-z'],
                            capture_output=True, text=True, timeout=10, check=True)
    boundary = root / '.worktrees'
    if boundary.is_symlink():
        raise ValueError('Worktree directory is a symlink')
    paths = []
    for record in result.stdout.rstrip('\0').split('\0\0')[1:]:
        fields = record.split('\0')
        name = next((x[9:] for x in fields if x.startswith('worktree ')), '')
        if not name or any(x.startswith(('locked', 'prunable')) for x in fields):
            continue
        path = Path(name)
        if (path.parent != boundary or path.is_symlink() or not path.is_dir()
                or (path / '.git').is_symlink() or not (path / '.git').is_file()):
            continue
        paths.append(path)
    return paths


def cleanup(root: Path, *, apply: bool, products: bool) -> tuple[int, int]:
    total = size = 0
    for path in task_worktrees(root):
        # Registrations can change while a scan is in progress. Unknown paths
        # never become candidates merely because they resemble a checkout.
        if path not in task_worktrees(root):
            print(f'SKIP {path}: worktree registration changed')
            continue
        print(f'Worktree: {path}')
        count, allocated = retention.cleanup(path, apply=apply, intermediates_only=True, products=products)
        total += count
        size += allocated
    print(f'{"Removed" if apply else "Eligible"} worktree cache roots: {total}, {size} allocated bytes.')
    return total, size

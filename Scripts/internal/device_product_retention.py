"""Prove a device product has independently retained binaries and symbols."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess

from internal import build_symbols as symbols

MACHO = {bytes.fromhex(value) for value in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                             'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}


def retained_binary(root: Path, item: dict) -> bool:
    relative = Path(item['path'])
    if relative.is_absolute() or '..' in relative.parts:
        return False
    target = root / relative
    if any(path.is_symlink() for path in (target, *target.parents) if path.is_relative_to(root)):
        return False
    return target.is_file() and symbols.digest(target) == item['sha256']


def verified_profiles(binaries: list[dict]) -> list[tuple[Path, dict]]:
    root = symbols.artifact_root() / 'profiles'
    if root.is_symlink() or not root.is_dir():
        return []
    results = []
    for profile in root.iterdir():
        result, saved = profile / 'result.json', profile / 'symbols'
        if (profile.is_symlink() or not profile.is_dir() or result.is_symlink()
                or saved.is_symlink() or not saved.is_dir()):
            continue
        try:
            data = json.loads(result.read_text())
            manifest = saved / 'symbol-manifest.json'
            if (data.get('status') != 'passed' or data.get('buildSymbols', {}).get('binaries') != binaries
                    or manifest.is_symlink()):
                continue
            if any(path.is_symlink() for path in saved.rglob('*')):
                continue
            recorded = json.loads(manifest.read_text())['files']
            actual = symbols.tree_hashes(saved)
            actual.pop('symbol-manifest.json', None)
            if actual != recorded:
                continue
            results.append((profile, data))
        except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError):
            continue
    return results


def verified_device_products(products: Path) -> bool:
    """Require exact app binaries and every dSYM in successful retained profiles."""
    try:
        if products.is_symlink() or not products.is_dir():
            return False
        configs = list(products.iterdir())
        if not configs or any(path.is_symlink() or not path.is_dir() or path.name not in
                              ('Debug-iphoneos', 'Release-iphoneos') for path in configs):
            return False
        for config in configs:
            apps = list(config.glob('*.app'))
            bundles = list(config.rglob('*.dSYM'))
            if len(apps) != 1 or not bundles or any(p.is_symlink() for p in [*apps, *bundles]):
                return False
            # Unrecognized binaries or evidence cannot be justified by this app's backup.
            for path in config.rglob('*'):
                if path.is_symlink():
                    return False
                if path.suffix in ('.xctest', '.xcarchive', '.trace', '.ipa', '.dylib'):
                    return False
                if (path.suffix in ('.framework', '.appex', '.app') and path != apps[0]
                        and not path.is_relative_to(apps[0])):
                    return False
                if (path.is_file() and not path.is_relative_to(apps[0])
                        and not any(path.is_relative_to(bundle) for bundle in bundles)):
                    with path.open('rb') as stream:
                        if stream.read(4) in MACHO:
                            return False
            current = symbols.app_manifest(apps[0], config)
            profiles = verified_profiles(current['binaries'])
            if not profiles:
                return False
            required = [symbols.tree_hashes(bundle) for bundle in bundles]
            matched = False
            for profile, _result in profiles:
                binaries = profile / 'Binaries'
                if binaries.is_symlink() or not binaries.is_dir():
                    continue
                if not all(retained_binary(binaries, item) for item in current['binaries']):
                    continue
                saved_bundles = [symbols.tree_hashes(path) for path in (profile / 'symbols').rglob('*.dSYM')
                                 if path.is_dir() and not path.is_symlink()]
                if all(bundle in saved_bundles for bundle in required):
                    matched = True
                    break
            if not matched:
                return False
        return True
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        return False

#!/usr/bin/env python3
"""Local source preparation records and source-free shipping-output verification."""
from __future__ import annotations

import argparse
import csv
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GENERATED = Path('Packages/TrinketContent/Sources/TrinketContent/Generated')
RECORD = GENERATED / 'PreparedAssets.generated.json'
KINDS = {
    'art': ('ArtManifest/curated-assets.tsv', 'ArtCatalog.generated.swift', 'ArtSourceHashes.generated.tsv', 'Trinket/Assets.xcassets', 'Scripts/prepare-art-assets.sh'),
    'music': ('MusicManifest/music.tsv', 'MusicCatalog.generated.swift', 'MusicSourceHashes.generated.tsv', 'Trinket/Media/Music', 'Scripts/prepare-audio-assets.sh'),
    'sfx': ('SoundManifest/sfx.tsv', 'SFXCatalog.generated.swift', 'SFXSourceHashes.generated.tsv', 'Trinket/Media/SFX', 'Scripts/prepare-audio-assets.sh'),
    'cinematic': ('CinematicManifest/cinematics.tsv', 'UltimateCinematicCatalog.generated.swift', 'UltimateCinematicSourceHashes.generated.tsv', 'Trinket/Media/Cinematics', 'Scripts/prepare-cinematic-assets.sh'),
    'app-icon': ('ArtManifest/app-icon.tsv', None, 'AppIconSourceHashes.generated.tsv', 'Trinket/AppIcon.icon', 'Scripts/prepare-app-icon.sh'),
}


def library_root() -> Path:
    return Path(os.environ.get('ASSET_LIBRARY_ROOT') or Path.home() / 'Documents/Asset Library').resolve()


def source_path(source: str) -> Path:
    root = library_root()
    path = (root / source).resolve()
    if not source or Path(source).is_absolute() or path == root or not path.is_relative_to(root):
        raise ValueError(f'Asset source must be library-relative: {source}')
    return path


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def rows(kind: str) -> list[dict[str, str]]:
    lines = (ROOT / KINDS[kind][0]).read_text().splitlines()
    headers = {
        'art': 'kind id asset_name source_path focal_x focal_y',
        'music': 'kind id asset_name source_path boss_enemy_id looping volume_gain',
        'sfx': 'id swift_symbol asset_name source_path volume_gain',
        'cinematic': 'actor_id ability_id asset_name source_path has_audio',
        'app-icon': 'asset_name source_path',
    }
    header = headers[kind].split()
    return [dict(zip(header, line.split('\t'))) for line in lines if line and not line.startswith('#')]



def selected_sources(kind: str) -> list[str]:
    return sorted({row['source_path'] for row in rows(kind)})


def source_hashes(kind: str) -> dict[str, str]:
    result = {}
    for source in selected_sources(kind):
        path = source_path(source)
        try:
            if kind == 'app-icon':
                if not path.is_dir() or not (path / 'icon.json').is_file():
                    raise ValueError('Missing Icon Composer package')
                files = [file for file in sorted(path.rglob('*')) if not file.is_dir() and file.name != '.DS_Store']
            else:
                files = [path]
            for file in files:
                if not file.is_file() or file.stat().st_size == 0:
                    raise ValueError('Missing or empty source')
                result[file.relative_to(library_root()).as_posix()] = digest(file)
        except (OSError, ValueError) as error:
            raise ValueError(f'Cannot read Asset Library source "{source}". Download it in Finder if iCloud has offloaded it, or set ASSET_LIBRARY_ROOT. Existing outputs were preserved.') from error
    return result


def input_hash(kind: str) -> str:
    manifest, _, _, _, script = KINDS[kind]
    paths = [manifest, script, 'Scripts/lib/media-assets.sh', 'Scripts/asset-library.py']
    if kind == 'art':
        paths.append('Scripts/config/full-only-art-kinds.txt')
    if kind == 'art':
        override = os.environ.get('ART_MAX_DIMENSION', '')
        defaults = {'COMBATANT': '1320', 'ABILITY': '960', 'ITEM': '960', 'SLOT_BACKGROUND': '720', 'BACKGROUND': '1600', 'PORTRAIT_BACKGROUND': '2752', 'ENCOUNTER': '1320', 'RESOURCE': '256', 'TALENT': '960'}
        settings = {f'ART_{name}_DIMENSION': os.environ.get(f'ART_{name}_DIMENSION') or override or value for name, value in defaults.items()}
        for name, value in {'ART_HEIC_QUALITY': '80', 'ART_THUMB_DIMENSION': '480', 'ART_PORTRAIT_THUMB_DIMENSION': '960'}.items():
            settings[name] = os.environ.get(name) or value
    else:
        defaults = {'music': {'MUSIC_AAC_BITRATE': '96000'}, 'sfx': {'SFX_AAC_BITRATE': '64000'}, 'cinematic': {'CINEMATIC_HEVC_PRESET': 'PresetHEVCHighestQuality'}, 'app-icon': {}}[kind]
        settings = {name: os.environ.get(name) or value for name, value in defaults.items()}
    values = {path: digest(ROOT / path) for path in paths if (ROOT / path).is_file()}
    values['settings'] = settings
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


def shipping_output_hashes(kind: str) -> dict[str, str]:
    directory = KINDS[kind][3]
    folder = ROOT / directory
    if not folder.is_dir():
        raise ValueError(f'Missing prepared outputs: {directory}')
    paths = [p for p in folder.rglob('*') if p.is_file() and p.name != '.DS_Store']
    # Accent colors are authored independently of the art pipeline.
    if kind == 'art':
        paths = [p for p in paths if '.imageset' in str(p) or p == folder / 'Contents.json']
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths)}


def output_hashes(kind: str) -> dict[str, str]:
    _, catalog, state, _, _ = KINDS[kind]
    outputs = shipping_output_hashes(kind)
    paths = [ROOT / GENERATED / state]
    if catalog:
        paths.append(ROOT / GENERATED / catalog)
    outputs.update({p.relative_to(ROOT).as_posix(): digest(p) for p in paths})
    return outputs


def read_record() -> dict:
    if not (ROOT / RECORD).is_file():
        return {}
    return json.loads((ROOT / RECORD).read_text())


def relink_sources(kinds: list[str], apply: bool) -> list[str]:
    """Recover moved masters by receipt identity, never by a similar filename."""
    recorded = read_record()
    missing = [(kind, source) for kind in kinds for source in selected_sources(kind)
               if not source_path(source).exists()]
    if not missing:
        return []
    root = library_root()
    if not root.is_dir():
        raise ValueError(f'Asset Library is unavailable: {root}. Set ASSET_LIBRARY_ROOT.')
    wanted = {recorded.get(kind, {}).get('sources', {}).get(source)
              for kind, source in missing if kind != 'app-icon'} - {None}
    matches = {value: [] for value in wanted}
    packages = []
    # Search only when a selected path is missing. Library duplicates deliberately
    # remain ambiguous, even when one happens to share the old filename.
    def scan_error(error):
        raise error

    for directory, folders, files in os.walk(root, followlinks=False, onerror=scan_error):
        folders[:] = sorted(name for name in folders if not (Path(directory) / name).is_symlink())
        folder = Path(directory)
        if folder.suffix == '.icon' and 'icon.json' in files:
            packages.append(folder)
        for name in sorted(files) if wanted else []:
            file = folder / name
            relative = file.relative_to(root).as_posix()
            if file.is_symlink() or name == '.DS_Store' or any(char in relative for char in '\t\r\n'):
                continue
            value = digest(file)
            if value in matches:
                matches[value].append(file.relative_to(root).as_posix())
    changes = {}
    errors = []
    for kind, source in missing:
        hashes = recorded.get(kind, {}).get('sources', {})
        if kind == 'app-icon':
            expected = {name[len(source) + 1:]: value for name, value in hashes.items()
                        if name.startswith(source + '/')}
            candidates = []
            for package in packages if expected else []:
                if (any(char in package.relative_to(root).as_posix() for char in '\t\r\n')
                        or any(file.is_symlink() for file in package.rglob('*'))):
                    continue
                actual = {file.relative_to(package).as_posix(): digest(file)
                          for file in package.rglob('*') if file.is_file() and file.name != '.DS_Store'}
                if actual == expected:
                    candidates.append(package.relative_to(root).as_posix())
        else:
            candidates = matches.get(hashes.get(source), [])
        if len(candidates) != 1:
            if not hashes or (kind != 'app-icon' and source not in hashes):
                reason = 'no recorded source hash'
            elif not candidates:
                reason = 'no exact match'
            else:
                reason = 'ambiguous exact matches: ' + ', '.join(candidates)
            errors.append(f'{source}: {reason}')
        else:
            changes.setdefault(kind, {})[source] = candidates[0]
    if errors:
        raise ValueError('Cannot relink Asset Library sources; manifests were preserved. Existing outputs were preserved:\n' + '\n'.join(errors))
    updates = []
    for kind, replacements in changes.items():
        manifest = ROOT / KINDS[kind][0]
        before = manifest.read_text()
        column = list(rows(kind)[0]).index('source_path')
        lines = []
        for line in before.splitlines(keepends=True):
            if line.strip() and not line.startswith('#'):
                content = line.rstrip('\r\n')
                ending = line[len(content):]
                fields = content.split('\t')
                fields[column] = replacements.get(fields[column], fields[column])
                line = '\t'.join(fields) + ending
            lines.append(line)
        updates.append((manifest, before, ''.join(lines)))
        for old, new in replacements.items():
            print(f'{kind}: {old} -> {new}', file=sys.stderr)
    if apply:
        for manifest, before, after in updates:
            if manifest.read_text() != before:
                raise ValueError(f'Manifest changed during relinking: {manifest}. Rerun preparation.')
        for manifest, _, after in updates:
            with tempfile.NamedTemporaryFile(mode='w', dir=manifest.parent, delete=False) as staging:
                temporary = Path(staging.name)
                staging.write(after)
            try:
                temporary.chmod(manifest.stat().st_mode & 0o777)
                temporary.replace(manifest)
            finally:
                temporary.unlink(missing_ok=True)
    return list(changes)


def pending_relocations(kinds: list[str]) -> list[str]:
    """Retry preparation if an earlier relink succeeded but encoding failed."""
    recorded = read_record()
    pending = []
    for kind in kinds:
        previous = recorded.get(kind, {}).get('sources', {})
        selections = selected_sources(kind)
        if not previous:
            continue
        if all(any(name.startswith(source + '/') for name in previous) if kind == 'app-icon'
               else source in previous for source in selections):
            continue
        current = source_hashes(kind)
        if kind == 'app-icon':
            def package_members(hashes):
                return {name.split('.icon/', 1)[-1]: value for name, value in hashes.items()}
            identical = package_members(current) == package_members(previous)
        else:
            identical = sorted(current.values()) == sorted(previous.values())
        if identical:
            pending.append(kind)
    return pending


def input_snapshot(kind: str) -> dict:
    return {'input_hash': input_hash(kind), 'sources': source_hashes(kind)}


def record_kind(kind: str, expected_inputs: dict) -> None:
    target = ROOT / RECORD
    target.parent.mkdir(parents=True, exist_ok=True)
    lock = ROOT / '.DerivedData/AssetPreparation/receipt.lock'
    lock.parent.mkdir(parents=True, exist_ok=True)
    # Keep the lock inode stable across writers; replacing the receipt is atomic.
    with lock.open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        outputs = output_hashes(kind)
        if input_snapshot(kind) != expected_inputs:
            raise ValueError(f'Prepared {kind} inputs changed during preparation. Rerun the pipeline; no new receipt was recorded.')
        record = read_record()
        record[kind] = {**expected_inputs, 'outputs': outputs}
        content = json.dumps(record, indent=2, sort_keys=True) + '\n'
        if target.exists() and target.read_text() == content:
            return
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', dir=target.parent, prefix='.PreparedAssets.', suffix='.tmp', delete=False) as staging:
                temporary = Path(staging.name)
                staging.write(content)
            temporary.replace(target)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


def validate_art_ids() -> None:
    import re
    owners = {
        'combatant': [GENERATED / 'GameContentRoster.generated.swift', GENERATED / 'GameContentEnemies.generated.swift'],
        'ability': [Path(f'Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog+{tier}.swift') for tier in ('Basic', 'Skill', 'Ultimate')],
        'item': [GENERATED / 'GameContentItemBases.generated.swift'],
    }
    ids = {kind: {match for file in files for match in re.findall(r'id: "([^"\n]+)"', (ROOT / file).read_text())} for kind, files in owners.items()}
    for row in rows('art'):
        kind = row['kind']
        identifier = re.sub(r'-(?:basic|astral)$', '', row['id']) if kind == 'item' else row['id']
        if kind in ids and identifier not in ids[kind]:
            raise ValueError(f'Art selection {kind} "{identifier}" has no backing game content.')


def validate_media_ids(kind: str) -> None:
    if kind == 'music':
        bosses = [row for row in rows(kind) if row['kind'] == 'boss']
        if bosses:
            enemies = (ROOT / GENERATED / 'GameContentEnemies.generated.swift').read_text().splitlines()
            for row in bosses:
                if not any(f'id: "{row["boss_enemy_id"]}"' in line and 'isBoss: true' in line for line in enemies):
                    raise ValueError(f'Music boss "{row["boss_enemy_id"]}" is no longer a boss enemy.')
    elif kind == 'cinematic':
        selections = rows(kind)
        if not selections:
            return
        with (ROOT / 'ContentManifest/combatants.tsv').open() as stream:
            actors = {row['id']: row for row in csv.DictReader(stream, delimiter='\t')}
        with (ROOT / GENERATED / 'AbilityInventory.generated.tsv').open() as stream:
            ultimates = {row['id'] for row in csv.DictReader(stream, delimiter='\t') if row['tier'] == 'ultimate'}
        for row in selections:
            actor = actors.get(row['actor_id'])
            ability = row['ability_id']
            parts = ability.split('-')
            symbol = parts[0] + ''.join(part[:1].upper() + part[1:] for part in parts[1:])
            if (not actor or actor['role'] not in ('hero', 'companion') or ability not in ultimates
                    or symbol not in actor['ultimates'].split(',')):
                raise ValueError(f'Cinematic "{row["actor_id"]}/{ability}" no longer matches an actor Ultimate.')


def check_kind(kind: str, outputs_only: bool) -> None:
    recorded = read_record().get(kind)
    if not recorded or recorded['input_hash'] != input_hash(kind):
        raise ValueError(f'Prepared {kind} selection/settings changed. Run Scripts/prepare-assets.sh --kind {kind} locally.')
    if recorded['outputs'] != output_hashes(kind):
        raise ValueError(f'Prepared {kind} outputs/catalogs changed. Regenerate locally.')
    if kind == 'art':
        validate_art_ids()
    else:
        validate_media_ids(kind)
    if not outputs_only and recorded['sources'] != source_hashes(kind):
        raise ValueError(f'Raw {kind} sources changed. Regenerate locally.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--resolve')
    group.add_argument('--preflight', action='store_true')
    group.add_argument('--record', action='store_true')
    group.add_argument('--check', action='store_true')
    group.add_argument('--repair-needed', action='store_true')
    group.add_argument('--relink', action='store_true', help='preview exact-content source relocations')
    parser.add_argument('--apply', action='store_true', help='write manifest paths with --relink')
    parser.add_argument('--outputs-only', action='store_true')
    parser.add_argument('--snapshot', action='store_true', help='emit the single-kind preflight input snapshot')
    parser.add_argument('--expected-inputs', help='preflight snapshot required when recording a kind')
    parser.add_argument('--kind', choices=[*KINDS, 'all', 'audio'], default='all')
    args = parser.parse_args()
    if args.apply and not args.relink:
        parser.error('--apply requires --relink')
    if args.outputs_only and not args.check:
        parser.error('--outputs-only requires --check')
    if args.snapshot and (not args.preflight or args.kind in ('all', 'audio')):
        parser.error('--snapshot requires --preflight and a single kind')
    if args.record and (not args.expected_inputs or args.kind in ('all', 'audio')):
        parser.error('--record requires --expected-inputs and a single kind')
    if args.resolve:
        print(source_path(args.resolve))
        return
    kinds = list(KINDS) if args.kind == 'all' else ['music', 'sfx'] if args.kind == 'audio' else [args.kind]
    if args.relink or args.preflight:
        relinked = relink_sources(kinds, apply=args.preflight or args.apply)
    if args.relink:
        if args.apply:
            print('\n'.join(dict.fromkeys([*relinked, *pending_relocations(kinds)])))
        return
    for kind in kinds:
        if args.repair_needed:
            recorded = read_record().get(kind, {}).get('outputs', {})
            shipping = {path: value for path, value in recorded.items() if path.startswith('Trinket/')}
            if not shipping or not (ROOT / KINDS[kind][3]).is_dir() or shipping != shipping_output_hashes(kind):
                print('yes')
                return
            continue
        if args.preflight:
            if args.snapshot:
                print(json.dumps(input_snapshot(kind), sort_keys=True))
            else:
                source_hashes(kind)
        elif args.record:
            record_kind(kind, json.loads(args.expected_inputs))
        else:
            check_kind(kind, args.outputs_only)
    if args.check:
        print('Prepared outputs are consistent.' if args.outputs_only else 'Prepared outputs match local sources.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

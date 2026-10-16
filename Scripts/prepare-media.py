#!/usr/bin/env python3
"""Incremental media encoders; asset-library owns source identity and receipts."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location('asset_library', Path(__file__).with_name('asset-library.py'))
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)
ROOT = assets.ROOT
TEMPLATES = ROOT / 'Scripts/internal/media_templates'

# kind: reference type, key type, crop metadata; asset-library owns encode settings
ART = {
    'combatant': ('Combatant', 'String', 'focal'),
    'ability': ('Ability', 'String', 'none'),
    'item': ('Item', 'String', 'none'),
    'slot_background': ('SlotBackground', 'ItemSlot', 'none'),
    'background': ('Background', 'String', 'aspect'),
    'portrait_background': ('Background', 'String', 'aspect'),
    'encounter': ('Encounter', 'String', 'none'),
    'resource': ('Resource', 'String', 'none'),
    'talent': ('Talent', 'Keyword', 'aspect'),
}
KEYWORDS = set('physical burn stun block health gold holy poison bleed leech freeze dodge purge cleanse mana deathsDoor'.split())
SWIFT_RESERVED = set('''Any Protocol Self Type actor any as associatedtype async await
borrowing break case catch class consuming continue default defer deinit do each else
enum extension fallthrough false fileprivate for func guard if import in init inout
internal is isolated let macro nil nonisolated open operator package precedencegroup
private protocol public repeat rethrows return self some static struct subscript super
switch throw throws true try typealias var where while'''.split())


def setting(name: str, default) -> str:
    return os.environ.get(name) or str(default)


def swift(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def template(name: str, **values: str) -> str:
    text = (TEMPLATES / f'{name}.swift-template').read_text()
    return re.sub(r'@(\w+)@', lambda match: values[match[1]], text)


def write_changed(path: Path, content: str) -> None:
    if path.is_file() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.media-', dir=path.parent) as directory:
        staged = Path(directory) / path.name
        staged.write_text(content)
        staged.replace(path)


def command(*args, check=True) -> str:
    return subprocess.run(args, check=check, stdout=subprocess.PIPE, text=True).stdout


def validate(kind: str) -> list[dict[str, str]]:
    rows = assets.rows(kind)
    if kind == 'app-icon' and len(rows) != 1:
        raise ValueError('App icon manifest must select exactly one Icon Composer package.')
    seen = {}

    def unique(label, value):
        values = seen.setdefault(label, set())
        if value in values:
            raise ValueError(f"Duplicate {label} '{value}'.")
        values.add(value)

    for row in rows:
        identifier = row.get('id', row['asset_name'])
        if any(not value for key, value in row.items() if key != 'boss_enemy_id'):
            raise ValueError(f"Manifest row is missing required fields for id '{identifier}'.")
        for field in ('id', 'asset_name', 'swift_symbol'):
            if field not in row:
                continue
            value = row[field]
            label = {'id': f'{kind} id', 'asset_name': f'{kind} asset name', 'swift_symbol': 'SFX Swift symbol'}[field]
            pattern = r'[A-Za-z_][A-Za-z0-9_]*' if field == 'swift_symbol' else r'[A-Za-z0-9_][A-Za-z0-9_-]*'
            if kind == 'art' and field == 'asset_name':
                pattern = r'[A-Za-z0-9_]+'
            if kind != 'app-icon' and not re.fullmatch(pattern, value):
                raise ValueError(f"{label} '{value}' is not a valid identifier.")
            if field == 'swift_symbol' and value in SWIFT_RESERVED:
                raise ValueError(f"{label} '{value}' is a reserved Swift keyword.")
            unique(label, (row['kind'], value) if kind == 'art' and field == 'id' else value)
        if kind == 'art':
            art_kind = row['kind']
            if art_kind not in ART:
                raise ValueError(f"Unsupported art kind '{art_kind}' for id '{identifier}'.")
            if any(not re.fullmatch(r'[0-9]+(?:[.][0-9]+)?', row[field]) or not 0 <= float(row[field]) <= 1
                   for field in ('focal_x', 'focal_y')):
                raise ValueError(f"Focal values for '{identifier}' must be numeric values between 0 and 1.")
            if art_kind == 'talent' and identifier not in KEYWORDS:
                raise ValueError(f"Talent art id '{identifier}' is not a valid Keyword case.")
            if art_kind == 'slot_background' and identifier not in {'weapon', 'armor', 'accessory', 'trinket'}:
                raise ValueError(f"Slot background id '{identifier}' must be one of: weapon, armor, accessory, trinket.")
        if kind in ('music', 'sfx') and not re.fullmatch(r'(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)', row['volume_gain']):
            raise ValueError(f"Volume gain for '{identifier}' must be numeric.")
        if kind == 'music':
            if row['kind'] not in {'menu', 'battle', 'boss'}:
                raise ValueError(f"Unsupported music kind '{row['kind']}' for id '{identifier}'.")
            if row['looping'] not in {'true', 'false'}:
                raise ValueError(f"Looping value for '{identifier}' must be true or false.")
            boss = row['boss_enemy_id']
            if (row['kind'] == 'boss') != (boss not in {'', 'none'}):
                raise ValueError(f"Only boss music must include boss_enemy_id; '{identifier}' has '{boss}'.")
            if row['kind'] == 'boss':
                unique('boss music enemy id', boss)
    if kind == 'art':
        assets.validate_art_ids()
    assets.validate_media_ids(kind)
    return rows


class Preparation:
    """One preflight snapshot and cache per kind; receipt follows successful outputs."""
    def __init__(self, kind, snapshot):
        self.kind = kind
        self.snapshot = snapshot
        self.settings = assets.encoding_settings(kind)
        _, catalog, state, directory, self.generator = assets.KINDS[kind]
        self.catalog = ROOT / assets.GENERATED / catalog if catalog else None
        self.state = ROOT / assets.GENERATED / state
        self.directory = ROOT / directory
        self.directory.mkdir(parents=True, exist_ok=True)
        self.previous = {}
        if self.state.is_file():
            for line in self.state.read_text().splitlines():
                fields = line.split('\t')
                if not line.startswith('#') and len(fields) >= 2:
                    self.previous.setdefault(fields[0], tuple(fields[1:]))
        self.records = {}
        recorded = assets.read_record().get(kind, {}).get('outputs', {})
        shipping = {path: value for path, value in recorded.items() if path.startswith('Trinket/')}
        self.force = setting('FORCE_ASSET_REENCODE', '0') == '1' or not shipping or shipping != assets.shipping_output_hashes(kind)

    def stale(self, name, digest, profile, outputs):
        self.records[name] = (digest, profile)
        return self.force or self.previous.get(name) != (digest, profile) or any(not p.is_file() or p.stat().st_size == 0 for p in outputs)

    def finish(self, catalog=None, *, active=(), patterns=(), label='asset'):
        if catalog is not None:
            write_changed(self.catalog, catalog)
        for pattern in patterns:
            self.prune(active, pattern, label)
        header = f'# Generated by {self.generator}. Do not edit directly.\n# asset_name\tsource_sha256\tencode_profile\n'
        write_changed(self.state, header + ''.join(f'{name}\t{digest}\t{profile}\n' for name, (digest, profile) in sorted(self.records.items())))
        assets.record_kind(self.kind, self.snapshot)

    def prune(self, active, pattern, label):
        for path in self.directory.glob(pattern):
            if path.name not in active:
                print(f'Pruning orphaned {label}: {path.name}')
                shutil.rmtree(path) if path.is_dir() else path.unlink()


def imageset(path, source, dimension, quality):
    # Stage beside the destination so conversion failure never removes a working image.
    with tempfile.TemporaryDirectory(prefix='.media-', dir=path.parent) as directory:
        staged = Path(directory) / path.name
        staged.mkdir()
        image = staged / f'{path.stem}.heic'
        command('sips', '-s', 'format', 'heic', '-s', 'formatOptions', quality, '-Z', dimension, str(source), '--out', str(image))
        if not image.is_file() or image.stat().st_size == 0:
            raise ValueError(f'Failed to produce a valid art asset: {source}')
        subprocess.run(['sips', '-d', 'all', str(image)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Keep actool metadata byte-stable with existing prepared imagesets.
        (staged / 'Contents.json').write_text('{\n  "images" : [\n    {\n      "filename" : "' + image.name + '",\n      "idiom" : "universal"\n    }\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
        install_directory(staged, path)


def install_directory(staged: Path, destination: Path) -> None:
    backup = staged.parent / 'previous'
    if destination.exists():
        destination.replace(backup)
    try:
        staged.replace(destination)
    except OSError:
        if backup.exists():
            backup.replace(destination)
        raise


def prepare_art(rows, snapshot):
    run = Preparation('art', snapshot)
    quality = run.settings['ART_HEIC_QUALITY']
    config = ROOT / setting('TRINKET_FULL_ONLY_ART_KINDS_CONFIG', 'Scripts/config/full-only-art-kinds.txt')
    full_only = {line.strip() for line in config.read_text().splitlines() if line.strip() and not line.startswith('#')} if config.is_file() else {'resource', 'slot_background'}
    entries = {kind: [] for kind in ART}
    active = set()
    for row in rows:
        kind, name = row['kind'], row['asset_name']
        reference, key_type, crop = ART[kind]
        dimension = run.settings[f'ART_{kind.upper()}_DIMENSION']
        thumb = run.settings['ART_PORTRAIT_THUMB_DIMENSION' if kind == 'portrait_background' else 'ART_THUMB_DIMENSION']
        want_thumb = str(kind not in full_only).lower()
        profile = f'q{quality}/full{dimension}/thumb{thumb}/thumb:{want_thumb}'
        source = assets.source_path(row['source_path'])
        source_hash = hashlib.sha256(f'{assets.digest(source)}\t{quality}\t{dimension}\t{thumb}\t{want_thumb}\n'.encode()).hexdigest()
        variants = [(name, dimension)] + ([(name + '_thumb', thumb)] if kind not in full_only else [])
        outputs = [run.directory / f'{variant}.imageset/{variant}.heic' for variant, _ in variants]
        if run.stale(name, source_hash, profile, outputs):
            for variant, size in variants:
                imageset(run.directory / f'{variant}.imageset', source, size, quality)
        active.update(f'{variant}.imageset' for variant, _ in variants)
        fields = [f'imageName: {swift(name)}']
        if crop == 'aspect':
            dimensions = dict(re.findall(r'(pixelWidth|pixelHeight):\s*(\d+)', command('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(outputs[0]))))
            fields.append(f"sourceAspectRatio: {int(dimensions['pixelWidth']) / int(dimensions['pixelHeight']):.12f}")
        if crop != 'none':
            fields.append(f"focalPoint: ArtFocalPoint(x: {row['focal_x']}, y: {row['focal_y']})")
        key = swift(row['id']) if key_type == 'String' else '.' + row['id']
        entries[kind].append(f'        {key}: {reference}ArtReference(\n            ' + ',\n            '.join(fields) + '\n        ),\n')
    text = template('art-header')
    references = set()
    names = []
    dictionaries = '\npublic enum ArtCatalog {\n'
    for kind, (reference, key_type, crop) in ART.items():
        if reference not in references:
            text += f'\npublic struct {reference}ArtReference: Hashable, Sendable {{\n    public let imageName: String\n'
            text += '    public let sourceAspectRatio: Double\n' if crop == 'aspect' else ''
            text += '    public let focalPoint: ArtFocalPoint\n' if crop != 'none' else ''
            if kind not in {'resource', 'slot_background'}:
                text += '\n    public var thumbnailImageName: String? {\n        "\\(imageName)_thumb"\n    }\n'
            text += '}\n'
            references.add(reference)
        prop = ''.join(word.title() if index else word for index, word in enumerate(kind.split('_'))) + 'ArtByID'
        dictionaries += f'    public static let {prop}: [{key_type}: {reference}ArtReference] = '
        dictionaries += '[\n' + ''.join(entries[kind]) + '    ]\n\n' if entries[kind] else '[:]\n\n'
        names.append(f'        names.formUnion({prop}.values.map(\\.imageName))\n')
        if kind not in {'resource', 'slot_background'}:
            names.append(f'        names.formUnion({prop}.values.compactMap(\\.thumbnailImageName))\n')
    text += dictionaries + '}\n\n' + template('art-extensions') + '\n'
    text += 'public extension ArtCatalog {\n    static let allImageNames: [String] = {\n        var names = Set<String>()\n' + ''.join(names)
    text += '        return names.sorted()\n    }()\n\n    static let allImageNamesSet: Set<String> = Set(allImageNames)\n}\n'
    write_changed(run.directory / 'Contents.json', '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
    run.finish(text, active=active, patterns=('*.imageset', '*/*.imageset'))


def prepare_audio(kind, rows, snapshot, lyrics=None):
    run = Preparation(kind, snapshot)
    bitrate = run.settings[f'{kind.upper()}_AAC_BITRATE']
    profile = f'container=m4af;codec=aac;bitrate={bitrate};soundcheck=true'
    snippets = {name: [] for name in ('tracks', 'menu', 'battle', 'boss', 'clips', 'ids')}
    active = set()
    for row in rows:
        name, identifier = row['asset_name'], swift(row['id'])
        output = run.directory / f'{name}.m4a'
        source = assets.source_path(row['source_path'])
        if run.stale(name, assets.digest(source), profile, [output]):
            with tempfile.TemporaryDirectory(prefix='.media-', dir=run.directory) as directory:
                staged = Path(directory) / output.name
                command('afconvert', str(source), str(staged), '-f', 'm4af', '-d', 'aac', '-b', bitrate, '--soundcheck-generate')
                if not staged.is_file() or staged.stat().st_size == 0:
                    raise ValueError(f'Failed to produce a valid {kind} asset.')
                staged.replace(output)
        active.add(output.name)
        fields = [f'id: {identifier}']
        if kind == 'music':
            fields.append(f"kind: .{row['kind']}")
        fields += [f'resourceName: {swift(name)}', 'fileExtension: "m4a"']
        if kind == 'music':
            boss = swift('' if row['boss_enemy_id'] == 'none' else row['boss_enemy_id'])
            fields += [f'bossEnemyID: {boss}', f"isLooping: {row['looping']}"]
            snippets[row['kind']].append(f'        {boss}: {identifier},' if row['kind'] == 'boss' else f'        {identifier},')
        else:
            snippets['ids'].append(f"    public static let {row['swift_symbol']} = {identifier}")
        fields.append(f"volumeGain: {row['volume_gain']}")
        snippets['tracks' if kind == 'music' else 'clips'].append('        ' + ('MusicTrack' if kind == 'music' else 'SFXClip') + '(\n            ' + ',\n            '.join(fields) + '\n        ),')
    if kind == 'music':
        entries = []
        for identifier, lines in (lyrics or {}).items():
            phrases = [f'            MusicLyricPhrase(text: {swift(line["text"])}, timings: {line["timings"]}),' for line in lines]
            entries.append(f'        {swift(identifier)}: [\n' + '\n'.join(phrases) + '\n        ],')
        snippets['lyrics'] = ['[\n' + '\n'.join(entries) + '\n    ]' if entries else '[:]']
    run.finish(template(kind, **{key: '\n'.join(value) for key, value in snippets.items()}),
               active=active, patterns=('*.m4a',), label=f'{kind} asset')


def prepare_icon(rows, snapshot):
    run = Preparation('app-icon', snapshot)
    source = assets.source_path(rows[0]['source_path'])
    # Retain the existing directory digest, including relative member names.
    def tree_hash(path):
        members = ''.join(f'{assets.digest(file)}  ./{file.relative_to(path).as_posix()}\n' for file in sorted(path.rglob('*')) if file.is_file() and file.name != '.DS_Store')
        return hashlib.sha256(members.encode()).hexdigest()
    digest = tree_hash(source)
    if run.stale('AppIcon.icon', digest, 'copy', [run.directory / 'icon.json']) or tree_hash(run.directory) != digest:
        with tempfile.TemporaryDirectory(prefix='.media-', dir=run.directory.parent) as directory:
            staged = Path(directory) / 'AppIcon.icon'
            shutil.copytree(source, staged, ignore=shutil.ignore_patterns('.DS_Store'))
            install_directory(staged, run.directory)
        print(f'  Installed {run.directory.relative_to(ROOT)}')
    legacy = ROOT / 'Trinket/Assets.xcassets/AppIcon.appiconset'
    if legacy.is_dir():
        shutil.rmtree(legacy)
    run.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=[*assets.KINDS, 'audio'])
    args = parser.parse_args()
    kinds = ['music', 'sfx'] if args.kind == 'audio' else [args.kind]
    os.chdir(ROOT)
    assets.relink_sources(kinds, apply=True)
    # Validate every selected source and row before encoding or pruning any kind.
    snapshots = {kind: assets.input_snapshot(kind) for kind in kinds}
    rows = {kind: validate(kind) for kind in kinds}
    lyrics = assets.music_lyrics(snapshots['music']['sources']) if 'music' in kinds else None
    for kind in kinds:
        if kind == 'art':
            prepare_art(rows[kind], snapshots[kind])
        elif kind == 'app-icon':
            prepare_icon(rows[kind], snapshots[kind])
        else:
            prepare_audio(kind, rows[kind], snapshots[kind], lyrics)
        print(f'Prepared {len(rows[kind])} {kind} asset(s).')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

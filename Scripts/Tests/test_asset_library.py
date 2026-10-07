#!/usr/bin/env python3
"""Protect private-source isolation and committed-output integrity."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

from script_test_support import ScriptRegressionTestCase

SCRIPT_INPUTS = ('Scripts/asset-library.py', 'Scripts/lib/media-assets.sh',
                 'Scripts/prepare-audio-assets.sh', 'Scripts/prepare-cinematic-assets.sh')


class AssetLibraryTests(ScriptRegressionTestCase):
    def test_automatic_healing_retries_interrupted_preparation_and_stays_source_free_on_ci(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, log = self.make_audio_fixture(directory, 'sfx')
            self.make_repo_fixture(directory, ('Scripts/prepare-assets.sh', 'Scripts/lib/args.sh',
                                               'Scripts/build-freshness.sh', 'Scripts/build-inputs.env'))
            prepare = root / 'Scripts/prepare-assets.sh'
            prepare.rename(root / 'Scripts/prepare-selected-assets.sh')
            prepare.write_text('#!/bin/bash\nexec bash Scripts/prepare-selected-assets.sh "$@" --kind sfx\n')
            prepare.chmod(0o755)
            generator = root / 'Scripts/generate.sh'
            generator.write_text('#!/bin/bash\nexit 0\n')
            generator.chmod(0o755)
            library = root / 'library'
            library.mkdir()
            (root / 'Raw Assets').rename(library / 'Raw Assets')
            env['ASSET_LIBRARY_ROOT'] = str(library)
            self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
            source = library / 'Raw Assets/Sound Effects/clip.wav'
            moved = library / 'Renamed.wav'
            source.rename(moved)
            manifest = root / 'SoundManifest/sfx.tsv'
            before = manifest.read_bytes()
            command = ['bash', '-ec', 'unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE; '
                       'source Scripts/build-freshness.sh; prepare_generated_inputs results']
            hosted = subprocess.run(command, cwd=root, env={**env, 'CI': 'true'}, capture_output=True, text=True)
            self.assertEqual(hosted.returncode, 0, hosted.stderr)
            self.assertEqual(manifest.read_bytes(), before)
            pipeline = root / 'Scripts/prepare-audio-assets.sh'
            original = pipeline.read_bytes()
            pipeline.write_text('#!/bin/bash\nexit 9\n')
            interrupted = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(interrupted.returncode, 9, interrupted.stderr)
            self.assertIn('Renamed.wav', manifest.read_text())
            pipeline.write_bytes(original)
            healed = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(healed.returncode, 0, healed.stderr)
            checked = self.run_check(root, env, '--check')
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual((root / 'Trinket/Media/SFX/sfx_test_clip.m4a').read_bytes(), b'fixture audio')
            self.assertEqual(log.read_text().count('convert'), 1)

    def make_relink_fixture(self, directory, kind):
        root = self.make_repo_fixture(directory, ('Scripts/asset-library.py',))
        library = root / 'library'
        library.mkdir()
        manifest = root / 'ArtManifest' / ('app-icon.tsv' if kind == 'app-icon' else 'curated-assets.tsv')
        manifest.parent.mkdir()
        source = 'Old/Icon.icon' if kind == 'app-icon' else 'Old/Knight.jpeg'
        manifest.write_text('# retained comment\n' + ('AppIcon.icon\t' + source + '\n' if kind == 'app-icon' else
                            'combatant\tknight\thero_knight_card\t' + source + '\t0.50\t0.50\n'))
        hashes = {source + '/icon.json': hashlib.sha256(b'icon settings').hexdigest(),
                  source + '/Assets/master.jpeg': hashlib.sha256(b'art master').hexdigest()} if kind == 'app-icon' else {
                      source: hashlib.sha256(b'art master').hexdigest()}
        receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
        receipt.parent.mkdir(parents=True)
        receipt.write_text(json.dumps({kind: {'sources': hashes}}))
        env = {**self.verification_environment(), 'ASSET_LIBRARY_ROOT': str(library)}
        return root, library, manifest, receipt, env

    def test_preflight_relinks_moved_art_and_complete_icon_packages(self):
        for kind in ('art', 'app-icon'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root, library, manifest, receipt, env = self.make_relink_fixture(directory, kind)
                moved = library / ('New/Renamed.icon' if kind == 'app-icon' else 'New/Renamed.jpeg')
                if kind == 'app-icon':
                    (moved / 'Assets').mkdir(parents=True)
                    (moved / 'icon.json').write_bytes(b'icon settings')
                    (moved / 'Assets/master.jpeg').write_bytes(b'art master')
                else:
                    moved.parent.mkdir()
                    moved.write_bytes(b'art master')
                before, recorded = manifest.read_bytes(), receipt.read_bytes()
                command = [sys.executable, 'Scripts/asset-library.py', '--kind', kind]
                preview = subprocess.run(command + ['--relink'], cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(preview.returncode, 0, preview.stderr)
                self.assertEqual(manifest.read_bytes(), before)
                prepared = subprocess.run(command + ['--preflight', '--snapshot'], cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(prepared.returncode, 0, prepared.stderr)
                snapshot = json.loads(prepared.stdout)
                self.assertTrue(all(name.startswith('New/') for name in snapshot['sources']))
                self.assertEqual(manifest.read_bytes(), before.replace(b'Old/Icon.icon' if kind == 'app-icon' else b'Old/Knight.jpeg',
                                                                      b'New/Renamed.icon' if kind == 'app-icon' else b'New/Renamed.jpeg'))
                self.assertEqual(receipt.read_bytes(), recorded)

    def test_relink_refuses_ambiguous_changed_and_unrecorded_art_without_writing(self):
        for failure in ('duplicate', 'changed', 'unrecorded', 'escaped', 'icon-members'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                kind = 'app-icon' if failure == 'icon-members' else 'art'
                root, library, manifest, receipt, env = self.make_relink_fixture(directory, kind)
                (library / 'Moved.jpeg').write_bytes(b'changed master' if failure == 'changed' else b'art master')
                if failure == 'duplicate':
                    (library / 'Copy.jpeg').write_bytes(b'art master')
                    # A repairable second entry must not be written on partial failure.
                    with manifest.open('a') as stream:
                        stream.write('background\tplace\tplace\tOld/Place.jpeg\t0.50\t0.50\n')
                    record = json.loads(receipt.read_text())
                    record['art']['sources']['Old/Place.jpeg'] = hashlib.sha256(b'place').hexdigest()
                    receipt.write_text(json.dumps(record))
                    (library / 'Place.jpeg').write_bytes(b'place')
                elif failure == 'unrecorded':
                    receipt.unlink()
                elif failure == 'escaped':
                    (root / 'Outside.jpeg').write_bytes(b'art master')
                    (library / 'Moved.jpeg').unlink()
                    (library / 'Moved.jpeg').symlink_to(root / 'Outside.jpeg')
                elif failure == 'icon-members':
                    package = library / 'Moved.icon'
                    package.mkdir()
                    (package / 'icon.json').write_bytes(b'icon settings')
                    (package / 'renamed-master.jpeg').write_bytes(b'art master')
                before = manifest.read_bytes()
                result = subprocess.run([sys.executable, 'Scripts/asset-library.py', '--preflight', '--kind', kind],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('manifests were preserved', result.stderr)
                self.assertEqual(manifest.read_bytes(), before)

    def test_existing_art_revision_is_never_replaced_with_an_old_matching_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root, library, manifest, _, env = self.make_relink_fixture(directory, 'art')
            selected = library / 'Old/Knight.jpeg'
            selected.parent.mkdir()
            selected.write_bytes(b'intentionally revised artwork')
            (library / 'old-copy.jpeg').write_bytes(b'art master')
            before = manifest.read_bytes()
            result = subprocess.run([sys.executable, 'Scripts/asset-library.py', '--preflight', '--kind', 'art'],
                                    cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(manifest.read_bytes(), before)
            self.assertEqual(selected.read_bytes(), b'intentionally revised artwork')

    def run_check(self, root, environment, *arguments):
        return subprocess.run(['python3', 'Scripts/asset-library.py', '--kind', 'sfx', *arguments], cwd=root, env=environment, capture_output=True, text=True)

    def test_source_free_integrity_and_local_source_freshness(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, log = self.make_audio_fixture(directory, 'sfx')
            result = self.run_audio_fixture(root, env, 'sfx')
            self.assertEqual(result.returncode, 0, result.stderr)
            unavailable = {**env, 'ASSET_LIBRARY_ROOT': str(root / 'unavailable')}
            checked = self.run_check(root, unavailable, '--check', '--outputs-only')
            self.assertEqual(checked.returncode, 0, checked.stderr)
            source = root / 'Raw Assets/Sound Effects/clip.wav'
            source.write_bytes(b'updated source')
            local = self.run_check(root, env, '--check')
            self.assertNotEqual(local.returncode, 0)
            self.assertIn('sources changed', local.stderr)
            output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
            source.write_bytes(b'fixture audio')
            output.write_bytes(b'corrupt')
            corrupt = self.run_check(root, unavailable, '--check', '--outputs-only')
            self.assertNotEqual(corrupt.returncode, 0)
            self.assertIn('outputs/catalogs changed', corrupt.stderr)
            repaired = self.run_audio_fixture(root, env, 'sfx')
            self.assertEqual(repaired.returncode, 0, repaired.stderr)
            self.assertEqual(output.read_bytes(), b'fixture audio')

    def test_missing_later_source_preserves_all_outputs_and_orphans(self):
        for unavailable in ('missing', 'directory'):
            with self.subTest(unavailable=unavailable), tempfile.TemporaryDirectory() as directory:
                root, env, log = self.make_audio_fixture(directory, 'sfx')
                self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
                output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
                before = output.read_bytes()
                orphan = output.with_name('orphan.m4a')
                orphan.write_bytes(b'keep')
                (root / 'Raw Assets/Sound Effects/clip.wav').write_bytes(b'new source')
                if unavailable == 'directory':
                    (root / 'Missing.wav').mkdir()
                    (root / 'Missing.wav/unrelated.wav').write_bytes(b'not the selected source')
                with (root / 'SoundManifest/sfx.tsv').open('a') as stream:
                    stream.write('missing\tmissing\tsfx_missing\tMissing.wav\t1.0\n')
                result = self.run_audio_fixture(root, env, 'sfx')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Existing outputs were preserved', result.stderr)
                self.assertEqual(output.read_bytes(), before)
                self.assertEqual(orphan.read_bytes(), b'keep')
                self.assertEqual(log.read_text().count('convert'), 1)

    def test_manifest_or_settings_changes_require_local_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, _ = self.make_audio_fixture(directory, 'sfx')
            self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
            overridden = self.run_check(root, {**env, 'SFX_AAC_BITRATE': '96000'}, '--check', '--outputs-only')
            self.assertNotEqual(overridden.returncode, 0)
            self.assertIn('selection/settings changed', overridden.stderr)
            manifest = root / 'SoundManifest/sfx.tsv'
            manifest.write_text(manifest.read_text().replace('\t1.0', '\t0.5'))
            changed = self.run_check(root, env, '--check', '--outputs-only')
            self.assertNotEqual(changed.returncode, 0)
            self.assertIn('selection/settings changed', changed.stderr)

    def test_source_free_checks_reject_removed_media_content_references(self):
        for changed in ('boss', 'actor', 'actor-ultimate', 'ability-tier'):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                kind = 'music' if changed == 'boss' else 'cinematic'
                if kind == 'music':
                    root, env, _ = self.make_audio_fixture(directory, kind)
                    manifest = root / 'MusicManifest/music.tsv'
                    manifest.write_text(manifest.read_text().replace('menu\t', 'boss\t').replace('\tnone\t', '\ttest_boss\t'))
                    content = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift'
                    content.write_text('id: "test_boss", isBoss: true\n')
                    prepared = self.run_audio_fixture(root, env, kind)
                else:
                    root, env, _ = self.make_cinematic_fixture(directory)
                    prepared = self.run_cinematic_fixture(root, env)
                self.assertEqual(prepared.returncode, 0, prepared.stderr)
                unavailable = {**env, 'ASSET_LIBRARY_ROOT': str(root / 'unavailable')}
                command = ['python3', 'Scripts/asset-library.py', '--check', '--outputs-only', '--kind', kind]
                checked = subprocess.run(command, cwd=root, env=unavailable, capture_output=True, text=True)
                self.assertEqual(checked.returncode, 0, checked.stderr)
                if changed == 'boss':
                    content.write_text('id: "test_boss", isBoss: false\n')
                elif changed == 'ability-tier':
                    content = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv'
                    content.write_text(content.read_text().replace('\tultimate\t', '\tskill\t'))
                else:
                    content = root / 'ContentManifest/combatants.tsv'
                    before, after = ('\thero\t', '\tenemy\t') if changed == 'actor' else ('\tavatarOfJustice\n', '\tbash\n')
                    content.write_text(content.read_text().replace(before, after))
                checked = subprocess.run(command, cwd=root, env=unavailable, capture_output=True, text=True)
                self.assertNotEqual(checked.returncode, 0)
                self.assertIn('no longer', checked.stderr)

    def test_missing_receipt_rebuilds_damaged_cached_outputs(self):
        for missing in ('receipt', 'kind', 'output'):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as directory:
                root, env, log = self.make_audio_fixture(directory, 'sfx')
                self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
                receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
                if missing == 'receipt':
                    receipt.unlink()
                else:
                    record = json.loads(receipt.read_text())
                    if missing == 'kind':
                        del record['sfx']
                    else:
                        del record['sfx']['outputs']['Trinket/Media/SFX/sfx_test_clip.m4a']
                    receipt.write_text(json.dumps(record))
                output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
                output.write_bytes(b'corrupt shipping bytes')
                result = self.run_audio_fixture(root, env, 'sfx')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output.read_bytes(), b'fixture audio')
                self.assertEqual(log.read_text().count('convert'), 2)
                checked = self.run_check(root, env, '--check')
                self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_inputs_changed_during_encoding_cannot_receive_a_fresh_receipt(self):
        for changed in ('source', 'manifest'):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                root, env, _ = self.make_audio_fixture(directory, 'sfx')
                self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
                receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
                before = receipt.read_bytes()
                mutation = ('printf changed-after-encoding > "$1"' if changed == 'source' else
                            "printf '# changed during preparation\\n' >> SoundManifest/sfx.tsv")
                (root / 'bin/afconvert').write_text('#!/bin/bash\ncp "$1" "$2"\n' + mutation + '\n')
                result = self.run_audio_fixture(root, {**env, 'FORCE_ASSET_REENCODE': '1'}, 'sfx')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('inputs changed during preparation', result.stderr)
                self.assertEqual(receipt.read_bytes(), before)
                checked = self.run_check(root, env, '--check')
                self.assertNotEqual(checked.returncode, 0)

    def test_parallel_kind_updates_preserve_both_receipts(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, _ = self.make_audio_fixture(directory, 'music')
            self.make_audio_fixture(directory, 'sfx')
            for kind in ('music', 'sfx'):
                result = self.run_audio_fixture(root, env, kind)
                self.assertEqual(result.returncode, 0, result.stderr)
            receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
            receipt.unlink()
            # Delay each read to expose an unlocked read-modify-write race.
            harness = '''
import importlib.util
from pathlib import Path
import sys
import time
spec = importlib.util.spec_from_file_location('assets', 'Scripts/asset-library.py')
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)
kind = sys.argv[1]
expected = assets.input_snapshot(kind)
read = assets.read_record
def delayed_read():
    result = read()
    time.sleep(0.3)
    return result
assets.read_record = delayed_read
Path(kind + '.ready').touch()
deadline = time.monotonic() + 10
while not all(Path(name + '.ready').exists() for name in ('music', 'sfx')):
    if time.monotonic() > deadline:
        raise RuntimeError('Concurrent writer failed to start')
    time.sleep(0.01)
assets.record_kind(kind, expected)
'''
            processes = [subprocess.Popen([sys.executable, '-c', harness, kind], cwd=root, env=env,
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                         for kind in ('music', 'sfx')]
            try:
                for process in processes:
                    _, stderr = process.communicate(timeout=20)
                    self.assertEqual(process.returncode, 0, stderr)
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.kill()
                        process.communicate()
            self.assertEqual(set(json.loads(receipt.read_text())), {'music', 'sfx'})
            for kind in ('music', 'sfx'):
                checked = subprocess.run(['python3', 'Scripts/asset-library.py', '--check', '--kind', kind],
                                         cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(checked.returncode, 0, checked.stderr)

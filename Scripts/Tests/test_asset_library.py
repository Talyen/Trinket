#!/usr/bin/env python3
"""Protect repository-source isolation and committed-output integrity."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

from script_test_support import ScriptRegressionTestCase, run_captured, write_executable, write_json

class AssetLibraryTests(ScriptRegressionTestCase):
    def test_preparation_uses_repo_sources_and_never_falls_back_to_legacy_library(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as external:
            root, env, log = self.make_audio_fixture(directory, 'sfx')
            source = root / 'AssetSources/Raw Assets/Sound Effects/clip.wav'
            foreign = Path(external) / 'Raw Assets/Sound Effects/clip.wav'
            foreign.parent.mkdir(parents=True)
            foreign.write_bytes(b'unrelated external revision')
            env['ASSET_LIBRARY_ROOT'] = external
            self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
            self.assertEqual(self.run_check(root, env, '--check').returncode, 0)
            output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
            self.assertEqual(output.read_bytes(), b'fixture audio')
            before = (root / 'SoundManifest/sfx.tsv').read_bytes()
            source.unlink()
            failed = self.run_audio_fixture(root, env, 'sfx')
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('AssetSources/Raw Assets/Sound Effects/clip.wav', failed.stderr)
            self.assertEqual(output.read_bytes(), b'fixture audio')
            self.assertEqual((root / 'SoundManifest/sfx.tsv').read_bytes(), before)
            self.assertEqual(log.read_text().count('convert'), 1)
            self.assertEqual(foreign.read_bytes(), b'unrelated external revision')

    def test_source_resolution_refuses_absolute_paths_traversal_and_external_symlinks(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as external:
            root = self.make_repo_fixture(directory, ('Scripts/asset-library.py',))
            sources = root / 'AssetSources'
            sources.mkdir()
            (sources / 'escape').symlink_to(external, target_is_directory=True)
            command = [sys.executable, 'Scripts/asset-library.py', '--resolve']
            for source in ('', '.', '../outside.png', str(Path(external) / 'outside.png'), 'escape/outside.png'):
                with self.subTest(source=source):
                    failed = run_captured(command + [source], cwd=root)
                    self.assertNotEqual(failed.returncode, 0)
                    self.assertIn('must stay within repository AssetSources', failed.stderr)
            (sources / 'escape').unlink()
            sources.rmdir()
            sources.symlink_to(external, target_is_directory=True)
            failed = run_captured(command + ['outside.png'], cwd=root)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('AssetSources must stay within the repository', failed.stderr)

    def test_icon_preflight_rejects_external_package_members(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as external:
            root, library, _, _, env = self.make_relink_fixture(directory, 'app-icon')
            package = library / 'Old/Icon.icon'
            (package / 'Assets').mkdir(parents=True)
            (package / 'icon.json').write_text('{}')
            foreign = Path(external) / 'master.jpeg'
            foreign.write_bytes(b'external master')
            (package / 'Assets/master.jpeg').symlink_to(foreign)
            failed = run_captured([sys.executable, 'Scripts/asset-library.py', '--preflight', '--kind', 'app-icon'], cwd=root, env=env)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('Existing outputs were preserved', failed.stderr)

    def test_builds_never_relink_and_explicit_healing_retries_interrupted_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, log = self.make_audio_fixture(directory, 'sfx')
            for name in ('CI', 'GITHUB_ACTIONS'):
                env.pop(name, None)
            self.make_repo_fixture(directory, ('Scripts/prepare-assets.sh', 'Scripts/lib/args.sh',
                                               'Scripts/build-freshness.sh', 'Scripts/build-inputs.env',
                                               'Scripts/lib/generated-paths.sh', 'Scripts/config/generated-paths.tsv'))
            prepare = root / 'Scripts/prepare-assets.sh'
            prepare.rename(root / 'Scripts/prepare-selected-assets.sh')
            write_executable(prepare, '#!/bin/bash\nexec bash Scripts/prepare-selected-assets.sh "$@" --kind sfx\n')
            write_executable(root / 'Scripts/generate.sh', '#!/bin/bash\nexit 0\n')
            library = root / 'AssetSources'
            self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
            source = library / 'Raw Assets/Sound Effects/clip.wav'
            moved = library / 'Renamed.wav'
            source.rename(moved)
            manifest = root / 'SoundManifest/sfx.tsv'
            before = manifest.read_bytes()
            command = ['bash', '-ec', 'unset TRINKET_SHARED_DERIVED_DATA SKIP_GENERATE; '
                       'source Scripts/build-freshness.sh; prepare_generated_inputs results']
            run_captured(command, cwd=root, env={**env, 'CI': 'true'}, expected=0)
            self.assertEqual(manifest.read_bytes(), before)
            run_captured(command, cwd=root, env=env, expected=0)
            self.assertEqual(manifest.read_bytes(), before)
            pipeline = root / 'Scripts/prepare-audio-assets.sh'
            original = pipeline.read_bytes()
            pipeline.write_text('#!/bin/bash\nexit 9\n')
            repair = ['bash', 'Scripts/prepare-assets.sh', '--heal']
            run_captured(repair, cwd=root, env=env, expected=9)
            self.assertIn('Renamed.wav', manifest.read_text())
            pipeline.write_bytes(original)
            run_captured(repair, cwd=root, env=env, expected=0)
            checked = self.run_check(root, env, '--check')
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual((root / 'Trinket/Media/SFX/sfx_test_clip.m4a').read_bytes(), b'fixture audio')
            self.assertEqual(log.read_text().count('convert'), 1)

    def make_relink_fixture(self, directory, kind):
        root = self.make_repo_fixture(directory, ('Scripts/asset-library.py',))
        library = root / 'AssetSources'
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
        write_json(receipt, {kind: {'sources': hashes}})
        env = self.verification_environment()
        return root, library, manifest, receipt, env

    def test_explicit_relink_repairs_moved_art_and_complete_icon_packages(self):
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
                run_captured(command + ['--relink'], cwd=root, env=env, expected=0)
                self.assertEqual(manifest.read_bytes(), before)
                run_captured(command + ['--preflight'], cwd=root, env=env, expected=1)
                self.assertEqual(manifest.read_bytes(), before)
                run_captured(command + ['--relink', '--apply'], cwd=root, env=env, expected=0)
                prepared = run_captured(command + ['--preflight', '--snapshot'], cwd=root, env=env, expected=0)
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
                    write_json(receipt, record)
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
                result = run_captured([sys.executable, 'Scripts/asset-library.py', '--relink', '--apply', '--kind', kind], cwd=root, env=env)
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
            run_captured([sys.executable, 'Scripts/asset-library.py', '--preflight', '--kind', 'art'], cwd=root, env=env, expected=0)
            self.assertEqual(manifest.read_bytes(), before)
            self.assertEqual(selected.read_bytes(), b'intentionally revised artwork')

    def run_check(self, root, environment, *arguments):
        return run_captured(['python3', 'Scripts/asset-library.py', '--kind', 'sfx', *arguments], cwd=root, env=environment)

    def test_source_free_integrity_and_local_source_freshness(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, log = self.make_audio_fixture(directory, 'sfx')
            result = self.run_audio_fixture(root, env, 'sfx')
            self.assertEqual(result.returncode, 0, result.stderr)
            (root / 'AssetSources').rename(root / 'source-archive')
            checked = self.run_check(root, env, '--check', '--outputs-only')
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertNotEqual(self.run_check(root, env, '--check').returncode, 0)
            (root / 'source-archive').rename(root / 'AssetSources')
            source = root / 'AssetSources/Raw Assets/Sound Effects/clip.wav'
            source.write_bytes(b'updated source')
            local = self.run_check(root, env, '--check')
            self.assertNotEqual(local.returncode, 0)
            self.assertIn('sources changed', local.stderr)
            output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
            source.write_bytes(b'fixture audio')
            output.write_bytes(b'corrupt')
            corrupt = self.run_check(root, env, '--check', '--outputs-only')
            self.assertNotEqual(corrupt.returncode, 0)
            self.assertIn('outputs/catalogs changed', corrupt.stderr)
            repaired = self.run_audio_fixture(root, env, 'sfx')
            self.assertEqual(repaired.returncode, 0, repaired.stderr)
            self.assertEqual(output.read_bytes(), b'fixture audio')

    def test_receipt_refresh_retires_unknown_kinds_and_preserves_other_active_kinds(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, _ = self.make_audio_fixture(directory, 'sfx')
            receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
            other = {'input_hash': 'music-inputs', 'sources': {}, 'outputs': {}}
            write_json(receipt, {'music': other, 'retired': {'outputs': {}}})
            prepared = self.run_audio_fixture(root, env, 'sfx')
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            recorded = json.loads(receipt.read_text())
            self.assertEqual(recorded['music'], other)
            self.assertNotIn('retired', recorded)
            self.assertEqual(self.run_check(root, env, '--check', '--outputs-only').returncode, 0)

    def test_missing_later_source_preserves_all_outputs_and_orphans(self):
        for unavailable in ('missing', 'directory'):
            with self.subTest(unavailable=unavailable), tempfile.TemporaryDirectory() as directory:
                root, env, log = self.make_audio_fixture(directory, 'sfx')
                self.assertEqual(self.run_audio_fixture(root, env, 'sfx').returncode, 0)
                output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
                before = output.read_bytes()
                orphan = output.with_name('orphan.m4a')
                orphan.write_bytes(b'keep')
                (root / 'AssetSources/Raw Assets/Sound Effects/clip.wav').write_bytes(b'new source')
                if unavailable == 'directory':
                    (root / 'AssetSources/Missing.wav').mkdir()
                    (root / 'AssetSources/Missing.wav/unrelated.wav').write_bytes(b'not the selected source')
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

    def test_source_free_checks_reject_removed_boss_music_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root, env, _ = self.make_audio_fixture(directory, 'music')
            manifest = root / 'MusicManifest/music.tsv'
            manifest.write_text(manifest.read_text().replace('menu\t', 'boss\t').replace('\tnone\t', '\ttest_boss\t'))
            content = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift'
            content.write_text('id: "test_boss", isBoss: true\n')
            prepared = self.run_audio_fixture(root, env, 'music')
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            (root / 'AssetSources').rename(root / 'source-archive')
            command = ['python3', 'Scripts/asset-library.py', '--check', '--outputs-only', '--kind', 'music']
            checked = run_captured(command, cwd=root, env=env, expected=0)
            content.write_text('id: "test_boss", isBoss: false\n')
            checked = run_captured(command, cwd=root, env=env)
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
                    write_json(receipt, record)
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
                run_captured(['python3', 'Scripts/asset-library.py', '--check', '--kind', kind], cwd=root, env=env, expected=0)

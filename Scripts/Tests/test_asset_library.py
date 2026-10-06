#!/usr/bin/env python3
"""Protect private-source isolation and committed-output integrity."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

from script_test_support import ScriptRegressionTestCase

SCRIPT_INPUTS = ('Scripts/asset-library.py', 'Scripts/lib/media-assets.sh',
                 'Scripts/prepare-audio-assets.sh', 'Scripts/prepare-cinematic-assets.sh')


class AssetLibraryTests(ScriptRegressionTestCase):
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

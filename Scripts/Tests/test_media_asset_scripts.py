#!/usr/bin/env python3

from __future__ import annotations

import os
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, run_captured, write_executable

class MediaAssetScriptTests(ScriptRegressionTestCase):
    def test_sfx_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_audio_fixture(directory, "sfx")

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_audio_fixture(root, {**environment, **overrides}, "sfx")
                self.assertEqual(result.returncode, 0, result.stderr)
                conversion_count = conversion_log.read_text(encoding="utf-8").count("convert")
                self.assertEqual(conversion_count, expected_conversions)

            assert_run(1)
            generated = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift"
            ).read_text(encoding="utf-8")
            self.assertIn('public static let testClip = "test_clip"', generated)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXSourceHashes.generated.tsv"
            )
            with state.open("a", encoding="utf-8") as handle:
                handle.write("orphan\tstale\tstale-profile\n")

            assert_run(1)
            self.assertNotIn("orphan", state.read_text(encoding="utf-8"))

            assert_run(2, SFX_AAC_BITRATE="96000")

            state.unlink()
            assert_run(3)

            output = root / "Trinket/Media/SFX/sfx_test_clip.m4a"
            output.unlink()
            assert_run(4)

            output.write_bytes(b"")
            assert_run(5)
            self.assertGreater(output.stat().st_size, 0)

            assert_run(6, FORCE_ASSET_REENCODE="1")

    def test_sfx_manifest_rejects_invalid_and_duplicate_swift_symbols(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_audio_fixture(directory, "sfx")
            manifest = root / "SoundManifest/sfx.tsv"
            for reserved in ("repeat", "actor", "async", "package"):
                manifest.write_text(
                    f"test_clip\t{reserved}\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                    encoding="utf-8",
                )
                invalid = self.run_audio_fixture(root, environment, "sfx")
                self.assertNotEqual(invalid.returncode, 0, reserved)
                self.assertIn("reserved Swift keyword", invalid.stderr, reserved)

            manifest.write_text(
                "first\tsharedSymbol\tsfx_first\tRaw Assets/Sound Effects/clip.wav\t1.0\n"
                "second\tsharedSymbol\tsfx_second\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                encoding="utf-8",
            )
            duplicate = self.run_audio_fixture(root, environment, "sfx")
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn("Duplicate SFX Swift symbol 'sharedSymbol'", duplicate.stderr)

    def test_music_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_audio_fixture(directory, "music")
            scratch = root / "temporary music"
            scratch.mkdir()
            environment["TMPDIR"] = str(scratch)
            write_executable(root / "bin/mktemp", '#!/bin/sh\nexec /usr/bin/mktemp "$TMPDIR/music.XXXXXX"\n')

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_audio_fixture(root, {**environment, **overrides}, "music")
                self.assertEqual(result.returncode, 0, result.stderr)
                conversion_count = conversion_log.read_text(encoding="utf-8").count("convert")
                self.assertEqual(conversion_count, expected_conversions)
                self.assertEqual(list(scratch.iterdir()), [])

            assert_run(1)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/MusicSourceHashes.generated.tsv"
            )
            with state.open("a", encoding="utf-8") as handle:
                handle.write("orphan\tstale\tstale-profile\n")

            assert_run(1)
            self.assertNotIn("orphan", state.read_text(encoding="utf-8"))
            assert_run(2, MUSIC_AAC_BITRATE="128000")
            assert_run(3, FORCE_ASSET_REENCODE="1")

            catalog = state.with_name("MusicCatalog.generated.swift")
            previous = {path: path.read_bytes() for path in (catalog, state)}
            manifest = root / "MusicManifest/music.tsv"
            manifest.write_text(manifest.read_text().replace("1.0", "0.5"))
            # Refuse the atomic catalog replacement, after conversion succeeds.
            failed = run_captured([sys.executable, '-c', """
import pathlib, runpy, sys
replace = pathlib.Path.replace
def refuse_catalog(self, target):
    if pathlib.Path(target).name == 'MusicCatalog.generated.swift':
        raise OSError('catalog replacement refused')
    return replace(self, target)
pathlib.Path.replace = refuse_catalog
sys.argv = ['Scripts/prepare-media.py', 'music']
runpy.run_path(sys.argv[0], run_name='__main__')
"""], cwd=root, env=environment)
            self.assertEqual(failed.returncode, 1, failed.stderr)
            self.assertIn('catalog replacement refused', failed.stderr)
            self.assertEqual(list(scratch.iterdir()), [])
            self.assertFalse(list(state.parent.glob("*.tmp.*")))
            for path, content in previous.items():
                self.assertEqual(path.read_bytes(), content)

    def test_boss_lyrics_bind_recording_and_refresh_catalog_without_reencoding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, log = self.make_audio_fixture(directory, "music")
            manifest = root / "MusicManifest/music.tsv"
            manifest.write_text(manifest.read_text().replace("menu\ttest_track", "boss\ttest_track").replace("none\t", "treant\t"))
            generated = root / "Packages/TrinketContent/Sources/TrinketContent/Generated"
            (generated / "GameContentEnemies.generated.swift").write_text('id: "treant", isBoss: true')
            lyrics = root / "MusicManifest/lyrics/test_track.json"
            lyrics.parent.mkdir()
            data = {"audioSha256": hashlib.sha256(b"fixture music").hexdigest(),
                    "lines": [{"text": "I grow", "timings": [0.5, 1, 1.2, 2]}]}
            lyrics.write_text(json.dumps(data))
            result = self.run_audio_fixture(root, environment, "music")
            self.assertEqual(result.returncode, 0, result.stderr)
            catalog = generated / "MusicCatalog.generated.swift"
            before = catalog.read_bytes()
            self.assertIn(b'MusicLyricPhrase(text: "I grow", timings: [0.5, 1, 1.2, 2])', before)
            self.assertEqual(self.run_audio_fixture(root, environment, "music").returncode, 0)
            self.assertEqual(catalog.read_bytes(), before)
            self.assertEqual(log.read_text().count("convert"), 1)
            data["lines"][0]["timings"][-1] = 2.5
            lyrics.write_text(json.dumps(data))
            check = [sys.executable, "Scripts/asset-library.py", "--check", "--outputs-only", "--kind", "music"]
            self.assertNotEqual(run_captured(check, cwd=root, env=environment).returncode, 0)
            self.assertEqual(self.run_audio_fixture(root, environment, "music").returncode, 0)
            self.assertNotEqual(catalog.read_bytes(), before)
            self.assertEqual(log.read_text().count("convert"), 1)
            self.assertEqual(run_captured(check, cwd=root, env=environment).returncode, 0)

    def test_invalid_lyrics_preserve_shipping_outputs_and_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, log = self.make_audio_fixture(directory, "music")
            manifest = root / "MusicManifest/music.tsv"
            manifest.write_text(manifest.read_text().replace("menu\ttest_track", "boss\ttest_track").replace("none\t", "treant\t"))
            generated = root / "Packages/TrinketContent/Sources/TrinketContent/Generated"
            (generated / "GameContentEnemies.generated.swift").write_text('id: "treant", isBoss: true')
            self.assertEqual(self.run_audio_fixture(root, environment, "music").returncode, 0)
            orphan = root / "Trinket/Media/Music/orphan.m4a"
            orphan.write_bytes(b"preserve")
            before = {path: path.read_bytes() for path in [orphan, *generated.iterdir()]}
            folder = root / "MusicManifest/lyrics"
            folder.mkdir()
            source_hash = hashlib.sha256(b"fixture music").hexdigest()
            cases = [
                ("unknown", source_hash, "I grow", [0, 1, 1, 2]),
                ("test_track", "wrong recording", "I grow", [0, 1, 1, 2]),
                ("test_track", source_hash, "I grow", [0, 1]),
                ("test_track", source_hash, "I grow", [0, 1, 0.5, 2]),
                ("test_track", source_hash, "I grow", [0, 0, 1, 2]),
                ("test_track", source_hash, "I grow", [0, 1, 1, float("nan")]),
            ]
            for track, digest, text, timings in cases:
                with self.subTest(track=track, digest=digest, timings=timings):
                    lyrics = folder / (track + ".json")
                    lyrics.write_text(json.dumps({"audioSha256": digest, "lines": [{"text": text, "timings": timings}]}))
                    result = self.run_audio_fixture(root, environment, "music")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Lyrics", result.stderr)
                    self.assertEqual({path: path.read_bytes() for path in before}, before)
                    self.assertEqual(log.read_text().count("convert"), 1)
                    lyrics.unlink()

    def test_media_orphan_pruning_is_extension_scoped(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_audio_fixture(directory, "sfx")
            resources = root / "Trinket/Media/SFX"
            self.assertEqual(self.run_audio_fixture(root, environment, "sfx").returncode, 0)
            for name in ("remove.m4a", "ignore.txt"):
                (resources / name).write_text(name)
            result = self.run_audio_fixture(root, environment, "sfx")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((resources / "sfx_test_clip.m4a").exists())
            self.assertFalse((resources / "remove.m4a").exists())
            self.assertTrue((resources / "ignore.txt").exists())

    def test_invalid_later_row_preserves_encoded_media_and_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, log = self.make_audio_fixture(directory, "sfx")
            self.assertEqual(self.run_audio_fixture(root, environment, "sfx").returncode, 0)
            generated = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated'
            output = root / 'Trinket/Media/SFX/sfx_test_clip.m4a'
            orphan = output.with_name('orphan.m4a')
            orphan.write_bytes(b'retain until validation succeeds')
            before = {path: path.read_bytes() for path in [output, orphan, *generated.iterdir()]}
            (root / 'Raw Assets/Sound Effects/clip.wav').write_bytes(b'revised source')
            with (root / 'SoundManifest/sfx.tsv').open('a') as stream:
                stream.write('invalid\trepeat\tinvalid\tRaw Assets/Sound Effects/clip.wav\t1.0\n')
            result = self.run_audio_fixture(root, environment, "sfx")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('reserved Swift keyword', result.stderr)
            self.assertEqual(log.read_text().count('convert'), 1)
            self.assertEqual({path: path.read_bytes() for path in before}, before)

    def test_failed_imageset_install_restores_previous_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_art_fixture(directory)
            (root / 'ArtManifest/curated-assets.tsv').write_text(
                'combatant\tknight\thero_knight_card\tRaw Assets/source.jpeg\t0.5\t0.5\n')
            self.assertEqual(self.run_art_fixture(root, environment).returncode, 0)
            imageset = root / 'Trinket/Assets.xcassets/hero_knight_card.imageset'
            receipt = root / 'Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json'
            before = {path: path.read_bytes() for path in [receipt, *imageset.iterdir()]}
            result = run_captured([sys.executable, '-c', """
import pathlib, runpy, sys
replace = pathlib.Path.replace
def refuse_install(self, target):
    if self.name == 'hero_knight_card.imageset' and self.parent.name.startswith('.media-'):
        raise OSError('imageset installation refused')
    return replace(self, target)
pathlib.Path.replace = refuse_install
sys.argv = ['Scripts/prepare-media.py', 'art']
runpy.run_path(sys.argv[0], run_name='__main__')
"""], cwd=root, env={**environment, 'FORCE_ASSET_REENCODE': '1'})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('imageset installation refused', result.stderr)
            self.assertEqual({path: path.read_bytes() for path in before}, before)
            self.assertFalse(list(imageset.parent.glob('.media-*')))

    def test_project_yml_keeps_assets_outside_swift_sync_roots(self) -> None:
        text = (ROOT / "project.yml").read_text(encoding="utf-8")
        self.assertIn("path: Trinket/App", text)
        self.assertIn("type: syncedFolder", text)
        self.assertIn("path: Trinket/Assets.xcassets", text)
        self.assertIn("path: Trinket/Media", text)
        self.assertIn("path: Trinket/AppIcon.icon", text)
        # Whole-folder sync of Trinket/ would pull assets into the FS sync root.
        self.assertNotRegex(
            text,
            r"(?m)^\s+- path: Trinket\n\s+type: syncedFolder\n",
        )

    def make_art_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = self.make_repo_fixture(directory, ("Scripts/prepare-art-assets.sh", "Scripts/prepare-media.py"))
        for relative in (
            "ArtManifest",
            "Raw Assets",
            "Trinket/Assets.xcassets",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "Packages/TrinketContent/Sources/TrinketContent/Abilities",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)
        (root / "Raw Assets/source.jpeg").write_bytes(b"source")
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift").write_text(
            'id: "knight"\n', encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift").write_text(
            "", encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog+Basic.swift").write_text(
            'id: "slash"\n', encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift").write_text(
            'id: "longsword"\n', encoding="utf-8"
        )
        for tier in ("Skill", "Ultimate"):
            (root / f"Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog+{tier}.swift").write_text("")
        write_executable(
            root / "bin/sips",
            "#!/usr/bin/env python3\n"
            "import pathlib, sys\n"
            "args = sys.argv[1:]\n"
            "if '--out' in args:\n"
            "    out = pathlib.Path(args[args.index('--out') + 1])\n"
            "    out.write_bytes(b'encoded')\n"
            "    with open(__import__('os').environ['ART_TEST_LOG'], 'a') as log:\n"
            "        log.write(out.name + ':' + args[args.index('-Z') + 1] + '\\n')\n"
            "elif '-g' in args:\n"
            "    portrait = 'portrait' in args[-1]\n"
            "    print('pixelWidth:', 1536 if portrait else 1600)\n"
            "    print('pixelHeight:', 2752 if portrait else 1194)\n",
        )
        log = root / "conversions.log"
        log.write_text("", encoding="utf-8")
        environment = {
            **os.environ,
            "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
            "ART_TEST_LOG": str(log),
        }
        return root, environment, log

    def run_art_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return run_captured(["bash", "Scripts/prepare-art-assets.sh"], cwd=root, env=environment)

    def test_art_kind_matrix_emits_expected_variants(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, log = self.make_art_fixture(directory)
            (root / "ArtManifest/curated-assets.tsv").write_text(
                "combatant\tknight\thero_knight_card\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "ability\tslash\tability_slash\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "item\tlongsword-basic\titem_longsword_basic\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "slot_background\tweapon\tslot_weapon\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "background\tfield\tbg_field\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "portrait_background\tfield_portrait\tbg_field_portrait\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "encounter\tshop\tdest_shop\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "resource\twood\tresource_wood\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "talent\tburn\ttalent_burn\tRaw Assets/source.jpeg\t0.5\t0.5\n",
                encoding="utf-8",
            )
            first = self.run_art_fixture(root, environment)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(
                sorted(log.read_text().splitlines()),
                sorted([
                    "hero_knight_card.heic:1320", "hero_knight_card_thumb.heic:480",
                    "ability_slash.heic:960", "ability_slash_thumb.heic:480",
                    "item_longsword_basic.heic:960", "item_longsword_basic_thumb.heic:480",
                    "slot_weapon.heic:720",
                    "bg_field.heic:1600", "bg_field_thumb.heic:480",
                    "bg_field_portrait.heic:2752", "bg_field_portrait_thumb.heic:960",
                    "dest_shop.heic:1320", "dest_shop_thumb.heic:480",
                    "resource_wood.heic:256",
                    "talent_burn.heic:960", "talent_burn_thumb.heic:480",
                ]),
            )
            catalog = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift"
            ).read_text(encoding="utf-8")
            for section in (
                "combatantArtByID", "abilityArtByID", "itemArtByID", "slotBackgroundArtByID",
                "backgroundArtByID", "portraitBackgroundArtByID", "encounterArtByID",
                "resourceArtByID", "talentArtByID",
            ):
                self.assertIn(section, catalog)
            self.assertIn('"\\(imageName)_thumb"', catalog)
            self.assertIn("sourceAspectRatio: 0.558139534884", catalog)
            self.assertIn(".burn: TalentArtReference(", catalog)
            self.assertIn(".weapon: SlotBackgroundArtReference(", catalog)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtSourceHashes.generated.tsv"
            ).read_text(encoding="utf-8")
            self.assertTrue(state.splitlines()[1].startswith("# asset_name\tsource_sha256\tencode_profile"))
            outputs = [root / "Trinket/Assets.xcassets/Contents.json",
                       root / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift"]
            for output in outputs:
                os.utime(output, (1000000000, 1000000000))
            second = self.run_art_fixture(root, environment)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertTrue(all(output.stat().st_mtime == 1000000000 for output in outputs))
            self.assertEqual(len(log.read_text().splitlines()), 16)
            self.assertEqual(
                (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift").read_text(
                    encoding="utf-8"
                ),
                catalog,
            )

    def test_art_rejects_unbacked_ids_and_prunes_orphans(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_art_fixture(directory)
            scratch = root / "scratch"
            scratch.mkdir()
            environment["TMPDIR"] = str(scratch)
            manifest = root / "ArtManifest/curated-assets.tsv"
            manifest.write_text(
                "combatant\tknight\thero_knight_card\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "combatant\tbogus\tbogus_card\tRaw Assets/source.jpeg\t0.5\t0.5\n",
                encoding="utf-8",
            )
            rejected = self.run_art_fixture(root, environment)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn('Art selection combatant "bogus"', rejected.stderr)
            self.assertEqual(list(scratch.iterdir()), [])
            manifest.write_text(
                "combatant\tknight\thero_knight_card\tRaw Assets/source.jpeg\t0.5\t0.5\n",
                encoding="utf-8",
            )
            ok = self.run_art_fixture(root, environment)
            self.assertEqual(ok.returncode, 0, ok.stderr)
            stray = root / "Trinket/Assets.xcassets/hero_stray.imageset"
            stray.mkdir(parents=True)
            (stray / "hero_stray.heic").write_bytes(b"stale")
            pruned = self.run_art_fixture(root, environment)
            self.assertEqual(pruned.returncode, 0, pruned.stderr)
            self.assertIn("Pruning orphaned asset: hero_stray.imageset", pruned.stdout)
            self.assertFalse(stray.exists())

            product = root / "Trinket/Assets.xcassets/hero_knight_card.imageset/hero_knight_card.heic"
            previous = product.read_bytes()
            (root / "bin/sips").write_text("#!/bin/bash\nexit 23\n")
            environment["FORCE_ASSET_REENCODE"] = "1"
            failed = self.run_art_fixture(root, environment)
            self.assertEqual(failed.returncode, 23, failed.stderr)
            self.assertEqual(product.read_bytes(), previous)
            self.assertEqual(list(scratch.iterdir()), [])
            self.assertFalse(list((root / "Trinket/Assets.xcassets").glob("*.tmp.*")))

    def test_sfx_volume_gain_accepts_leading_dot_decimal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_audio_fixture(directory, "sfx")
            (root / "SoundManifest/sfx.tsv").write_text(
                "test_clip\ttestClip\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t.5\n",
                encoding="utf-8",
            )
            result = self.run_audio_fixture(root, environment, "sfx")
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift"
            ).read_text(encoding="utf-8")
            self.assertIn("volumeGain: .5", generated)

    def test_app_icon_fixture_installs_once_and_stays_stable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, ("Scripts/prepare-app-icon.sh", "Scripts/prepare-media.py"))
            for relative in (
                "Scripts/lib",
                "Raw Assets/App Icon/Trinket App Icon.icon",
                "Trinket",
                "Packages/TrinketContent/Sources/TrinketContent/Generated",
            ):
                (root / relative).mkdir(parents=True, exist_ok=True)
            for relative in ("Scripts/prepare-app-icon.sh", "Scripts/prepare-media.py"):
                write_executable(root / relative, (ROOT / relative).read_text(encoding="utf-8"))
            (root / "Raw Assets/App Icon/Trinket App Icon.icon/icon.json").write_text(
                "{}", encoding="utf-8"
            )
            (root / "Raw Assets/App Icon/Trinket App Icon.icon/contents.dat").write_bytes(b"icon")
            command = ["bash", "Scripts/prepare-app-icon.sh"]

            first = run_captured(command, cwd=root, expected=0)
            self.assertIn("Installed", first.stdout)
            self.assertTrue((root / "Trinket/AppIcon.icon/icon.json").is_file())
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/AppIconSourceHashes.generated.tsv"
            ).read_text(encoding="utf-8")
            self.assertTrue(state.splitlines()[1].startswith("# asset_name\tsource_sha256\tencode_profile"))

            second = run_captured(command, cwd=root, expected=0)
            self.assertNotIn("Installed", second.stdout)

            # The focused pipeline must consume the manifest after preflight
            # repairs a relocated master, just like the unified asset command.
            library = root / "library"
            library.mkdir()
            (root / "Raw Assets/App Icon/Trinket App Icon.icon").rename(library / "Moved.icon")
            environment = {**os.environ, 'ASSET_LIBRARY_ROOT': str(library)}
            run_captured(command, cwd=root, env=environment, expected=0)
            self.assertIn("Moved.icon", (root / "ArtManifest/app-icon.tsv").read_text())
            self.assertEqual((root / "Trinket/AppIcon.icon/contents.dat").read_bytes(), b"icon")
            run_captured([sys.executable, 'Scripts/asset-library.py', '--check', '--kind', 'app-icon'], cwd=root, env=environment, expected=0)

if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class MediaAssetScriptTests(ScriptRegressionTestCase):
    def test_portrait_art_has_independent_size_and_preserves_landscape(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ("Scripts/lib", "ArtManifest", "Raw Assets", "bin"):
                (root / folder).mkdir(parents=True, exist_ok=True)
            for relative in ("Scripts/prepare-art-assets.sh", "Scripts/lib/media-assets.sh"):
                target = root / relative
                target.write_text((ROOT / relative).read_text(), encoding="utf-8")
                target.chmod(0o755)
            (root / "Raw Assets/source.jpeg").write_bytes(b"source")
            (root / "ArtManifest/curated-assets.tsv").write_text(
                "background\twheatField\tbg_field\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "portrait_background\twheatField\tbg_field_portrait\tRaw Assets/source.jpeg\t0.5\t0.5\n",
                encoding="utf-8",
            )
            sips = root / "bin/sips"
            sips.write_text(
                "#!/usr/bin/env python3\n"
                "import os, pathlib, sys\n"
                "args = sys.argv[1:]\n"
                "if '--out' in args:\n"
                "    out = pathlib.Path(args[args.index('--out') + 1])\n"
                "    out.write_bytes(b'encoded')\n"
                "    with open(os.environ['ART_TEST_LOG'], 'a') as log:\n"
                "        log.write(out.name + ':' + args[args.index('-Z') + 1] + '\\n')\n"
                "elif '-g' in args:\n"
                "    portrait = 'portrait' in args[-1]\n"
                "    print('pixelWidth:', 1536 if portrait else 1600)\n"
                "    print('pixelHeight:', 2752 if portrait else 1194)\n",
                encoding="utf-8",
            )
            sips.chmod(0o755)
            log = root / "conversions.log"
            environment = {
                **os.environ,
                "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
                "ART_TEST_LOG": str(log),
            }
            command = ["bash", str(root / "Scripts/prepare-art-assets.sh")]
            first = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(
                sorted(log.read_text().splitlines()),
                ["bg_field.heic:1600", "bg_field_portrait.heic:2752", "bg_field_portrait_thumb.heic:960", "bg_field_thumb.heic:480"],
            )
            catalog = root / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift"
            generated = catalog.read_text()
            self.assertIn("portraitBackgroundArtByID", generated)
            self.assertIn('thumbnailImageName: "bg_field_portrait_thumb"', generated)
            self.assertIn("sourceAspectRatio: 0.558139534884", generated)
            second = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(len(log.read_text().splitlines()), 4)
            self.assertEqual(catalog.read_text(), generated)

    def test_sfx_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_sfx_fixture(directory)

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_sfx_fixture(root, {**environment, **overrides})
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

            assert_run(5, FORCE_ASSET_REENCODE="1")

    def test_sfx_manifest_rejects_invalid_and_duplicate_swift_symbols(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, _ = self.make_sfx_fixture(directory)
            manifest = root / "SoundManifest/sfx.tsv"
            for reserved in ("repeat", "actor", "async", "package"):
                manifest.write_text(
                    f"test_clip\t{reserved}\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                    encoding="utf-8",
                )
                invalid = self.run_sfx_fixture(root, environment)
                self.assertNotEqual(invalid.returncode, 0, reserved)
                self.assertIn("reserved Swift keyword", invalid.stderr, reserved)

            manifest.write_text(
                "first\tsharedSymbol\tsfx_first\tRaw Assets/Sound Effects/clip.wav\t1.0\n"
                "second\tsharedSymbol\tsfx_second\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
                encoding="utf-8",
            )
            duplicate = self.run_sfx_fixture(root, environment)
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn("Duplicate SFX Swift symbol 'sharedSymbol'", duplicate.stderr)

    def test_music_cache_tracks_profile_state_output_and_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, environment, conversion_log = self.make_music_fixture(directory)

            def assert_run(expected_conversions: int, **overrides: str) -> None:
                result = self.run_music_fixture(root, {**environment, **overrides})
                self.assertEqual(result.returncode, 0, result.stderr)
                conversion_count = conversion_log.read_text(encoding="utf-8").count("convert")
                self.assertEqual(conversion_count, expected_conversions)

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

    def test_assert_generated_output_supports_tiered_asset_idempotence(self) -> None:
        text = (ROOT / "Scripts" / "assert-generated-output.sh").read_text(encoding="utf-8")
        self.assertIn("snapshot_tracked_asset_catalogs", text)
        self.assertIn("snapshot_for_idempotent_check", text)
        self.assertIn("--strict-assets", text)

    def test_media_orphan_pruning_is_extension_scoped(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resources = root / "Media"
            resources.mkdir()
            active = root / "active.txt"
            active.write_text("keep.mp4\n", encoding="utf-8")
            for name in ("keep.mp4", "remove.mp4", "ignore.m4a"):
                (resources / name).write_text(name, encoding="utf-8")

            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; trinket_asset_prune_orphans "$2" "$3" cinematic mp4',
                    "media-prune-test",
                    str(ROOT / "Scripts/lib/media-assets.sh"),
                    str(resources),
                    str(active),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((resources / "keep.mp4").exists())
            self.assertFalse((resources / "remove.mp4").exists())
            self.assertTrue((resources / "ignore.m4a").exists())

    def test_prepare_asset_scripts_use_c_locale_header_preserving_sort(self) -> None:
        scripts = tuple(
            path.name
            for path in sorted((ROOT / "Scripts").glob("prepare-*.sh"))
        )
        for name in scripts:
            text = (ROOT / "Scripts" / name).read_text(encoding="utf-8")
            sort_owner = (
                (ROOT / "Scripts" / "lib" / "media-assets.sh").read_text(encoding="utf-8")
                if "source \"Scripts/lib/media-assets.sh\"" in text
                else text
            )
            self.assertTrue(
                "LC_ALL=C sort" in sort_owner,
                name,
            )
            self.assertTrue(
                ("head -n 2" in sort_owner and "tail -n +3" in sort_owner)
                or ("grep -v '^#'" in sort_owner and "# asset_name" in sort_owner),
                f"{name} should preserve hash TSV headers before sorting",
            )
            self.assertIn("cmp -s", sort_owner, f"{name} should skip rewriting unchanged hash/catalog stamps")

    def test_prepare_art_skips_unchanged_catalog_contents_json(self) -> None:
        text = (ROOT / "Scripts" / "prepare-art-assets.sh").read_text(encoding="utf-8")
        self.assertIn("contents_json_temp", text)
        self.assertIn(
            'trinket_asset_commit_generated "$contents_json_temp" "$asset_catalog/Contents.json"',
            text,
        )
        self.assertIn(
            'trinket_asset_commit_generated "$generated_temp" "$generated_swift"',
            text,
        )

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

    def test_media_assets_lib_routes_asset_generation(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/lib/media-assets.sh",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/generate.sh --assets", plan)
        self.assertIn("./Scripts/test-scripts.sh", plan)

    def make_art_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "ArtManifest",
            "Raw Assets",
            "Trinket/Assets.xcassets",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "Packages/TrinketContent/Sources/TrinketContent/Content",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)
        for relative in ("Scripts/prepare-art-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)
        (root / "Raw Assets/source.jpeg").write_bytes(b"source")
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentRoster.generated.swift").write_text(
            'id: "knight"\n', encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift").write_text(
            "", encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift").write_text(
            'id: "slash"\n', encoding="utf-8"
        )
        for name in ("AbilityCatalogSkill.swift", "AbilityCatalogUltimate.swift"):
            (root / "Packages/TrinketContent/Sources/TrinketContent/Content" / name).write_text(
                "", encoding="utf-8"
            )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentItemBases.generated.swift").write_text(
            'id: "longsword"\n', encoding="utf-8"
        )
        sips = root / "bin/sips"
        sips.write_text(
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
            encoding="utf-8",
        )
        sips.chmod(0o755)
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
        return subprocess.run(
            ["bash", "Scripts/prepare-art-assets.sh"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

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
            self.assertIn("dict[.burn]", catalog)
            self.assertIn("dict[.weapon]", catalog)
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/ArtSourceHashes.generated.tsv"
            ).read_text(encoding="utf-8")
            self.assertTrue(state.splitlines()[1].startswith("# asset_name\tsource_sha256\tencode_profile"))
            second = self.run_art_fixture(root, environment)
            self.assertEqual(second.returncode, 0, second.stderr)
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
            manifest = root / "ArtManifest/curated-assets.tsv"
            manifest.write_text(
                "combatant\tknight\thero_knight_card\tRaw Assets/source.jpeg\t0.5\t0.5\n"
                "combatant\tbogus\tbogus_card\tRaw Assets/source.jpeg\t0.5\t0.5\n",
                encoding="utf-8",
            )
            rejected = self.run_art_fixture(root, environment)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("Combatant art id 'bogus'", rejected.stderr)
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

    def test_cinematic_fixture_converts_once_and_stays_stable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in (
                "Scripts/lib",
                "CinematicManifest",
                "ContentManifest",
                "Raw Assets/Animations",
                "Trinket/Media/Cinematics",
                "Packages/TrinketContent/Sources/TrinketContent/Generated",
                "Packages/TrinketContent/Sources/TrinketContent/Content",
                "bin",
            ):
                (root / relative).mkdir(parents=True, exist_ok=True)
            for relative in ("Scripts/prepare-cinematic-assets.sh", "Scripts/lib/media-assets.sh"):
                destination = root / relative
                destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
                destination.chmod(0o755)
            (root / "Raw Assets/Animations/slash.mp4").write_bytes(b"master")
            (root / "CinematicManifest/cinematics.tsv").write_text(
                "knight\tavatar-of-justice\tknight_avatar\tRaw Assets/Animations/slash.mp4\ttrue\n",
                encoding="utf-8",
            )
            (root / "ContentManifest/combatants.tsv").write_text(
                "id\tname\trole\tmax_health\tmax_mana\tbasics\tskills\tultimates\n"
                "knight\tKnight\thero\t100\t0\tslash\tslash\tavatarOfJustice\n",
                encoding="utf-8",
            )
            (root / "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogUltimate.swift").write_text(
                'id: "avatar-of-justice"\n', encoding="utf-8"
            )
            avconvert = root / "bin/avconvert"
            avconvert.write_text(
                "#!/usr/bin/env python3\n"
                "import os, pathlib, re, sys\n"
                "args = sys.argv[1:]\n"
                "out = pathlib.Path(args[args.index('--output') + 1])\n"
                "src = pathlib.Path(args[args.index('--source') + 1])\n"
                "out.write_bytes(src.read_bytes() + b'hvc1')\n"
                "name = out.name.lstrip('.')\n"
                "name = re.sub(r'\\.tmp\\.\\d+', '', name)\n"
                "with open(os.environ['AVCONVERT_LOG'], 'a') as log:\n"
                "    log.write(name + '\\n')\n",
                encoding="utf-8",
            )
            avconvert.chmod(0o755)
            log = root / "conversions.log"
            log.write_text("", encoding="utf-8")
            environment = {
                **os.environ,
                "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
                "AVCONVERT_LOG": str(log),
            }
            command = ["bash", "Scripts/prepare-cinematic-assets.sh"]

            first = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(log.read_text().splitlines(), ["knight_avatar.mp4"])
            catalog = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift"
            ).read_text(encoding="utf-8")
            self.assertIn('"knight|avatar-of-justice"', catalog)

            second = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(log.read_text().splitlines(), ["knight_avatar.mp4"])
            self.assertEqual(
                (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift").read_text(
                    encoding="utf-8"
                ),
                catalog,
            )

    def test_app_icon_fixture_installs_once_and_stays_stable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in (
                "Scripts/lib",
                "Raw Assets/App Icon/Trinket App Icon.icon",
                "Trinket",
                "Packages/TrinketContent/Sources/TrinketContent/Generated",
            ):
                (root / relative).mkdir(parents=True, exist_ok=True)
            for relative in ("Scripts/prepare-app-icon.sh", "Scripts/lib/media-assets.sh"):
                destination = root / relative
                destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
                destination.chmod(0o755)
            (root / "Raw Assets/App Icon/Trinket App Icon.icon/icon.json").write_text(
                "{}", encoding="utf-8"
            )
            (root / "Raw Assets/App Icon/Trinket App Icon.icon/contents.dat").write_bytes(b"icon")
            command = ["bash", "Scripts/prepare-app-icon.sh"]

            first = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertIn("Installed", first.stdout)
            self.assertTrue((root / "Trinket/AppIcon.icon/icon.json").is_file())
            state = (
                root
                / "Packages/TrinketContent/Sources/TrinketContent/Generated/AppIconSourceHashes.generated.tsv"
            ).read_text(encoding="utf-8")
            self.assertTrue(state.splitlines()[1].startswith("# asset_name\tsource_sha256\tencode_profile"))

            second = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertNotIn("Installed", second.stdout)

if __name__ == "__main__":
    unittest.main()

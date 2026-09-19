#!/usr/bin/env python3

"""Shared fixtures for script regression modules."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))

from internal.cli import load_sibling


def load_script(name: str, filename: str):
    """Load a Scripts/ module by filename (shared with internal.cli.load_sibling)."""
    return load_sibling(name, filename)


class ScriptRegressionTestCase(unittest.TestCase):

    def make_repo_fixture(self, directory: str, files: Iterable[str]) -> Path:
        """Create an isolated repo root holding copies of repository files.

        `files` are repository-relative paths (e.g. "Scripts/build-freshness.sh");
        parent directories are created. Returns the root. Callers add any
        synthetic files (stubs, manifests) on top.
        """
        root = Path(directory)
        for relative in files:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        return root

    # Shared audio-fixture shape; only the manifest/raw/media layout differs.
    _AUDIO_FIXTURES = {
        "sfx": {
            "manifest_dir": "SoundManifest",
            "manifest_file": "sfx.tsv",
            "manifest_row": (
                "# id\tswift_symbol\tasset_name\tsource_path\tvolume_gain\n"
                "test_clip\ttestClip\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n"
            ),
            "raw_dir": "Raw Assets/Sound Effects",
            "raw_file": "clip.wav",
            "raw_bytes": b"fixture audio",
            "media_dir": "Trinket/Media/SFX",
        },
        "music": {
            "manifest_dir": "MusicManifest",
            "manifest_file": "music.tsv",
            "manifest_row": (
                "# kind\tid\tasset_name\tsource_path\tboss_enemy_id\tlooping\tvolume_gain\n"
                "menu\ttest_track\tmusic_test_track\tRaw Assets/Music/track.mp3\tnone\ttrue\t1.0\n"
            ),
            "raw_dir": "Raw Assets/Music",
            "raw_file": "track.mp3",
            "raw_bytes": b"fixture music",
            "media_dir": "Trinket/Media/Music",
        },
    }

    def make_audio_fixture(self, directory: str, kind: str) -> tuple[Path, dict[str, str], Path]:
        fixture = self._AUDIO_FIXTURES[kind]
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            fixture["manifest_dir"],
            fixture["raw_dir"],
            fixture["media_dir"],
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        for relative in ("Scripts/prepare-audio-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)

        source = root / fixture["raw_dir"] / fixture["raw_file"]
        source.write_bytes(fixture["raw_bytes"])
        (root / fixture["manifest_dir"] / fixture["manifest_file"]).write_text(
            fixture["manifest_row"],
            encoding="utf-8",
        )

        conversion_log = root / "afconvert.log"
        afconvert = root / "bin/afconvert"
        afconvert.write_text(
            "#!/usr/bin/env bash\n"
            "printf 'convert\\n' >> \"$AFCONVERT_LOG\"\n"
            "cp \"$1\" \"$2\"\n",
            encoding="utf-8",
        )
        afconvert.chmod(0o755)
        environment = {
            **os.environ,
            "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
            "AFCONVERT_LOG": str(conversion_log),
        }
        return root, environment, conversion_log

    def make_sfx_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        return self.make_audio_fixture(directory, "sfx")

    def run_sfx_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(root / "Scripts/prepare-audio-assets.sh"), "sfx"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def make_music_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        return self.make_audio_fixture(directory, "music")

    def run_music_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "Scripts/prepare-audio-assets.sh", "music"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    _CINEMATIC_MANIFEST_ROW = "knight\tavatar-of-justice\tknight_avatar\tRaw Assets/Animations/slash.mp4\ttrue\n"
    _CINEMATIC_COMBATANTS_TSV = (
        "id\tname\trole\tmax_health\tmax_mana\tbasics\tskills\tultimates\n"
        "knight\tKnight\thero\t100\t0\tslash\tslash\tavatarOfJustice\n"
    )
    _CINEMATIC_INVENTORY_TSV = (
        "id\tname\ttier\tsummary\n"
        "avatar-of-justice\tAvatar\tultimate\tTest ultimate.\n"
        "bash\tBash\tbasic\tTest basic.\n"
    )

    def make_cinematic_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "CinematicManifest",
            "ContentManifest",
            "Raw Assets/Animations",
            "Trinket/Media/Cinematics",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)
        for relative in ("Scripts/prepare-cinematic-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)
        (root / "Raw Assets/Animations/slash.mp4").write_bytes(b"master")
        (root / "CinematicManifest/cinematics.tsv").write_text(
            self._CINEMATIC_MANIFEST_ROW, encoding="utf-8"
        )
        (root / "ContentManifest/combatants.tsv").write_text(
            self._CINEMATIC_COMBATANTS_TSV, encoding="utf-8"
        )
        (root / "Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv").write_text(
            self._CINEMATIC_INVENTORY_TSV, encoding="utf-8"
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
        return root, environment, log

    def run_cinematic_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "Scripts/prepare-cinematic-assets.sh"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

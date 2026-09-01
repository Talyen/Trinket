#!/usr/bin/env python3

"""Shared fixtures for script regression modules."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "Scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class ScriptRegressionTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls) -> None:
        cls.codegen = load_script("content_codegen", "content_codegen.py")
        cls.check_docs = load_script("check_docs", "check-docs.py")

    def make_sfx_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "SoundManifest",
            "Raw Assets/Sound Effects",
            "Trinket/Media/SFX",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        for relative in ("Scripts/prepare-sfx-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)

        source = root / "Raw Assets/Sound Effects/clip.wav"
        source.write_bytes(b"fixture audio")
        (root / "SoundManifest/sfx.tsv").write_text(
            "# id\tswift_symbol\tasset_name\tsource_path\tvolume_gain\n"
            "test_clip\ttestClip\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
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

    def run_sfx_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(root / "Scripts/prepare-sfx-assets.sh")],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def make_music_fixture(self, directory: str) -> tuple[Path, dict[str, str], Path]:
        root = Path(directory)
        for relative in (
            "Scripts/lib",
            "MusicManifest",
            "Raw Assets/Music",
            "Trinket/Media/Music",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)

        for relative in ("Scripts/prepare-music-assets.sh", "Scripts/lib/media-assets.sh"):
            destination = root / relative
            destination.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8")
            destination.chmod(0o755)

        source = root / "Raw Assets/Music/track.mp3"
        source.write_bytes(b"fixture music")
        (root / "MusicManifest/music.tsv").write_text(
            "# kind\tid\tasset_name\tsource_path\tboss_enemy_id\tlooping\tvolume_gain\n"
            "menu\ttest_track\tmusic_test_track\tRaw Assets/Music/track.mp3\tnone\ttrue\t1.0\n",
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

    def run_music_fixture(
        self, root: Path, environment: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "Scripts/prepare-music-assets.sh"],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

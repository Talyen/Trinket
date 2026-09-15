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
sys.path.insert(0, str(ROOT / "Scripts"))


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "Scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class ScriptRegressionTestCase(unittest.TestCase):

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

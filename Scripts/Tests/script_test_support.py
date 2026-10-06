#!/usr/bin/env python3

"""Shared fixtures for script regression modules."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
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

    def verification_environment(self, *, hosted: bool = False) -> dict[str, str]:
        """Select a policy for dry runs or stubbed fixtures, independent of the test host."""
        environment = {key: value for key, value in os.environ.items()
                       if key not in {'CI', 'GITHUB_ACTIONS', 'TRINKET_ALLOW_HEAVY_LOCAL'}}
        if hosted:
            environment.update(CI='true', GITHUB_ACTIONS='true')
        return environment

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
            if relative.endswith('.sh') and 'source Scripts/lib/verification-policy.sh' in target.read_text():
                policy = root / 'Scripts/lib/verification-policy.sh'
                policy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / 'Scripts/lib/verification-policy.sh', policy)
        # Copy the retention substrate when a fixture includes a direct consumer.
        if any('output_retention' in p.read_text() or 'output-retention.sh' in p.read_text()
               or 'cleanup-outputs.py' in p.read_text()
               for p in (root / 'Scripts').rglob('*') if p.is_file() and p.suffix in {'.py', '.sh'}):
            for relative in ('Scripts/cleanup-outputs.py', 'Scripts/internal/output_retention.py',
                             'Scripts/internal/cli.py', 'Scripts/lib/output-retention.sh', 'Scripts/lib/lock.sh'):
                target = root / relative
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / relative, target)
        return root

    _AUDIO_FIXTURES = {
        "sfx": (
            "SoundManifest/sfx.tsv", "Raw Assets/Sound Effects/clip.wav", "Trinket/Media/SFX",
            "# id\tswift_symbol\tasset_name\tsource_path\tvolume_gain\n"
            "test_clip\ttestClip\tsfx_test_clip\tRaw Assets/Sound Effects/clip.wav\t1.0\n",
            b"fixture audio",
        ),
        "music": (
            "MusicManifest/music.tsv", "Raw Assets/Music/track.mp3", "Trinket/Media/Music",
            "# kind\tid\tasset_name\tsource_path\tboss_enemy_id\tlooping\tvolume_gain\n"
            "menu\ttest_track\tmusic_test_track\tRaw Assets/Music/track.mp3\tnone\ttrue\t1.0\n",
            b"fixture music",
        ),
    }

    def make_audio_fixture(self, directory: str, kind: str) -> tuple[Path, dict[str, str], Path]:
        manifest, source, media, row, audio = self._AUDIO_FIXTURES[kind]
        root = self.make_repo_fixture(directory, ("Scripts/prepare-audio-assets.sh", "Scripts/lib/media-assets.sh"))
        for relative in (Path(manifest).parent, Path(source).parent, media,
                         "Packages/TrinketContent/Sources/TrinketContent/Generated", "bin"):
            (root / relative).mkdir(parents=True, exist_ok=True)
        (root / source).write_bytes(audio)
        (root / manifest).write_text(row, encoding="utf-8")
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

    def run_audio_fixture(
        self, root: Path, environment: dict[str, str], kind: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "Scripts/prepare-audio-assets.sh", kind],
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
        root = self.make_repo_fixture(directory, ("Scripts/prepare-cinematic-assets.sh", "Scripts/lib/media-assets.sh"))
        for relative in (
            "CinematicManifest",
            "ContentManifest",
            "Raw Assets/Animations",
            "Trinket/Media/Cinematics",
            "Packages/TrinketContent/Sources/TrinketContent/Generated",
            "bin",
        ):
            (root / relative).mkdir(parents=True, exist_ok=True)
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

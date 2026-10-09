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

from internal.cli import load_sibling as load_script


def fake_toolchain(root):
    """Provide stable identities without requiring Xcode or a Git checkout."""
    tools = root / 'fake-tools'
    tools.mkdir()
    for name, body in {
        'xcodebuild': 'echo "${FAKE_XCODE:-Xcode fixture A}"',
        'xcrun': 'echo "${FAKE_SDK:-SDK fixture A}"',
        'git': 'if [ "$1" = rev-parse ]; then echo "${FAKE_COMMIT:-commit-a}"; fi',
    }.items():
        executable = tools / name
        executable.write_text('#!/bin/sh\n' + body + '\n')
        executable.chmod(0o755)
    # Apple's /usr/bin/python3 shim consults DEVELOPER_DIR before executing;
    # fixtures must launch the real interpreter even for a synthetic Xcode bundle.
    (tools / 'python3').symlink_to(Path(sys.executable).resolve())
    environment = {**os.environ, 'PATH': f'{tools}:{os.environ["PATH"]}',
                   'CI': '', 'GITHUB_ACTIONS': ''}
    environment.pop('DEVELOPER_DIR', None)
    return environment


class ScriptRegressionTestCase(unittest.TestCase):

    def verification_environment(self, *, hosted: bool = False, **changes: str) -> dict[str, str]:
        """Select a policy for dry runs or stubbed fixtures, independent of the test host."""
        environment = {key: value for key, value in os.environ.items()
                       if key not in {'CI', 'GITHUB_ACTIONS', 'TRINKET_ALLOW_HEAVY_LOCAL'}}
        if hosted:
            environment.update(CI='true', GITHUB_ACTIONS='true')
        return {**environment, **changes}

    def make_repo_fixture(self, directory: str, files: Iterable[str]) -> Path:
        """Create an isolated repo root holding copies of repository files.

        `files` are repository-relative paths (e.g. "Scripts/build-freshness.sh");
        parent directories are created. Returns the root. Callers add any
        synthetic files (stubs, manifests) on top.
        """
        root = Path(directory)
        files = tuple(files)
        if set(files) & {'Scripts/handoff.sh', 'Scripts/agent-context.sh', 'Scripts/agent-push-gate.sh', 'Scripts/change-budget.sh'}:
            files = tuple(dict.fromkeys((*files, 'Scripts/verify.py', 'Scripts/agent-brief.py',
                'Scripts/internal/change_routing.py', 'Scripts/internal/ui_registration.py',
                'Scripts/internal/agent_status.py',
                'Scripts/internal/agent_tasks.py', 'Scripts/internal/agent_arguments.py',
                'Scripts/internal/markdown.py', 'Scripts/internal/cli.py',
                'Scripts/internal/output_retention.py', 'Scripts/build-inputs.env',
                'Scripts/config/ui-tests.tsv', 'Scripts/config/cheap-slices.txt')))
        for relative in files:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
            if relative.endswith('.sh') and 'source Scripts/lib/verification-policy.sh' in target.read_text():
                policy = root / 'Scripts/lib/verification-policy.sh'
                policy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / 'Scripts/lib/verification-policy.sh', policy)
        if any(relative.startswith("Scripts/prepare-") and "assets" in relative or relative == "Scripts/prepare-app-icon.sh" for relative in files):
            helper = root / "Scripts/asset-library.py"
            helper.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "Scripts/asset-library.py", helper)
            from unittest.mock import patch
            environment_patch = patch.dict(os.environ, {"ASSET_LIBRARY_ROOT": str(root)})
            environment_patch.start()
            self.addCleanup(environment_patch.stop)
            if "Scripts/prepare-app-icon.sh" in files:
                manifest = root / "ArtManifest/app-icon.tsv"
                manifest.parent.mkdir(parents=True, exist_ok=True)
                manifest.write_text("# asset_name\tsource_path\nAppIcon.icon\tRaw Assets/App Icon/Trinket App Icon.icon\n")
        # Copy the retention substrate when a fixture includes a direct consumer.
        sources = (p.read_text() for p in (root / 'Scripts').rglob('*')
                   if p.is_file() and p.suffix in {'.py', '.sh'})
        if any(marker in source for source in sources
               for marker in ('output_retention', 'output-retention.sh', 'cleanup-outputs.py')):
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

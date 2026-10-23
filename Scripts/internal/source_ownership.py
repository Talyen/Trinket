"""Authored package, generation-input, and generated-output ownership facts."""
from pathlib import Path

from internal.cli import read_env_arrays


def build_inputs(scripts: Path) -> dict[str, tuple[str, ...]]:
    return read_env_arrays(scripts / 'build-inputs.env', [
        'TRINKET_TEST_PACKAGES', 'TRINKET_CONTENT_GENERATION_INPUTS',
        'TRINKET_ASSET_GENERATION_INPUTS', 'TRINKET_PROJECT_GENERATION_INPUTS',
    ])


def generated_paths(scripts: Path, kinds: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(entry.rstrip('/') for line in (scripts / 'config/generated-paths.tsv').read_text().splitlines()
                 for kind, separator, entry in [line.partition('|')] if separator and kind in kinds and entry)

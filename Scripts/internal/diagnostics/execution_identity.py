"""Bind transferred execution evidence to its hosted run and selected toolchain."""
from __future__ import annotations

import os
import re


def execution_identity(commit: str | None) -> dict:
    return {'commit': commit, **{key: os.environ.get(key, '') for key in (
        'GITHUB_REPOSITORY', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'XCODE_VERSION', 'XCODE_BUILD')}}


def require_hosted_identity(identity: dict) -> None:
    patterns = {'commit': r'[0-9a-f]{40}', 'GITHUB_REPOSITORY': r'[^/\s]+/[^/\s]+',
                'GITHUB_RUN_ID': r'[1-9][0-9]*', 'GITHUB_RUN_ATTEMPT': r'[1-9][0-9]*',
                'XCODE_VERSION': r'\d+(?:\.\d+)*', 'XCODE_BUILD': r'\d+[A-Z]\d+[a-z]?'}
    if (not isinstance(identity, dict) or set(identity) != set(patterns)
            or any(not isinstance(identity.get(key), str) or not re.fullmatch(pattern, identity[key])
                   for key, pattern in patterns.items())):
        raise ValueError('Transferred parity evidence requires complete hosted execution identity')

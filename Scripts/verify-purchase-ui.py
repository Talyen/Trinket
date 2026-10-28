#!/usr/bin/env python3
"""Run every purchase recovery test with fresh, qualified simulator evidence."""
from __future__ import annotations

import os
from pathlib import Path

from internal.cli import load_sibling

DEPLOY = load_sibling('purchase_deploy_verification', 'deploy-verification.py')


def main() -> None:
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Purchase qualification is restricted to GitHub Actions.')
    commit = DEPLOY.capture('git', 'rev-parse', 'HEAD')
    if not os.environ.get('GITHUB_SHA') or commit != os.environ['GITHUB_SHA']:
        raise ValueError('Purchase qualification requires the exact workflow revision.')
    profile = DEPLOY.profile()
    if profile != DEPLOY.QUALIFIED_PROFILE:
        raise ValueError(f'Purchase qualification requires {DEPLOY.QUALIFIED_PROFILE}; found {profile}.')
    identity = dict(build=DEPLOY.BUILD.identity(), profile=profile, root=str(DEPLOY.ROOT))
    if identity['build'].get('commit') != commit:
        raise ValueError('Build identity does not match the workflow revision.')
    # No state or input cache: each requested run must prove every method afresh.
    verification = DEPLOY.Verification(Path('.DerivedData/purchase-ui-unused.json'), identity, False)
    verification.ui_batch('ui', ['FullGamePurchaseUITests'])
    print('All purchase recovery cases passed on the qualified runtime.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, DEPLOY.subprocess.SubprocessError) as error:
        raise SystemExit(f'Purchase qualification stopped: {error}')

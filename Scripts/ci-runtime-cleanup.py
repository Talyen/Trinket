#!/usr/bin/env python3
"""Release iOS image space only on a disposable hosted compatibility runner."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
from uuid import UUID


def deletion_candidates(images: dict) -> list[str]:
    if not isinstance(images, dict):
        raise ValueError('Runtime image inventory is not an object')
    candidates = []
    for identifier, image in images.items():
        if (not isinstance(identifier, str) or str(UUID(identifier)).lower() != identifier.lower()
                or not isinstance(image, dict) or image.get('identifier') != identifier
                or not isinstance(image.get('platformIdentifier'), str)
                or not isinstance(image.get('state'), str) or not image['state']):
            raise ValueError('Incomplete runtime image inventory; refusing cleanup')
        # Busy images may omit deletion eligibility. Never interrupt their owner.
        if image['state'] != 'Ready':
            continue
        if type(image.get('deletable')) is not bool:
            raise ValueError('Missing runtime deletion eligibility; refusing cleanup')
        if image['deletable'] and image['platformIdentifier'] == 'com.apple.platform.iphonesimulator':
            candidates.append(identifier)
    return candidates


def cleanup(output: Path, environment: dict) -> None:
    if environment.get('RUNNER_ENVIRONMENT') != 'github-hosted' or environment.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Runtime cleanup requires a disposable GitHub-hosted runner')
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'status': 'incomplete', 'inventory_attempts': [], 'deleted': []}
    try:
        for limit in (10, 30):
            try:
                raw = subprocess.check_output(['xcrun', 'simctl', 'runtime', 'list', '-j'], text=True, timeout=limit)
                receipt['inventory_attempts'].append({'limit_seconds': limit, 'status': 'passed'})
                break
            except subprocess.TimeoutExpired:
                receipt['inventory_attempts'].append({'limit_seconds': limit, 'status': 'timeout'})
                if limit == 30:
                    raise
                print('Runtime image inventory timed out after 10s; retrying once with a 30s limit.', file=sys.stderr)
        images = json.loads(raw)
        (output / 'runtime-images.json').write_text(json.dumps(images) + '\n')
        receipt['selected'] = deletion_candidates(images)
        for identifier in receipt['selected']:
            # Deletion is not retried: a changed/busy image fails visibly.
            subprocess.run(['xcrun', 'simctl', 'runtime', 'delete', identifier], check=True, timeout=180)
            receipt['deleted'].append(identifier)
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        (output / 'runtime-cleanup.json').write_text(json.dumps(receipt) + '\n')


if __name__ == '__main__':
    try:
        cleanup(Path('.DerivedData/PlayerCoverage'), dict(os.environ))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f'[coverage prerequisite] Runtime image cleanup refused: {error}')

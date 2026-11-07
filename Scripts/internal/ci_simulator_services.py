"""Initialize the selected Xcode's simulator services on disposable CI hosts."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess


def prepare_components(environment):
    if environment.get('GITHUB_ACTIONS') != 'true':
        return
    developer = environment.get('DEVELOPER_DIR')
    if not developer:
        raise ValueError('CI simulator preparation requires an explicitly selected Xcode.')
    status = subprocess.run(['xcodebuild', '-checkFirstLaunchStatus'], env=environment,
                            timeout=30, check=False)
    if status.returncode:
        print('Initializing system components for the selected Xcode.', flush=True)
        subprocess.run(['sudo', 'env', f'DEVELOPER_DIR={developer}', 'xcodebuild', '-runFirstLaunch'],
                       env=environment, timeout=180, check=True)
        subprocess.run(['xcodebuild', '-checkFirstLaunchStatus'], env=environment,
                       timeout=30, check=True)


def start_device_ui(environment=None):
    environment = dict(os.environ) if environment is None else environment
    if environment.get('GITHUB_ACTIONS') != 'true':
        return
    developer = Path(environment['DEVELOPER_DIR'])
    candidates = (developer.parent / 'Applications/DeviceHub.app', developer / 'Applications/Simulator.app')
    application = next((path for path in candidates if path.is_dir()), None)
    if application is None:
        raise ValueError(f'The selected Xcode has no device UI: {developer}')
    # Keep a client of this Xcode's device services alive after provisioning.
    # SDK discovery and a completed boot alone do not establish that lifecycle.
    subprocess.run(['open', '-g', '-j', '-a', str(application)], env=environment,
                   timeout=30, check=True)
    print(f'CI device services: {application}', flush=True)

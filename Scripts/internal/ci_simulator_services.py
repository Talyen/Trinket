"""Initialize the selected Xcode's simulator services on disposable CI hosts."""
from __future__ import annotations

import os
import json
from pathlib import Path
import subprocess
import sys


def recover_runtime_mount(udid, environment=None):
    environment = dict(os.environ) if environment is None else environment
    if environment.get('GITHUB_ACTIONS') != 'true':
        return
    payload = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', udid, '-j'],
                                                env=environment, text=True, timeout=30))
    devices = [device for group in payload['devices'].values() for device in group
               if device.get('udid') == udid]
    if len(devices) != 1:
        raise ValueError('Cannot establish the failed simulator identity for runtime recovery.')
    device = devices[0]
    if device.get('isAvailable') is not False or 'runtime profile not found' not in device.get('availabilityError', ''):
        return
    # A service restart can leave a downloaded image unmounted. Re-register
    # installed images before the caller's existing owned-device boot recovery.
    print(f'Recovering missing CI runtime mount for {udid}: {device["availabilityError"]}',
          file=sys.stderr, flush=True)
    subprocess.run(['xcrun', 'simctl', 'runtime', 'scan-and-mount'], env=environment,
                   timeout=30, check=True, stdout=sys.stderr)


def prepare_components(environment):
    if environment.get('GITHUB_ACTIONS') != 'true':
        return
    developer = environment.get('DEVELOPER_DIR')
    if not developer:
        raise ValueError('CI simulator preparation requires an explicitly selected Xcode.')
    status = subprocess.run(['xcodebuild', '-checkFirstLaunchStatus'], env=environment,
                            timeout=30, check=False, stdout=sys.stderr)
    if status.returncode:
        print('Initializing system components for the selected Xcode.', file=sys.stderr, flush=True)
        subprocess.run(['sudo', 'env', f'DEVELOPER_DIR={developer}', 'xcodebuild', '-runFirstLaunch'],
                       env=environment, timeout=180, check=True, stdout=sys.stderr)
        subprocess.run(['xcodebuild', '-checkFirstLaunchStatus'], env=environment,
                       timeout=30, check=True, stdout=sys.stderr)


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
                   timeout=30, check=True, stdout=sys.stderr)
    print(f'CI device services: {application}', file=sys.stderr, flush=True)

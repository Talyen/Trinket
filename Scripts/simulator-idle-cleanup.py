#!/usr/bin/env python3
"""Opt-in, conservative idle shutdown for human simulator play and its device UI."""

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import time

from internal.cli import ROOT, legacy_runtime_owner, primary_worktree_root, write_json_atomic
from internal.output_retention import process_snapshot, safe_path

LABEL = 'com.trinket.simulator-idle'
UI_EXECUTABLE = re.compile(r'^(.+/(DeviceHub|Simulator)\.app/Contents/MacOS/\2)(?:\s|$)')
UI_IDS = ('com.apple.dt.Devices', 'com.apple.iphonesimulator')
FRONT_IDS = (*UI_IDS, 'com.apple.dt.Xcode')
STATE = Path.home() / '.local/state/trinket-simulator-idle'
BUSY = re.compile(r'(?:^|/)(?:xcodebuild|xctest|simctl|devicectl|swift-frontend|[^/\s]*Tests-Runner)(?:\s|$)')


def command(*args):
    return subprocess.check_output(list(args), text=True, timeout=45).strip()


def foreground():
    value = command('/usr/bin/osascript', '-l', 'JavaScript', '-e',
                    'ObjC.import("AppKit"); ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier)')
    if not value or value == 'undefined':
        raise ValueError('Foreground application unavailable; preserve play')
    return value


def input_idle():
    output = command('/usr/sbin/ioreg', '-c', 'IOHIDSystem', '-r', '-d', '1')
    match = re.search(r'"HIDIdleTime"\s*=\s*(\d+)', output)
    if not match:
        raise ValueError('Input activity unavailable; preserve play')
    return int(match[1]) / 1_000_000_000


def ui_processes(processes):
    return {pid: identity for pid, identity in processes.items()
            if UI_EXECUTABLE.match(identity[1])}


def observe(root, ignored_slot=None):
    processes = process_snapshot()
    ui = ui_processes(processes)
    guests = {pid: identity for pid, identity in processes.items() if identity[1].startswith('launchd_sim ')}
    session = [[pid, value[0]] for pid, value in sorted({**ui, **guests}.items())]
    reason = ''
    if any(BUSY.search(value[1]) or 'XCPreviewAgent' in value[1] for value in processes.values()):
        reason = 'build, test, or device command active'
    if legacy_runtime_owner(root, ('.active-sim', '.active-ui', '.simulator-cleanup.lock')) is not None:
        reason = 'legacy simulator ownership preserved'
    if (root / '.DerivedData/.simulator-cleanup.lock').exists():
        reason = 'simulator hygiene in progress'
    for directory in (root / '.DerivedData/.active-sim', root / '.DerivedData/.active-ui'):
        for path in [*directory.glob('*.slot'), *directory.glob('*.lifetime.json')]:
            if path != ignored_slot:
                reason = 'simulator or inspection reservation preserved'
    if foreground() in FRONT_IDS:
        reason = 'device UI or Xcode in foreground'
    return {'session': session, 'ui': ui, 'guests': guests, 'reason': reason, 'input_idle': input_idle()}


def devices():
    value = json.loads(command('/usr/bin/xcrun', 'simctl', 'list', 'devices', '-j'))
    if not isinstance(value.get('devices'), dict):
        raise ValueError('Simulator inventory unavailable')
    if not all(isinstance(group, list) for group in value['devices'].values()):
        raise ValueError('Invalid simulator inventory')
    result = [device for group in value['devices'].values() for device in group]
    for device in result:
        if not isinstance(device, dict) or not all(isinstance(device.get(key), str) and device[key] for key in ('name', 'udid', 'state')):
            raise ValueError('Incomplete simulator identity; preserve devices')
    return result


@contextmanager
def reserve(root):
    """Exclude both agent allocation and the independently claimed human run slot."""
    directory = root / '.DerivedData/.active-sim'
    if not safe_path(directory, root):
        raise ValueError('Unsafe simulator reservation directory')
    directory.mkdir(parents=True, exist_ok=True)
    lock = directory / '.sim-lifecycle.lock'
    slot = directory / 'run.slot'
    owned_lock = owned_slot = False
    marker = f'{os.getpid()} idle-cleanup\n'
    try:
        try:
            lock.mkdir()
            owned_lock = True
            (lock / 'pid').write_text(str(os.getpid()) + '\n')
            with slot.open('x') as handle:
                handle.write(marker)
            owned_slot = True
        except FileExistsError:
            yield None
            return
        yield slot
    finally:
        if owned_slot and slot.read_text() == marker:
            slot.unlink()
        if owned_lock:
            (lock / 'pid').unlink()
            lock.rmdir()


def shutdown(root, udid):
    # Reuse graceful guest-service teardown and require an observed Shutdown state.
    subprocess.run(['/bin/bash', '-c', 'source Scripts/run-env.sh; trinket_sim_shutdown_wait "$1"', '_', udid],
                   cwd=root, check=True, timeout=60)
    if not any(device['udid'] == udid and device['state'] == 'Shutdown' for device in devices()):
        raise ValueError('Simulator shutdown not confirmed; retain device UI')


def quit_ui(pid, executable):
    app = str(Path(UI_EXECUTABLE.match(executable)[1]).parents[2])
    # NSRunningApplication.terminate is a normal quit request, never a force quit.
    script = '''function run(argv) {
ObjC.import('AppKit');
const front = ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier);
if (!front || ['com.apple.dt.Devices', 'com.apple.iphonesimulator', 'com.apple.dt.Xcode'].includes(front)) return 'preserved';
const app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(Number(argv[0]));
if (!app || !['com.apple.dt.Devices', 'com.apple.iphonesimulator'].includes(ObjC.unwrap(app.bundleIdentifier)) || ObjC.unwrap(app.bundleURL.path) !== argv[1]) return 'preserved';
return app.terminate ? 'requested' : 'declined';
}'''
    return command('/usr/bin/osascript', '-l', 'JavaScript', '-e', script, str(pid), app)


def cleanup(root, previous, *, idle_seconds, apply):
    now = time.time()
    current = observe(root)
    last_active = previous.get('last_active', now)
    if not isinstance(last_active, (int, float)) or not 0 <= last_active <= now:
        last_active = now
    if previous.get('session') != current['session'] or current['reason']:
        last_active = now
    last_active = max(last_active, now - current['input_idle'])
    report = {'checked_at': now, 'session': current['session'], 'last_active': last_active,
              'idle_seconds': idle_seconds, 'state': current['reason'] or 'waiting for idle timeout', 'actions': []}
    if not current['session']:
        report['state'] = 'no simulator or device UI running'
        return report
    if current['reason'] or now - last_active < idle_seconds:
        return report
    report['state'] = 'eligible' if not apply else 'idle cleanup'
    if not apply:
        return report
    with reserve(root) as slot:
        if slot is None:
            report['state'] = 'simulator allocation busy'
            report['last_active'] = now
            return report
        latest = observe(root, slot)
        if latest['reason'] or latest['input_idle'] < idle_seconds or latest['session'] != current['session']:
            report['state'] = latest['reason'] or 'activity changed; preserved'
            report['last_active'] = now
            return report
        inventory = devices()
        human = [device for device in inventory if device['name'] == 'Trinket Run']
        if len(human) > 1:
            raise ValueError('Ambiguous human simulator identity; preserve devices')
        for device in human:
            if device['state'] == 'Booted':
                # Inventory itself may be slow: refresh activity immediately before shutdown.
                latest = observe(root, slot)
                if latest['reason'] or latest['input_idle'] < idle_seconds or latest['session'] != current['session']:
                    report['state'] = latest['reason'] or 'activity changed; preserved'
                    report['last_active'] = now
                    return report
                shutdown(root, device['udid'])
                report['actions'].append({'shutdown': device['udid'], 'name': device['name']})
        # Other projects' devices, agent devices and transitions keep the shared UI alive.
        if any(device['state'] != 'Shutdown' for device in devices()):
            report['state'] = 'other simulator running; device UI preserved'
            return report
        latest = observe(root, slot)
        if latest['guests']:
            report['state'] = 'simulator guest processes remain; device UI preserved'
            return report
        if latest['reason'] or latest['input_idle'] < idle_seconds:
            report['state'] = latest['reason'] or 'input resumed; device UI preserved'
            report['last_active'] = now
            return report
        for pid, identity in current['ui'].items():
            if latest['ui'].get(pid) == identity:
                outcome = quit_ui(pid, identity[1])
                report['actions'].append({'quit_pid': pid, 'result': outcome})
        report['last_active'] = now
    return report


def install(root, idle_seconds, uninstall=False):
    service = f'gui/{os.getuid()}/{LABEL}'
    path = Path.home() / 'Library/LaunchAgents' / f'{LABEL}.plist'
    subprocess.run(['/bin/launchctl', 'bootout', service], capture_output=True, check=False)
    if uninstall:
        path.unlink(missing_ok=True)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    value = {'Label': LABEL, 'ProgramArguments': ['/usr/bin/python3', str(root / 'Scripts/simulator-idle-cleanup.py'),
             '--apply', '--idle-seconds', str(idle_seconds)], 'StartInterval': 60, 'RunAtLoad': True,
             'ProcessType': 'Background', 'Nice': 10, 'LowPriorityIO': True,
             'StandardOutPath': '/dev/null', 'StandardErrorPath': '/dev/null'}
    path.write_bytes(plistlib.dumps(value))
    path.chmod(0o600)
    subprocess.run(['/bin/launchctl', 'enable', service], check=True)
    subprocess.run(['/bin/launchctl', 'bootstrap', f'gui/{os.getuid()}', str(path)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true', help='read-only current eligibility')
    mode.add_argument('--apply', action='store_true', help='record activity and perform eligible cleanup')
    mode.add_argument('--install', action='store_true', help='enable once-per-minute cleanup at login')
    mode.add_argument('--uninstall', action='store_true', help='disable cleanup without changing any device')
    mode.add_argument('--status', action='store_true', help='show the most recent bounded status record')
    parser.add_argument('--idle-seconds', type=int, default=600)
    args = parser.parse_args()
    if not 1 <= args.idle_seconds <= 86400:
        parser.error('idle-seconds must be between 1 and 86400')
    root = primary_worktree_root(ROOT)
    if args.install or args.uninstall:
        install(root, args.idle_seconds, args.uninstall)
        print('Idle cleanup disabled.' if args.uninstall else f'Idle cleanup enabled after {args.idle_seconds} seconds.')
        return
    path = STATE / 'status.json'
    if args.status:
        print(path.read_text() if path.exists() else '{}')
        return
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'run.lock').open('a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            previous = json.loads(path.read_text()) if path.exists() else {}
            if not isinstance(previous, dict):
                raise ValueError('Invalid idle history; restart the idle interval')
            report = cleanup(root, previous, idle_seconds=args.idle_seconds, apply=args.apply)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            report = {'checked_at': time.time(), 'last_active': time.time(), 'state': f'preserved: {error}', 'actions': []}
        if args.apply:
            write_json_atomic(path, report)
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()

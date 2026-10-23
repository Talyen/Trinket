"""One inspection command loop owns capture and optional native Xcode interaction."""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

from .cli import primary_worktree_root, write_json_atomic


class Bridge:
    def __init__(self):
        self.process = subprocess.Popen(['xcrun', 'mcpbridge'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=sys.stderr, bufsize=0)
        self.sequence = 0
        self.buffer = b''
        try:
            self.request('initialize', {'protocolVersion': '2024-11-05', 'capabilities': {},
                                       'clientInfo': {'name': 'Trinket Inspection', 'version': '1'}}, timeout=15)
            self.send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
            self.tools = self.request('tools/list', {}, timeout=15)['tools']
        except BaseException:
            self.close()
            raise

    def send(self, message):
        self.process.stdin.write(json.dumps(message).encode() + b'\n')
        self.process.stdin.flush()

    def request(self, method, params, *, timeout=180):
        self.sequence += 1
        self.send({'jsonrpc': '2.0', 'id': self.sequence, 'method': method, 'params': params})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if b'\n' not in self.buffer:
                ready, _, _ = select.select([self.process.stdout], [], [], max(0, deadline - time.monotonic()))
                if not ready:
                    break
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise ValueError('Xcode inspection bridge disconnected')
                self.buffer += chunk
                continue
            line, self.buffer = self.buffer.split(b'\n', 1)
            response = json.loads(line)
            if response.get('id') != self.sequence:
                continue
            if 'error' in response:
                raise ValueError(str(response['error']))
            return response['result']
        raise ValueError(f'Xcode inspection timed out during {method}; do not create a replacement session')

    def tool(self, name, arguments, *, timeout=180):
        metadata = next((tool for tool in self.tools if tool['name'] == name), None)
        if metadata is None:
            raise ValueError(f'Xcode does not expose {name}; use Computer Use')
        schema = metadata.get('inputSchema', {})
        if not set(schema.get('required', [])) <= arguments.keys() or not arguments.keys() <= schema.get('properties', {}).keys():
            raise ValueError(f'{name} metadata changed; inspect the current Xcode tool contract')
        result = self.request('tools/call', {'name': name, 'arguments': arguments}, timeout=timeout)
        if result.get('isError'):
            raise ValueError(str(result.get('content', 'Xcode interaction failed')))
        if result.get('structuredContent'):
            return result['structuredContent']
        for item in result.get('content', []):
            if item.get('type') == 'text':
                try:
                    return json.loads(item['text'])
                except ValueError:
                    pass
        raise ValueError(f'{name} returned no structured result')

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)


class Inspection:
    def __init__(self, udid, name, app, revision, ui):
        self.udid, self.name, self.app, self.revision, self.ui = udid, name, Path(app), revision, ui
        with (self.app / 'Info.plist').open('rb') as stream:
            self.product = plistlib.load(stream)
        self.directory = Path('.DerivedData/Deliverables/Inspection')
        self.directory.mkdir(parents=True, exist_ok=True)
        self.bridge = None
        self.key = None
        self.native_attempted = False
        self.native_ready = False
        self.recovery = self.directory / 'native-session.json'
        self.reservation = primary_worktree_root(Path.cwd()) / '.DerivedData/InspectionSessions' / (udid + '.json')
        self.reservation_owned = False

    def status(self):
        print(json.dumps({'simulator_udid': self.udid, 'simulator_name': self.name,
            'bundle_id': self.product['CFBundleIdentifier'], 'device_ui': self.ui,
            'capture': 'simctl screenshot', 'native': 'active' if self.key else 'lazy; type native to discover Xcode capabilities',
            'computer_use': 'available through the chat when exposed; confirm the selected device',
            'commands': ['status', 'capture', 'native', 'event <documented Xcode interaction command>', 'stop']}), flush=True)

    def save(self, native=None):
        directory = Path(tempfile.mkdtemp(prefix='capture.', dir=self.directory))
        if native:
            for key, filename in [('screenshotPath', 'screen.png'), ('hierarchyPath', 'hierarchy.txt')]:
                if native.get(key):
                    shutil.copy2(native[key], directory / filename)
        else:
            subprocess.run(['xcrun', 'simctl', 'io', self.udid, 'screenshot', str(directory / 'screen.png'),
                            '--type=png', '--mask=ignored'], check=True, timeout=30)
        metadata = {'captured_at': datetime.now(timezone.utc).isoformat(), 'simulator_udid': self.udid,
            'simulator_name': self.name, 'product_path': str(self.app), 'bundle_id': self.product['CFBundleIdentifier'],
            'product_version': self.product.get('CFBundleShortVersionString'), 'product_build': self.product.get('CFBundleVersion'),
            'checkout_revision_at_launch': self.revision or None, 'native': native,
            'evidence_limit': 'Inspect the image and record screen/state and build provenance; capture alone is not visual review.'}
        (directory / 'capture.json').write_text(json.dumps(metadata, indent=2) + '\n')
        if not (directory / 'screen.png').is_file():
            raise ValueError(f'Native capture returned no screenshot; inspect {directory / "capture.json"}')
        print(f'Capture saved: {directory.resolve() / "screen.png"}', flush=True)

    def native(self, command=None):
        if not self.bridge:
            if self.native_attempted or self.recovery.exists():
                raise ValueError('Previous native session needs recovery; use Computer Use without creating a replacement')
            self.native_attempted = True
            self.bridge = Bridge()
            names = {tool['name'] for tool in self.bridge.tools}
            print('Native Xcode capabilities: ' + ', '.join(sorted(name for name in names if name.startswith('DeviceInteraction'))), flush=True)
            required = {'DeviceInteractionStartSession', 'DeviceInteractionSynthesize', 'DeviceInteractionEndSession'}
            if not required <= names:
                raise ValueError('Native inspection tools unavailable; use Computer Use')
            # Persist uncertainty before dispatch so interrupted starts cannot be silently replaced.
            self.reservation.parent.mkdir(parents=True, exist_ok=True)
            starting = {'device': self.udid, 'state': 'starting; inspect Xcode if interrupted', 'recovery': str(self.recovery.resolve())}
            with self.reservation.open('x') as stream:
                self.reservation_owned = True
                self.reservation.chmod(0o600)
                json.dump(starting, stream)
            write_json_atomic(self.recovery, starting)
            result = self.bridge.tool('DeviceInteractionStartSession',
                                     {'deviceIdentifier': self.udid, 'sessionIdentifier': 'Trinket Inspection ' + uuid.uuid4().hex[:8]})
            self.key = result['interactionSessionKey']
            record = {**starting, 'state': 'active', 'interactionSessionKey': self.key}
            write_json_atomic(self.recovery, record)
            write_json_atomic(self.reservation, record)
            if result.get('deviceUUID', '').lower() != self.udid.lower() or not result.get('deviceIsSimulator'):
                self.close()
                raise ValueError('Xcode selected a different device; native inspection stopped')
            self.native_ready = True
        if not self.native_ready:
            raise ValueError('Native initialization failed; use Computer Use or stop and inspect the reported prerequisite')
        result = self.bridge.tool('DeviceInteractionSynthesize', {'interactSessionKey': self.key,
            'activationBundleId': self.product['CFBundleIdentifier'], **({'interactionCommand': command} if command else {})})
        self.save(result)

    def close(self):
        self.native_ready = False
        try:
            if self.key:
                self.bridge.tool('DeviceInteractionEndSession', {'interactionSessionKey': self.key}, timeout=30)
                self.recovery.unlink()
                if self.reservation_owned:
                    self.reservation.unlink()
                    self.reservation_owned = False
                self.key = None
                print('Native interaction session closed.', flush=True)
            elif self.reservation_owned or self.recovery.exists():
                raise ValueError(f'Native start was uncertain; inspect Xcode and {self.recovery} before another session')
        finally:
            if self.bridge:
                self.bridge.close()


def main(argv=None):
    session = Inspection(*(sys.argv[1:] if argv is None else argv))
    def interrupted(signum, frame):
        for number in (signal.SIGINT, signal.SIGTERM):
            signal.signal(number, signal.SIG_IGN)
        raise KeyboardInterrupt
    previous_signals = {number: signal.signal(number, interrupted) for number in (signal.SIGINT, signal.SIGTERM)}
    try:
        session.status()
        for line in sys.stdin:
            command = line.strip()
            if command == 'stop':
                break
            try:
                if command == 'capture': session.save()
                elif command == 'status': session.status()
                elif command == 'native': session.native()
                elif command.startswith('event '): session.native(command[6:])
                else: print('Commands: status, capture, native, event <Xcode command>, stop', flush=True)
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                message = f'Capture failed for leased simulator {session.udid}; inspection remains active' if command == 'capture' else 'Inspection command failed'
                print(f'{message}: {error}', file=sys.stderr, flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        for number in previous_signals:
            signal.signal(number, signal.SIG_IGN)
        try:
            session.close()
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f'Native cleanup unconfirmed: {error}', file=sys.stderr, flush=True)
            return 2
        finally:
            for number, handler in previous_signals.items():
                signal.signal(number, handler)
    return 0

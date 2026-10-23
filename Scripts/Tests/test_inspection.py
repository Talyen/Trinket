"""Exercise managed inspection ownership without starting a simulator or Xcode."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from internal.inspection import Inspection, Bridge, main


class InspectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        app = self.root / 'Trinket.app'
        app.mkdir()
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'fixture.trinket'}))
        self.app = app

    def session(self):
        # Use a fixture deliverables directory without changing the process cwd.
        with patch.object(Path, 'mkdir'):
            session = Inspection('owned-device', 'Trinket Agent Fixture', str(self.app), 'revision', 'DeviceHub.app')
        session.directory = self.root / 'evidence'
        session.directory.mkdir()
        session.recovery = session.directory / 'native-session.json'
        session.reservation = self.root / 'shared-native-session.json'
        return session

    def bridge(self, device='owned-device', fail_close=False):
        class FakeBridge:
            def __init__(self):
                self.tools = [{'name': name} for name in ('DeviceInteractionStartSession', 'DeviceInteractionSynthesize', 'DeviceInteractionEndSession')]
                self.calls = []
                self.closed = False
            def tool(self, name, args, **kwargs):
                self.calls.append((name, args))
                if name == 'DeviceInteractionStartSession':
                    return {'interactionSessionKey': 'owned-key', 'deviceUUID': device, 'deviceIsSimulator': True}
                if name == 'DeviceInteractionEndSession' and fail_close:
                    raise ValueError('close uncertain')
                return {'applicationState': 'Running'}
            def close(self): self.closed = True
        return FakeBridge()

    def test_one_session_supplies_device_identity_and_closes_before_owner_returns(self):
        session = self.session()
        bridge = self.bridge()
        with patch('internal.inspection.Bridge', return_value=bridge), patch.object(session, 'save') as save:
            session.native()
            session.native('t 10 20')
            self.assertEqual([name for name, _ in bridge.calls].count('DeviceInteractionStartSession'), 1)
            self.assertEqual(bridge.calls[0][1]['deviceIdentifier'], 'owned-device')
            self.assertEqual(bridge.calls[-1][1], {'interactSessionKey': 'owned-key', 'activationBundleId': 'fixture.trinket', 'interactionCommand': 't 10 20'})
            self.assertEqual(save.call_count, 2)
            session.close()
        self.assertTrue(bridge.closed)
        self.assertFalse(session.recovery.exists())
        self.assertFalse(session.reservation.exists())
        self.assertEqual(bridge.calls[-1][0], 'DeviceInteractionEndSession')

    def test_wrong_device_is_closed_without_input_and_failed_close_retains_recovery(self):
        for wrong, fail_close in ((True, False), (False, True)):
            session = self.session()
            bridge = self.bridge(device='foreign-device' if wrong else 'owned-device', fail_close=fail_close)
            with patch('internal.inspection.Bridge', return_value=bridge), patch.object(session, 'save'):
                if wrong:
                    with self.assertRaises(ValueError): session.native()
                    self.assertFalse(any(name == 'DeviceInteractionSynthesize' for name, _ in bridge.calls))
                else:
                    session.native()
                    with self.assertRaises(ValueError): session.close()
                    self.assertTrue(session.recovery.exists())
            self.assertTrue(bridge.closed)
            # Separate fixture directories for the next scenario.
            session.directory.rename(self.root / ('wrong' if wrong else 'failed'))

    def test_shared_uncertain_session_blocks_replacement_before_native_start(self):
        session = self.session()
        session.reservation.write_text('uncertain native session from another checkout')
        bridge = self.bridge()
        with patch('internal.inspection.Bridge', return_value=bridge):
            with self.assertRaises(FileExistsError): session.native()
            self.assertEqual(bridge.calls, [])
            session.close()
        self.assertEqual(session.reservation.read_text(), 'uncertain native session from another checkout')

    def test_eof_and_cancellation_close_native_owner(self):
        class CancelledInput:
            def __iter__(self): raise KeyboardInterrupt
        for index, input_value in enumerate((io.StringIO(''), io.StringIO('stop\n'), CancelledInput())):
            session = self.session()
            with patch('internal.inspection.Inspection', return_value=session), patch.object(session, 'close') as close, \
                 patch('sys.stdin', input_value), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(['device', 'name', str(self.app), 'rev', 'ui']), 0)
                close.assert_called_once()
            session.directory.rename(self.root / f'closed-{index}')

    def test_bridge_validates_tool_metadata_before_dispatch(self):
        bridge = Bridge.__new__(Bridge)
        bridge.tools = [{'name': 'DeviceInteractionSynthesize', 'inputSchema': {
            'required': ['interactSessionKey'], 'properties': {'interactSessionKey': {}}}}]
        with patch.object(bridge, 'request') as request:
            with self.assertRaises(ValueError): bridge.tool('DeviceInteractionSynthesize', {'wrongKey': 'key'})
            with self.assertRaises(ValueError): bridge.tool('MissingTool', {})
            request.assert_not_called()

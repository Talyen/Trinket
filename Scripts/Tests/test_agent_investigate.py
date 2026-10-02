from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-investigate.py',
    'Scripts/agent-search.py',
    'Scripts/internal/agent_callers.py',
    'Scripts/internal/agent_tasks.py',
    'Scripts/internal/source_declarations.py',
    'Scripts/internal/swift_policy.py',
    'Scripts/config/agent-tasks.json',
    'Scripts/config/generated-paths.tsv',
)

import contextlib
import io
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import load_script

INVESTIGATE = load_script('agent_investigation', 'agent-investigate.py')


class AgentInvestigationTests(unittest.TestCase):
    def fixture(self, root):
        for directory in ('Sources', 'Tests', 'Other', 'Scripts/config'):
            (root / directory).mkdir(parents=True)
        (root / 'Scripts/config/generated-paths.tsv').write_text('source|Sources/Generated\n')
        (root / 'Sources/Owner.py').write_text('class Owner:\n    # Retain caller context\n    def target(self):\n        return 42\n    def call(self):\n        return self.target()\n')
        (root / 'Sources/Generated').mkdir()
        (root / 'Sources/Generated/Hidden.py').write_text('target()\n')
        (root / 'Tests/test_owner.py').write_text('def test_result():\n    result = target()\n    assert result == 42\n\ndef test_state():\n    assert state == "saved"\n')
        (root / 'Other/unrelated.py').write_text('target()\n')
        subprocess.run(['git', 'init', '-q', str(root)], check=True)

    def run_bundle(self, root, *extra):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            status = INVESTIGATE.main(['--path', 'Sources/Owner.py', '--symbol', 'Owner.target',
                                       '--scope', 'Sources', '--scope', 'Tests', *extra], root=root)
        self.assertEqual(status, 0)
        return output.getvalue()

    def test_complete_bodies_include_assertions_exclude_generated_and_unscoped_calls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            text = self.run_bundle(root, '--test', 'Tests/test_owner.py#test_state')
            self.assertIn('return 42', text)
            self.assertIn('Enclosing context (signature only): Owner', text)
            self.assertIn('Owner.call', text)
            self.assertIn('assert result == 42', text)
            self.assertIn('assert state == "saved"', text)
            self.assertNotIn('Hidden.py', text)
            self.assertNotIn('unrelated.py', text)
            self.assertIn('not coverage proof', text)
            self.assertIn('omitted 0', text)

    def test_bounds_continue_without_duplicates_and_reject_changed_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            first = self.run_bundle(root, '--limit', '1', '--max-lines', '1')
            self.assertIn('Body omitted (line budget)', first)
            self.assertNotIn('return 42', first)
            self.assertIn('omitted 1 after this page', first)
            retry = shlex.split(next(line.removeprefix('Continue: ') for line in first.splitlines() if line.startswith('Continue: ')))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(INVESTIGATE.main(retry[2:], root=root), 0)
            self.assertIn('Test invocation', output.getvalue())
            self.assertNotIn('Owner.call', output.getvalue())
            path = root / 'Tests/test_owner.py'
            path.write_text(path.read_text().replace('42', '43'))
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                INVESTIGATE.main(retry[2:], root=root)
            self.assertEqual(error.exception.code, 2)

    def test_ambiguity_invalid_scopes_and_generated_targets_fail_without_body_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            path = root / 'Sources/Owner.py'
            path.write_text(path.read_text() + '\nclass Another:\n    def target(self):\n        return "ambiguous"\n')
            for extra in (['--symbol', 'target'], ['--scope', 'missing'],
                          ['--path', 'Sources/Generated/Hidden.py'], ['--test', 'Other/unrelated.py#target']):
                with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                    self.run_bundle(root, *extra)
                self.assertEqual(error.exception.code, 2)
                self.assertEqual(output.getvalue(), '')


if __name__ == '__main__':
    unittest.main()

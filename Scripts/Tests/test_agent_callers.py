from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-search.py',
    'Scripts/internal/agent_callers.py',
    'Scripts/internal/source_declarations.py',
    'Scripts/internal/swift_policy.py',
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

CALLERS = load_script('caller_navigation', 'internal/agent_callers.py')
SEARCH = load_script('caller_search', 'agent-search.py')


class AgentCallerTests(unittest.TestCase):
    def test_python_calls_exclude_literals_comments_definitions_and_keep_enclosing_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'Probe.py'
            path.write_text('def target(): pass\nclass Owner:\n    def act(self):\n        # target()\n        label = "target()"\n        target()\n        self.target()\n')
            rows = CALLERS.caller_rows(root, ['Probe.py'], 'target')
            self.assertEqual(len(rows), 2)
            self.assertTrue(all('Owner.act [3:7]' in row for row in rows))
            config = root / 'Scripts/config/generated-paths.tsv'
            config.parent.mkdir(parents=True)
            config.write_text('')
            subprocess.run(['git', 'init', '-q'], cwd=root, check=True)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(SEARCH.main(['target', '--callers', '--limit', '1'], root=root), 0)
            command = shlex.split(next(line.removeprefix('Continue: ') for line in output.getvalue().splitlines() if line.startswith('Continue: ')))
            self.assertIn('--callers', command)
            with contextlib.redirect_stdout(io.StringIO()) as continuation:
                self.assertEqual(SEARCH.main(command[2:], root=root), 0)
            self.assertIn('Probe.py:7', continuation.getvalue())
            self.assertNotIn('Probe.py:6', continuation.getvalue())
            path.write_text(path.read_text() + '\ntarget()\n')
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(SEARCH.main(command[2:], root=root), 2)

    def test_swift_calls_ignore_nested_comments_strings_and_function_declarations(self):
        source = '''struct Owner {
    func target() {}
    func act() {
        // target()
        /* nested /* target() */ target() */
        let text = "target()"
        target()
        self.target(
        )
        otherTarget()
    }
}
'''
        self.assertEqual(CALLERS.invocation_lines(Path('Probe.swift'), source, 'target'), [7, 8])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Probe.swift').write_text(source)
            self.assertTrue(all('Owner.act' in row for row in CALLERS.caller_rows(root, ['Probe.swift'], 'target')))


if __name__ == '__main__':
    unittest.main()

from __future__ import annotations

import contextlib
import io
from pathlib import Path
import tempfile
from unittest.mock import patch

from script_test_support import ScriptRegressionTestCase, load_script
from internal.content.common import _parse_tsv_rows
from internal.content.talents import TalentRow

INSPECT = load_script("content_inspect", "content-inspect.py")


class ContentInspectTests(ScriptRegressionTestCase):
    def test_exact_lookup_alias_resolution_locations_and_pagination(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "talents.tsv"
            path.write_text('id\tname\ticon_id\tdescription\tmodifiers\ttriggers\n'
                            '# comment\n\n'
                            'one\tOne\ticon\t"first\nsecond"\t\ton_cleanse_draw:1\n'
                            'two\tTwo\ticon\tOther\t\tcleanseBonusDraw:2\n')
            parser = lambda: _parse_tsv_rows(path, ['id', 'name', 'icon_id', 'description', 'modifiers', 'triggers'], TalentRow)
            def run(*args):
                output = io.StringIO()
                with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                    status = INSPECT.main(list(args))
                return status, output.getvalue()
            with patch.object(INSPECT, 'MANIFEST_DIR', path.parent), patch.dict(INSPECT.PARSERS, {'talents': parser}):
                status, output = run('--kind', 'talents', '--id', 'one')
                self.assertEqual(status, 0)
                self.assertIn('talents.tsv:4', output)
                self.assertIn('description: first\nsecond', output)
                self.assertNotIn('— two', output)
                status, output = run('--kind', 'talents', '--trigger', 'cleanseBonusDraw', '--limit', '1')
                self.assertEqual(status, 0)
                self.assertIn('Matched 2 records', output)
                self.assertIn('--offset 1', output)
                status, output = run('--kind', 'talents', '--trigger', 'cleanseBonusDraw', '--offset', '1')
                self.assertIn('talents.tsv:6', output)
                self.assertEqual(run('--kind', 'talents', '--id', 'on')[0], 1)
                self.assertEqual(run('--kind', 'talents', '--trigger', 'unknown')[0], 2)

    def test_field_shortening_is_explicit_and_expandable(self) -> None:
        rows = [('ContentManifest/talents.tsv:2', 'one', {'id': 'one', 'description': 'x' * 2000})]
        with patch.object(INSPECT, 'records', return_value=rows):
            for flags, expected in (([], False), (['--full'], True)):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(INSPECT.main(['--kind', 'talents', '--id', 'one', *flags]), 0)
                self.assertEqual('x' * 2000 in output.getvalue(), expected)
                self.assertEqual('[shortened; use --full]' in output.getvalue(), not expected)

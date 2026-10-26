"""Focused regressions for documentation, identifier, and hosted routing defects."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import load_script


class AuditToolingRegressions(unittest.TestCase):
    def test_documentation_code_spans_are_examples_not_link_dependencies(self):
        links = load_script('audit_links_code', 'check-links.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source.md'
            missing = root / 'missing.md'
            source.write_text('Use `[label](missing.md)` as syntax.\n'
                              '``A `backtick` and [label](missing.md)``\n'
                              '`a code span\nwith [label](missing.md)`\n'
                              '```md\n[label](missing.md)\n```\n')
            with patch.object(links, 'ROOT', root):
                self.assertEqual(links.broken_links([source]), [])
                self.assertEqual(links.affected_documents([source], {missing.resolve()}), [])
                source.write_text('[real](missing.md)\n')
                self.assertEqual(links.broken_links([source]), ['source.md:1: missing link target missing.md'])
                self.assertEqual(links.affected_documents([source], {missing.resolve()}), [source])
                source.write_text('An unmatched ` in one paragraph.\n\n'
                                  '[real](missing.md) `another unmatched delimiter\n')
                self.assertEqual(links.broken_links([source]), ['source.md:3: missing link target missing.md'])
                source.write_text('Escaped \\` [real](missing.md) \\`\n')
                self.assertEqual(links.broken_links([source]), ['source.md:1: missing link target missing.md'])

    def test_parenthesized_link_destinations_keep_headings_and_inbound_coverage(self):
        links = load_script('audit_links_parentheses', 'check-links.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'guide(draft(v2)).md'
            target.write_text('# Guide\n')
            source = root / 'source.md'
            source.write_text('[guide](guide(draft(v2)).md#guide)\n'
                              '[titled](guide(draft(v2)).md "Title")\n'
                              '[escaped](guide\\(draft\\(v2\\)\\).md#guide)\n')
            with patch.object(links, 'ROOT', root):
                self.assertEqual(links.broken_links([source]), [])
                self.assertEqual(links.affected_documents([source], {target.resolve()}), [source])
                source.write_text('[guide](guide(draft(v2)).md#absent)\n')
                self.assertEqual(links.broken_links([source]),
                                 ['source.md:1: missing heading guide(draft(v2)).md#absent'])

    def test_multiline_raw_identifiers_are_checked_without_comment_or_string_decoys(self):
        checker = load_script('audit_identifiers', 'check-accessibility-ids.py')
        source = '''
// app.buttons["comment"]
/* app.buttons[
    "block comment"
] */
let example = #"app.buttons["example"]"#
app.buttons[
    "actual" // retained line attribution
].tap()
app.descendants(matching: .any)[
    #"raw-actual"#
].tap()
app.buttons[AccessibilityID.playButton].tap()
'''
        self.assertEqual(list(checker.raw_queries(source)), [(7, 'actual'), (10, 'raw-actual')])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ids = root / 'AccessibilityID.swift'
            ids.write_text('''public enum AccessibilityID {
public static let play = "play"
// public static let example = "play"
/* public static let otherExample = "play" */
public static let alias =
    "play"
}
''')
            with patch.object(checker, 'ID_FILE', ids):
                self.assertEqual(checker.unique_constants(), ['play'])

    def test_build_helpers_select_their_hosted_consumers(self):
        routing = load_script('audit_hosted_routing', 'ci-path-filter.py')
        app_helpers = ('Scripts/build-source-times.py', 'Scripts/internal/cli.py',
                       'Scripts/internal/path_matching.py', 'Scripts/internal/source_ownership.py',
                       'Scripts/config/generated-paths.tsv')
        for path in (*app_helpers, 'Scripts/native-test-results.py'):
            with self.subTest(path=path):
                self.assertEqual(routing.classify([path]), (True, False, True))
                self.assertEqual(routing.affected_packages([path], lambda: {}), routing.all_packages())
                self.assertEqual(routing.needs_smoke([path]), path in app_helpers)
        self.assertEqual(routing.classify(['Scripts/release-notes-user.py']), (False, False, True))


if __name__ == '__main__':
    unittest.main()

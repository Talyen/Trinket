from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-read.py',
    'Scripts/check-links.py',
    'Scripts/internal/markdown.py',
    'Scripts/internal/source_declarations.py',
    'Scripts/internal/swift_policy.py',
)


import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import load_script


class AgentReadTests(unittest.TestCase):
    def test_signatures_filters_and_multiple_complete_symbols(self) -> None:
        reader = load_script('signature_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = '''struct Owner {
    var stored: Int = 99
    /// Preserve the supplied value.
    @MainActor
    public static func make(
        _ value: String = "{not a body}", transform: (Int) -> Int = { $0 }
    ) throws -> String {
        return "body-secret"
    }
    private func other() -> Int { 7 }
}
'''
            (root / 'Code.swift').write_text(source)
            (root / 'code.py').write_text('class Owner:\n    # Contract\n    def make(self, data: dict = {"key": 1}) -> str:\n        return "body-secret"\n    value: int = 99\n')
            def read(path, *args):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reader.main([path, *args], root=root), 0)
                return output.getvalue()
            swift = read('Code.swift', '--signatures', '--kind', 'methods', '--match', 'MAKE')
            self.assertIn('public static func make(', swift)
            self.assertIn('throws -> String', swift)
            self.assertIn('{ $0 }', swift)
            self.assertIn('Preserve the supplied value', swift)
            self.assertNotIn('body-secret', swift)
            self.assertNotIn('Owner.stored', swift)
            self.assertNotIn('Owner.other', swift)
            properties = read('Code.swift', '--signatures', '--kind', 'properties')
            self.assertIn('var stored: Int', properties)
            self.assertNotIn('99', properties)
            python = read('code.py', '--signatures', '--kind', 'methods')
            self.assertIn('data: dict = {"key": 1}) -> str', python)
            self.assertIn('# Contract', python)
            self.assertNotIn('body-secret', python)
            multiple = read('Code.swift', '--symbol', 'make', '--symbol', 'other')
            self.assertIn('body-secret', multiple)
            self.assertIn('private func other()', multiple)
            page = read('Code.swift', '--signatures', '--kind', 'methods', '--limit', '1')
            self.assertIn('--signatures --offset 1 --limit 1 --kind methods', page)

    def test_section_reader_preserves_complete_ranges_and_link_anchor_identity(self) -> None:
        reader = load_script("agent_read", "agent-read.py")
        links = load_script("section_links", "check-links.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lines = ["# Guide", "Intro", "## Repeat", "Policy", "### Child", "x" * 500,
                     "````markdown", "## Hidden", "```", "[hidden](missing.md)", "~~~~", "````",
                     "Child ending", "## Repeat", "Second", "## Repeat-1", "Third"]
            path = root / "Guide.md"
            path.write_text("\n".join(lines) + "\n")
            def read(target, *flags):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    status = reader.main([target, *flags], root=root)
                self.assertEqual(status, 0)
                return output.getvalue()
            section = read("Guide.md#repeat")
            self.assertIn("Guide.md:3-13 (complete section)", section)
            self.assertIn("1: # Guide", section)
            self.assertIn("6: " + "x" * 500, section)
            self.assertIn("13: Child ending", section)
            self.assertNotIn("14: ## Repeat", section)
            child = read("Guide.md#child")
            self.assertIn("3: ## Repeat", child)
            self.assertIn("5: ### Child", child)
            self.assertNotIn("4: Policy", child)
            outline = read("Guide.md", "--outline")
            self.assertNotIn("#hidden", outline)
            self.assertIn("Guide.md#repeat-1 [14-15]", outline)
            self.assertIn("Guide.md#repeat-1-1 [16-17]", outline)
            self.assertIn("15: Second", read("Guide.md#repeat-1"))
            self.assertIn("17: Third", read("Guide.md"))
            source = root / "Links.md"
            source.write_text("\n".join(f"[section](Guide.md#{slug})" for slug in links.heading_slugs(path)))
            with patch.object(links, "ROOT", root):
                self.assertEqual(links.broken_links([source, path]), [])
            for target in ("Guide.md#absent", "../outside.md", "Guide.swift"):
                with contextlib.redirect_stderr(io.StringIO()) as error, contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reader.main([target], root=root), 2)
                self.assertEqual(output.getvalue(), "")
                self.assertIn("Read failed:", error.getvalue())


    def test_source_outline_and_explicit_reads(self) -> None:
        reader = load_script("source_reader", "agent-read.py")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "code.py").write_text('"def fake(): pass"\nclass Owner:\n    def real(self):\n        return 2\n')
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(["code.py", "--outline", "--limit", "1"], root=root), 0)
            self.assertIn("2:4 class Owner", output.getvalue())
            self.assertNotIn("fake", output.getvalue())
            self.assertIn("omitted 1", output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(["code.py", "--lines", "3:4"], root=root), 0)
            self.assertIn("4:         return 2", output.getvalue())
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(reader.main(["code.py", "--lines", "3:9"], root=root), 2)
            (root / "code.swift").write_text('struct Owner {}\n')
            tokens = [{"type": "keyword", "string": "struct"}, {"type": "space", "string": " "},
                      {"type": "identifier", "string": "Owner"}, {"type": "space", "string": " "},
                      {"type": "startOfScope", "string": "{"}, {"type": "endOfScope", "string": "}"}]
            with patch("internal.swift_policy.formatter_tokens", return_value=tokens):
                self.assertEqual([(d.name, d.start, d.end) for d in reader.source_declarations(root / "code.swift", 'struct Owner {}\n')], [('Owner', 1, 1)])


    def test_swift_member_ranges_attributes_literals_overloads_and_locals(self) -> None:
        reader = load_script("member_reader", "agent-read.py")
        source = '''/// Container documentation
@MainActor
struct Owner {
    /// Executes work.
    @available(
        iOS 26, *
    )
    func work(
        _ input: Int
    ) -> Int {
        let text = "not a scope: } func fake() {"
        func nested() -> Int { input }
        return nested()
    }
    func work(_ input: String) {}
    struct Child {
        var value: Int { 3 }
    }
    let values = [
        1, 2
    ]
    class func factory() {}
}
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'code.swift'
            path.write_text(source)
            entries = reader.source_declarations(path, source)
            names = [d.name for d in entries]
            self.assertEqual(names, ['Owner', 'Owner.work', 'Owner.work', 'Owner.Child',
                                     'Owner.Child.value', 'Owner.values', 'Owner.factory'])
            works = [d for d in entries if d.name == 'Owner.work']
            self.assertEqual((works[0].start, works[0].end), (4, 14))
            self.assertEqual((entries[0].start, entries[0].end), (1, 23))
            self.assertIn('Owner.work.nested', [d.name for d in reader.source_declarations(path, source, True)])
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['code.swift', '--symbol', 'work'], root=root), 2)
            self.assertIn('Ambiguous symbol', output.getvalue())
            self.assertNotIn('return nested()', output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['code.swift', '--symbol', 'work', '--limit', '1'], root=root), 2)
            self.assertIn('Candidates 0:1 of 2; omitted 1', output.getvalue())
            self.assertIn('--symbol work --offset 1 --limit 1', output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['code.swift', '--symbol', 'Owner.values'], root=root), 0)
            self.assertIn('1, 2', output.getvalue())
            self.assertNotIn('factory', output.getvalue())

    def test_python_qualified_symbols_decorators_and_local_visibility(self) -> None:
        reader = load_script("python_member_reader", "agent-read.py")
        source = '''class Owner:
    # Member documentation
    @decorator(
        1
    )
    def work(self):
        local = 1
        def helper():
            return local
        return helper()
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'code.py'
            path.write_text(source)
            entries = reader.source_declarations(path, source)
            self.assertEqual([d.name for d in entries], ['Owner', 'Owner.work'])
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['code.py', '--symbol', 'Owner.work'], root=root), 0)
            self.assertIn('# Member documentation', output.getvalue())
            self.assertIn('return helper()', output.getvalue())
            self.assertIn('Owner.work.helper', [d.name for d in reader.source_declarations(path, source, True)])

    def test_swift_property_initializer_tail_and_protocol_requirements(self) -> None:
        reader = load_script('tail_reader', 'agent-read.py')
        source = '''protocol Factory {
    associatedtype Value
    func make() -> Value
    var value: Value { get }
}
struct Owner {
    /// Creates values (once)
    var values = {
        [1, 2]
    }()
        .map { $0 + 1 }
    var next = 3
}
'''
        entries = reader.source_declarations(Path('sample.swift'), source)
        by_name = {entry.name: entry for entry in entries}
        self.assertEqual((by_name['Owner.values'].start, by_name['Owner.values'].end), (7, 11))
        self.assertEqual((by_name['Factory.make'].start, by_name['Factory.make'].end), (3, 3))
        self.assertIn('Factory.Value', by_name)
        self.assertEqual(by_name['Owner.next'].end, 12)

    def test_large_documents_require_explicit_read_and_outline_can_be_paged(self) -> None:
        reader = load_script('bounded_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            text = '# Guide\n## Rules\n' + 'important rule\n' * 1000 + '## End\nLast rule\n'
            (root / 'Guide.md').write_text(text)
            def read(*args):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reader.main(['Guide.md', *args], root=root), 0)
                return output.getvalue()
            default = read('--limit', '2')
            self.assertIn('Navigation only', default)
            self.assertIn('NOT been read', default)
            self.assertNotIn('important rule', default)
            self.assertIn('--full', default)
            self.assertIn('Omitted 1 headings', default)
            self.assertIn('Guide.md#end', read('--outline', '--offset', '2'))
            self.assertIn('Last rule', read('--full'))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['Guide.md#rules'], root=root), 0)
            self.assertEqual(output.getvalue().count('important rule'), 1000)
            (root / 'Guide.md').write_text('no headings\n' * 2000)
            self.assertIn('No headings', read())

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',
    'Scripts/lib/output-retention.sh',
    'Scripts/agent-read.py',
    'Scripts/agent-session.py',
    'Scripts/agent-context.sh',
    'Scripts/internal/agent_tasks.py',
    'Scripts/check-links.py',
    'Scripts/internal/markdown.py',
    'Scripts/internal/source_declarations.py',
    'Scripts/internal/agent_references.py',
    'Scripts/internal/agent_arguments.py',
    'Scripts/internal/swift_policy.py',
)


import contextlib
import io
import hashlib
import shlex
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import load_script


class AgentReadTests(unittest.TestCase):
    def test_explicit_guidance_reuse_skips_only_complete_unchanged_reads_and_forget_restores_them(self) -> None:
        reader = load_script('incremental_reader', 'agent-read.py')
        session = load_script('incremental_session', 'agent-session.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            guide = root / 'Guide.md'
            guide.write_text('# Guide\n## Rules\nKeep saves\n## Other\nKeep artwork\n')
            (root / 'code.py').write_text('def work():\n    return 42\n')
            receipt = root / 'receipt.json'
            with patch.object(reader, 'session_receipt', return_value=receipt):
                def read(*arguments):
                    with contextlib.redirect_stdout(io.StringIO()) as output:
                        self.assertEqual(reader.main(['--session', 'chat', *arguments], root=root), 0)
                    return output.getvalue()
                read('Guide.md#rules')
                self.assertIn('Keep saves', read('Guide.md#rules'))  # default still rereads
                reused = read('Guide.md#rules', '--reuse-guidance')
                self.assertIn('reused unchanged guidance', reused)
                self.assertNotIn('Keep saves', reused)
                self.assertIn('Keep artwork', read('Guide.md#other', '--reuse-guidance'))
                self.assertIn('Keep saves', read('Guide.md', '--reuse-guidance'))  # sections do not cover whole file
                self.assertNotIn('Keep artwork', read('Guide.md#other', '--reuse-guidance'))
                guide.write_text(guide.read_text().replace('Keep saves', 'Migrate saves'))
                self.assertIn('Migrate saves', read('Guide.md#rules', '--reuse-guidance'))
                mixed = read('--reuse-guidance', '--request', 'Guide.md#rules', '--request', 'code.py --symbol work')
                self.assertNotIn('Migrate saves', mixed)
                self.assertIn('return 42', mixed)
                with patch.object(session, 'session_receipt', return_value=receipt), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(session.main(['--chat', 'chat', 'forget'], root=root), 0)
                self.assertIn('Migrate saves', read('Guide.md#rules', '--reuse-guidance'))
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    reader.main(['Guide.md', '--reuse-guidance'], root=root)
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    reader.main(['Guide.md', '--session', 'another-chat', '--reuse-guidance'], root=root)

    def test_full_batches_keep_anchor_scope_and_continue_after_missing_anchors(self) -> None:
        reader = load_script('full_section_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Guide.md').write_text('# Guide\n## Rules\nKeep saves\n## Other\nKeep artwork\n')
            (root / 'code.py').write_text('def work():\n    return 42\n')
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['Guide.md#rules', 'code.py', '--full'], root=root), 0)
            self.assertIn('Keep saves', output.getvalue())
            self.assertIn('return 42', output.getvalue())
            self.assertNotIn('Keep artwork', output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(reader.main(['Guide.md#missing', 'code.py', '--full'], root=root), 2)
            self.assertIn('return 42', output.getvalue())
            self.assertNotIn('Keep artwork', output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(reader.main(['code.py#work', '--full'], root=root), 2)
            self.assertEqual(output.getvalue(), '')
            with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(reader.main(['--request', 'Guide.md --unsupported', '--request', 'code.py --full'], root=root), 2)
            self.assertIn('return 42', output.getvalue())
            self.assertIn('unrecognized arguments', errors.getvalue())
            self.assertNotIn('usage:', errors.getvalue())

    def test_full_text_reads_accept_config_and_source_without_guidance_receipts(self) -> None:
        reader = load_script('full_text_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'config.json').write_text('{"value": 1}\n')
            (root / 'Probe.py').write_text('def work():\n    return 1\n')
            for name in ('config.json', 'Probe.py'):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reader.main([name, '--full'], root=root), 0)
                self.assertIn('complete text file', output.getvalue())
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(reader.main([name, '--full', '--receipt', str(root / 'receipt'), '--chat', 'test'], root=root), 2)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['config.json', '--full', 'Probe.py'], root=root), 0)
            self.assertEqual(output.getvalue().count('complete text file'), 2)

    def test_brief_preserves_scope_and_attempts_all_source_reads_after_failure(self) -> None:
        session = load_script('brief_session', 'agent-session.py')
        task = {'id': 'thing', 'sources': ['Sources/Thing.py'], 'tests': ['Tests/Thing.py']}
        from types import SimpleNamespace
        with patch.object(session, 'select_task', return_value=task), patch.object(session.subprocess, 'run') as run:
            run.side_effect = [SimpleNamespace(returncode=0),
                               SimpleNamespace(returncode=0, stdout='python3 Scripts/agent-read.py Guide.md --session chat'),
                               SimpleNamespace(returncode=0), SimpleNamespace(returncode=2), SimpleNamespace(returncode=0)]
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(session.main(['--chat', 'chat', 'brief', '--task', 'thing', '--reuse-guidance', '--limit', '2', '--paths', 'One.py', 'Two.py']), 2)
            self.assertIn('--status', run.call_args_list[0].args[0])
            self.assertEqual(run.call_args_list[0].args[0][-3:], ['--paths', 'One.py', 'Two.py'])
            self.assertIn('Two.py', run.call_args_list[-1].args[0])
            self.assertIn('--reuse-guidance', run.call_args_list[2].args[0])
            self.assertNotIn('--reuse-guidance', run.call_args_list[1].args[0])
            self.assertIn('Tests/Thing.py', output.getvalue())

    def test_invalid_source_range_reports_bounds_and_returns_a_bounded_read(self) -> None:
        reader = load_script('range_recovery_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Probe.py').write_text('def work():\n    return 1\n')
            with contextlib.redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(reader.main(['Probe.py', '--lines', '1:100'], root=root), 2)
            self.assertIn('within 1:2', errors.getvalue())
            command = shlex.split(errors.getvalue().split('Try: ', 1)[1].strip())
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(command[2:], root=root), 0)
            self.assertIn('return 1', output.getvalue())

    def test_invalid_top_level_flags_include_an_executable_help_command(self) -> None:
        reader = load_script('usage_recovery_reader', 'agent-read.py')
        with contextlib.redirect_stderr(io.StringIO()) as errors, self.assertRaises(SystemExit):
            reader.main(['--unsupported'])
        command = shlex.split(errors.getvalue().split('Try: ', 1)[1].splitlines()[0])
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as result:
            reader.main(command[2:])
        self.assertEqual(result.exception.code, 0)

    def test_recovery_commands_run_for_source_config_shell_and_navigation_errors(self) -> None:
        reader = load_script('command_recovery_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Probe.py').write_text('def work():\n    return 1\n')
            (root / 'config.json').write_text('{"value": 1}\n')
            (root / 'run.sh').write_text('#!/bin/bash\nprintf hello\n')
            (root / 'Guide.md').write_text('# Guide\n## Rules\nKeep saves\n')
            cases = (['run.sh', '--outline'],
                     ['Probe.py', '--symbol', 'missing'], ['Guide.md#missing'], ['run.sh', '--lines', '99:100'],
                     ['Probe.py', '--outline', '--offset', '99'])
            for arguments in cases:
                with self.subTest(arguments=arguments), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as errors:
                    self.assertEqual(reader.main(arguments, root=root), 2)
                command = errors.getvalue().split('Try: ', 1)[1].splitlines()[0]
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(reader.main(shlex.split(command)[2:], root=root), 0)

    def test_mixed_session_reads_record_only_complete_guidance_and_continue_after_failure(self) -> None:
        reader = load_script('mixed_session_reader', 'agent-read.py')
        references = load_script('mixed_session_references', 'internal/agent_references.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Guide.md').write_text('# Guide\n## Rules\nKeep saves\n## Other\nKeep artwork\n')
            (root / 'Probe.py').write_text('def work():\n    return "$(literal)"\n')
            (root / 'run.sh').write_text('#!/bin/bash\nvalue=1\n')
            receipt = root / 'receipt.json'
            with patch.object(reader, 'session_receipt', return_value=receipt):
                arguments = ['--session', 'mixed-chat', '--request', 'Guide.md#rules',
                             '--request', 'Guide.md --outline', '--request', 'Probe.py --symbol work',
                             '--request', 'Missing.md', '--request', 'run.sh --lines 2:2',
                             '--request', 'Guide.md#rules']
                with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(reader.main(arguments, root=root), 2)
                self.assertEqual(output.getvalue().count('Keep saves'), 1)
                self.assertIn('complete lexical declaration: work', output.getvalue())
                self.assertIn('2: value=1', output.getvalue())
                state = references.read_receipt(receipt, 'mixed-chat', root)
                self.assertEqual(set(state['reads']), {'Guide.md#rules'})
                self.assertFalse(references.can_reuse(state, root, 'Guide.md#other'))
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(reader.main(['--request', 'Guide.md --session another-chat', '--request', 'run.sh --lines 1:1'], root=root), 2)
            self.assertNotEqual(references.session_receipt('one', root), references.session_receipt('two', root))
            self.assertNotEqual(references.session_receipt('one', root), references.session_receipt('one', root / 'other'))

    def test_session_wrapper_forwards_identity_and_forgets_only_its_own_receipt(self) -> None:
        session = load_script('session_wrapper', 'agent-session.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            receipt = root / 'receipt.json'
            receipt.write_text('{}')
            with patch.object(session.subprocess, 'run') as run:
                run.return_value.returncode = 0
                self.assertEqual(session.main(['--chat', 'this-chat', 'context', '--task', 'cloud'], root=root), 0)
                self.assertEqual(run.call_args.args[0], ['bash', 'Scripts/agent-context.sh', '--session', 'this-chat', '--task', 'cloud'])
            with patch.object(session, 'session_receipt', return_value=receipt), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(session.main(['--chat', 'this-chat', 'forget'], root=root), 0)
            self.assertFalse(receipt.exists())

    def test_session_task_read_preserves_chat_and_scope_without_shell_execution(self) -> None:
        session = load_script('session_task_wrapper', 'agent-session.py')
        with patch.object(session.subprocess, 'run') as run:
            from types import SimpleNamespace
            run.side_effect = [SimpleNamespace(returncode=0, stdout="python3 Scripts/agent-read.py --session 'chat id' --request 'Guide.md#rules'\n"), SimpleNamespace(returncode=0)]
            self.assertEqual(session.main(['--chat', 'chat id', 'read', '--task=shop', '--paths', 'Scripts/a b.py']), 0)
            self.assertEqual(run.call_args_list[0].args[0], ['bash', 'Scripts/agent-context.sh', '--session', 'chat id', '--read-command', '--task', 'shop', '--paths', 'Scripts/a b.py'])
            self.assertEqual(run.call_args_list[1].args[0][-1], 'Guide.md#rules')
            self.assertNotIn('shell', run.call_args.kwargs)
        with patch.object(session.subprocess, 'run') as run, contextlib.redirect_stderr(io.StringIO()):
            run.return_value = SimpleNamespace(returncode=2, stderr='Task routing failed\n')
            self.assertEqual(session.main(['--chat', 'chat', 'read', '--task', 'unknown']), 2)
            run.assert_called_once()

    def test_mixed_read_modes_print_an_executable_section_retry(self) -> None:
        reader = load_script('recovery_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Guide.md').write_text('# Guide\n## Rules\nKeep saves\n')
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(reader.main(['Guide.md#rules', '--lines', '1:2'], root=root), 2)
            command = errors.getvalue().split('Read the section separately: ', 1)[1].splitlines()[0]
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(shlex.split(command)[2:], root=root), 0)
            self.assertIn('Keep saves', output.getvalue())

    def test_receipts_cover_only_complete_read_content_and_invalidate_edits_and_other_chats(self) -> None:
        reader = load_script('receipt_reader', 'agent-read.py')
        references = load_script('receipt_references', 'internal/agent_references.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            guide = root / 'Guide.md'
            guide.write_text('# Guide\n## Rules\nKeep saves\n## Other\nKeep artwork\n')
            receipt = root / 'receipt.json'
            flags = ['--receipt', str(receipt), '--chat', 'this-chat']
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(reader.main(['Guide.md#rules', *flags], root=root), 0)
            state = references.read_receipt(receipt, 'this-chat', root)
            self.assertTrue(references.can_reuse(state, root, 'Guide.md#rules'))
            self.assertFalse(references.can_reuse(state, root, 'Guide.md'))
            self.assertFalse(references.can_reuse(state, root, 'Guide.md#other'))
            with self.assertRaises(ValueError):
                references.read_receipt(receipt, 'other-chat', root)
            guide.write_text(guide.read_text().replace('Keep artwork', 'Prepare artwork'))
            self.assertFalse(references.can_reuse(state, root, 'Guide.md#rules'))
            before = receipt.read_bytes()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(reader.main(['Guide.md', '--outline', *flags], root=root), 2)
                self.assertEqual(reader.main(['Guide.md#missing', *flags], root=root), 2)
            with patch.object(reader, 'DOCUMENT_CHAR_BUDGET', 1), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['Guide.md', *flags], root=root), 0)
                self.assertIn('NOT been read', output.getvalue())
            self.assertEqual(receipt.read_bytes(), before)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(reader.main(['Guide.md', *flags], root=root), 0)
            state = references.read_receipt(receipt, 'this-chat', root)
            self.assertTrue(references.can_reuse(state, root, 'Guide.md#other'))

    def test_reference_identity_invalidates_all_sections_and_rejects_missing_anchors(self) -> None:
        references = load_script('reference_identity', 'internal/agent_references.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            guide = root / 'Guide.md'
            guide.write_text('# Guide\n## Rules\nKeep saves\n## Other\nOld\n')
            before = references.fingerprint(root, 'Guide.md#rules')
            guide.write_text(guide.read_text().replace('Old', 'New'))
            self.assertNotEqual(references.fingerprint(root, 'Guide.md#rules'), before)
            self.assertEqual(references.fingerprint(root, 'Guide.md#rules'), references.fingerprint(root, 'Guide.md'))
            with self.assertRaises(ValueError):
                references.fingerprint(root, 'Guide.md#absent')
            with self.assertRaises(ValueError):
                references.fingerprint(root, '../outside.md')

    def test_batch_reads_deduplicate_targets_and_attempt_later_reads_after_failure(self) -> None:
        reader = load_script('batch_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'First.md').write_text('# First\n## Rules\nKeep saves\n')
            (root / 'Last.md').write_text('# Last\nKeep artwork\n')
            with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
                status = reader.main(['First.md#rules', 'Missing.md', 'Last.md', 'First.md#rules'], root=root)
            self.assertEqual(status, 2)
            self.assertEqual(output.getvalue().count('Keep saves'), 1)
            self.assertIn('Keep artwork', output.getvalue())
            self.assertIn('Missing.md', errors.getvalue())
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['First.md', 'Last.md', '--outline'], root=root), 0)
            self.assertIn('First.md#rules', output.getvalue())
            self.assertIn('Last.md#last', output.getvalue())
            self.assertNotIn('Continue:', output.getvalue())

    def test_shell_and_config_ranges_preserve_bytes_identity_and_reject_escape_or_binary(self) -> None:
        reader = load_script('range_reader', 'agent-read.py')
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            root = Path(directory)
            data = b'#!/bin/bash\r\nvalue="$(literal)"\r\nlast\r\n'
            (root / 'script.sh').write_bytes(data)
            (root / 'config.yml').write_text('first: 1\nlast: 2\n')
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['script.sh', 'config.yml', '--lines', '2:2', '--fingerprint'], root=root), 0)
            self.assertIn('2: value="$(literal)"', output.getvalue())
            self.assertIn('2: last: 2', output.getvalue())
            self.assertIn(hashlib.sha256(data).hexdigest(), output.getvalue())
            (Path(outside) / 'outside.sh').write_text('secret\n')
            (root / 'escape.sh').symlink_to(Path(outside) / 'outside.sh')
            (root / 'binary.json').write_bytes(b'\xff\x00')
            for args in (['script.sh'], ['escape.sh', '--lines', '1:1'], ['binary.json', '--lines', '1:1']):
                with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(reader.main(args, root=root), 2)
                self.assertEqual(output.getvalue(), '')

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
            default = read('--limit', '2', '--fingerprint')
            self.assertIn('Navigation only', default)
            self.assertIn('NOT been read', default)
            self.assertNotIn('important rule', default)
            self.assertIn('--full', default)
            self.assertIn('Omitted 1 headings', default)
            self.assertIn('--limit 2 --fingerprint', default)
            last_page = read('--outline', '--offset', '2')
            self.assertIn('Guide.md#end', last_page)
            self.assertNotIn('Continue:', last_page)
            self.assertIn('Last rule', read('--full'))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(reader.main(['Guide.md#rules'], root=root), 0)
            self.assertEqual(output.getvalue().count('important rule'), 1000)
            (root / 'Guide.md').write_text('no headings\n' * 2000)
            self.assertIn('No headings', read())

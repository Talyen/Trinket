from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',
    'Scripts/agent-efficiency.py',
    'Scripts/agent-search.py',
    'Scripts/agent-read.py',
    'Scripts/agent-context.sh',
    'Scripts/change-classification.sh',
    'Scripts/internal/agent_references.py',
    'Scripts/internal/agent_tasks.py',
    'Scripts/config/agent-tasks.json',
)

import copy
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from script_test_support import load_script

EFFICIENCY = load_script('agent_efficiency', 'agent-efficiency.py')


class AgentEfficiencyTests(unittest.TestCase):
    def test_collection_uses_actual_per_response_counts_and_rejects_duplicate_or_incomplete_usage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / 'trial.json'
            usage = root / 'usage.json'
            report = self.report()
            task = report['tasks'][0]
            task.update(usage_file='usage.json', usage_evidence='fixture provider export, final per-response accounting')
            task['metrics']['total_tokens'] = None
            manifest.write_text(json.dumps(report))
            rows = [{'id': 'response-1', 'input_tokens': 50, 'output_tokens': 20},
                    {'id': 'response-2', 'input_tokens': 30, 'output_tokens': 10}]
            usage.write_text(json.dumps(rows))
            result = EFFICIENCY.collect_tasks(manifest)['tasks'][0]
            self.assertEqual(result['metrics']['total_tokens'], 110)
            self.assertEqual(result['response_count'], 2)
            self.assertEqual(len(result['usage_sha256']), 64)
            for invalid in ([], rows + [rows[0]], [{'id': 'response-3', 'input_tokens': True, 'output_tokens': 1}],
                            [{'id': 'response-3', 'input_tokens': 1}]):
                usage.write_text(json.dumps(invalid))
                with self.assertRaises(ValueError):
                    EFFICIENCY.collect_tasks(manifest)
            usage.write_text(json.dumps(rows))
            task['metrics']['total_tokens'] = 100
            manifest.write_text(json.dumps(report))
            with self.assertRaises(ValueError):
                EFFICIENCY.collect_tasks(manifest)

    def test_preparation_keeps_unmeasured_usage_and_judgement_null(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            report = EFFICIENCY.prepare_tasks(root)
            self.assertEqual(len(report['tasks']), 4)
            self.assertTrue(all(task['metrics']['total_tokens'] is None and task['correct'] is None
                                for task in report['tasks']))
            with self.assertRaises(ValueError):
                EFFICIENCY.compare(report, report)
            repeated = EFFICIENCY.prepare_tasks(root, repetitions=3)
            self.assertEqual(len({task['id'] for task in repeated['tasks']}), 12)
            self.assertTrue(all(task['acceptance'] and task['metrics']['total_tokens'] is None for task in repeated['tasks']))
            extended = EFFICIENCY.prepare_tasks(root, suite='extended')
            self.assertTrue({'particles', 'voyage', 'labyrinth'} <= {task['id'] for task in extended['tasks']})
            self.assertIn('particles', {task['id'] for task in extended['tasks']})
            with self.assertRaises(ValueError):
                EFFICIENCY.prepare_tasks(root, repetitions=0)

    def report(self):
        return {
            'kind': 'task',
            'context': {'source_sha256': 'a' * 64, 'model': 'fixture', 'reasoning': 'high', 'tools': ['shell']},
            'tasks': [{'id': 'combat', 'request': 'Fix the evidenced combat defect.',
                       'correct': True, 'complete': True, 'evidence': 'fixture assertions and final diff',
                       'metrics': {'total_tokens': 100, 'repeated_reads': 2, 'retries': 1,
                                   'failed_commands': 1, 'unnecessary_stops': 0}}],
        }

    def test_complete_tasks_require_matching_inputs_and_actual_usage_fields(self):
        before = self.report()
        after = copy.deepcopy(before)
        after['tasks'][0]['metrics']['total_tokens'] = 80
        rows, accepted = EFFICIENCY.compare(before, after)
        self.assertTrue(accepted)
        self.assertIn('20.0% reduction', '\n'.join(rows))
        for key in ('source_sha256', 'model', 'reasoning', 'tools'):
            mismatch = copy.deepcopy(after)
            mismatch['context'][key] = 'different'
            with self.subTest(key=key), self.assertRaises(ValueError):
                EFFICIENCY.compare(before, mismatch)
        for mutate in (
            lambda task: task.update(request='A different task'),
            lambda task: task.pop('evidence'),
            lambda task: task['metrics'].pop('total_tokens'),
            lambda task: task['metrics'].update(total_tokens=True),
            lambda task: task['metrics'].update(retries=-1),
        ):
            invalid = copy.deepcopy(after)
            mutate(invalid['tasks'][0])
            with self.assertRaises(ValueError):
                EFFICIENCY.compare(before, invalid)

    def test_lower_tokens_cannot_compensate_for_incorrect_or_incomplete_work(self):
        before = self.report()
        for key in ('correct', 'complete'):
            after = copy.deepcopy(before)
            after['tasks'][0][key] = False
            after['tasks'][0]['metrics']['total_tokens'] = 1
            rows, accepted = EFFICIENCY.compare(before, after)
            self.assertFalse(accepted)
            self.assertIn('FAILED correctness/completion', '\n'.join(rows))

    def test_retrieval_cannot_be_compared_as_tokens_or_with_changed_verification(self):
        report = {'kind': 'retrieval', 'context': {'source_sha256': 'a' * 64, 'probe_version': 1},
                  'tasks': [{'id': 'tooling', 'request': 'Inspect checker ownership.', 'handoff': 'same command',
                             'metrics': {'output_characters': 400, 'commands': 4, 'failed_commands': 0}}]}
        rows, accepted = EFFICIENCY.compare(report, copy.deepcopy(report))
        self.assertTrue(accepted)
        self.assertIn('total task tokens are unmeasured', '\n'.join(rows))
        changed = copy.deepcopy(report)
        changed['tasks'][0]['handoff'] = 'weakened command'
        with self.assertRaises(ValueError):
            EFFICIENCY.compare(report, changed)
        with self.assertRaises(ValueError):
            EFFICIENCY.compare(report, self.report())

    def test_product_identity_accounts_for_dirty_new_and_deleted_inputs_but_excludes_guidance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            source = root / 'Packages/Game/Sources/Game.swift'
            source.parent.mkdir(parents=True)
            source.write_text('struct Game {}')
            original = EFFICIENCY.source_fingerprint(root)
            (root / 'AGENTS.md').write_text('Different guidance')
            self.assertEqual(EFFICIENCY.source_fingerprint(root), original)
            source.write_text('struct Game { var value = 1 }')
            self.assertNotEqual(EFFICIENCY.source_fingerprint(root), original)
            source.write_text('struct Game {}')
            subprocess.run(['git', 'add', '.'], cwd=root, check=True)
            self.assertEqual(EFFICIENCY.source_fingerprint(root), original)
            new = source.with_name('New.swift')
            new.write_text('struct New {}')
            self.assertNotEqual(EFFICIENCY.source_fingerprint(root), original)
            new.unlink()
            source.unlink()
            self.assertNotEqual(EFFICIENCY.source_fingerprint(root), original)


if __name__ == '__main__':
    unittest.main()

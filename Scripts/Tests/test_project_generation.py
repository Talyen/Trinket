"""Generated project and real Git hook behavior in isolated repositories."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from script_test_support import ROOT


class ProjectGenerationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        self.env['PROJECT_CALLS'] = str(self.root / 'calls')
        for path in ('.githooks/pre-commit', 'Scripts/check-staged-project.sh',
                     'Scripts/lib/project-generation.sh', 'Scripts/lib/tools.sh'):
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)
        self.write('Scripts/ensure-ci-tools.sh', '#!/bin/bash\nexit 0\n', executable=True)
        self.write('Scripts/tool-versions.env', 'XCODEGEN_WRAPPER_REV=1\n')
        self.write('.tools/xcodegen', '''#!/bin/bash
set -eu
printf 'called\\n' >> "$PROJECT_CALLS"
shift
while (( $# )); do
  case "$1" in
    --spec) spec="$2"; shift 2 ;;
    --cache-path) cache="$2"; shift 2 ;;
    *) exit 9 ;;
  esac
done
[[ ! -e "$cache" ]] || exit 8
root="$(dirname "$spec")"
mkdir -p "$root/Trinket.xcodeproj"
cp "$spec" "$root/Trinket.xcodeproj/project.pbxproj"
printf cached > "$cache"
''', executable=True)
        self.write('.gitignore', '.tools/\ncalls\n.DerivedData/\n')
        self.write('project.yml', 'canonical\n')
        self.write('Trinket.xcodeproj/project.pbxproj', 'canonical\n')
        self.write('code.swift', 'original\n')
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('add', '.')
        self.git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'baseline')
        self.git('config', 'core.hooksPath', '.githooks')

    def write(self, relative, text, executable=False):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)

    def run_command(self, *args, expected=0):
        result = subprocess.run(
            args,
            cwd=self.root,
            env=self.env,
            text=True,
            capture_output=True,
            stdin=subprocess.DEVNULL,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def git(self, *args, expected=0):
        return self.run_command('git', *args, expected=expected)

    def test_real_commit_checks_staged_pair_and_preserves_working_changes(self):
        self.write('project.yml', 'staged\n')
        self.write('Trinket.xcodeproj/project.pbxproj', 'staged\n')
        self.git('add', 'project.yml', 'Trinket.xcodeproj/project.pbxproj')
        self.write('project.yml', 'unstaged\n')
        self.write('Trinket.xcodeproj/project.pbxproj', 'unrelated output edit\n')
        self.write('code.swift', 'unrelated\n')
        staged_tree = self.git('write-tree').stdout.strip()
        self.git('commit', '-qm', 'project change')
        self.assertEqual(self.git('rev-parse', 'HEAD^{tree}').stdout.strip(), staged_tree)
        self.assertEqual((self.root / 'project.yml').read_text(), 'unstaged\n')
        self.assertEqual((self.root / 'Trinket.xcodeproj/project.pbxproj').read_text(), 'unrelated output edit\n')
        self.assertEqual((self.root / 'code.swift').read_text(), 'unrelated\n')
        self.assertEqual((self.root / 'calls').read_text(), 'called\n')

    def test_real_commit_rejects_stale_staged_output_without_changing_index(self):
        for output_only in (False, True):
            with self.subTest(output_only=output_only):
                self.git("read-tree", "HEAD")
                self.write("project.yml", "canonical\n")
                self.write("Trinket.xcodeproj/project.pbxproj", "canonical\n")
                if output_only:
                    self.write('Trinket.xcodeproj/project.pbxproj', 'damaged\n')
                    self.git('add', 'Trinket.xcodeproj/project.pbxproj')
                else:
                    self.write('project.yml', 'new input\n')
                    self.git('add', 'project.yml')
                    self.write('Trinket.xcodeproj/project.pbxproj', 'new input\n')
                index = (self.root / '.git/index').read_bytes()
                result = self.run_command('bash', '.githooks/pre-commit', expected=1)
                self.assertIn('staged project does not match staged inputs', result.stderr)
                self.assertIn('./Scripts/generate.sh', result.stderr)
                self.assertEqual((self.root / '.git/index').read_bytes(), index)
                staged = self.git('ls-files', '--stage').stdout
                self.git('commit', '-qm', 'bad project', expected=1)
                self.assertEqual(self.git('ls-files', '--stage').stdout, staged)

    def test_code_only_commit_skips_generation(self):
        self.write('code.swift', 'updated\n')
        self.git('add', 'code.swift')
        self.git('commit', '-qm', 'code change')
        self.assertFalse((self.root / 'calls').exists())

    def test_tool_revision_commit_generates_and_mixed_tool_staging_is_rejected(self):
        self.write('Scripts/tool-versions.env', 'XCODEGEN_WRAPPER_REV=2\n')
        self.git('add', 'Scripts/tool-versions.env')
        self.write('Scripts/tool-versions.env', 'XCODEGEN_WRAPPER_REV=3\n')
        index = (self.root / '.git/index').read_bytes()
        result = self.run_command('bash', '.githooks/pre-commit', expected=1)
        self.assertIn('staged/unstaged tool', result.stderr)
        self.assertEqual((self.root / '.git/index').read_bytes(), index)
        self.assertFalse((self.root / 'calls').exists())
        self.write('Scripts/tool-versions.env', 'XCODEGEN_WRAPPER_REV=2\n')
        self.git('commit', '-qm', 'tool revision')
        self.assertEqual((self.root / 'calls').read_text(), 'called\n')

    def test_uncached_generation_repairs_output_and_tracks_input(self):
        for initial, spec in ((None, 'canonical\n'), ('damaged\n', 'canonical\n'),
                              ('canonical\n', 'changed\n'), ('changed\n', 'changed\n')):
            with self.subTest(initial=initial, spec=spec):
                self.write('project.yml', spec)
                project = self.root / 'Trinket.xcodeproj/project.pbxproj'
                if initial is None:
                    project.unlink()
                else:
                    project.write_text(initial)
                self.write('.DerivedData/XcodeGen.cache', 'old cache\n')
                self.write('.DerivedData/XcodeGen.cache.hash', 'malformed metadata\n')
                self.run_command('bash', '-ec',
                                 'source Scripts/lib/project-generation.sh; trinket_generate_project "$PWD" "$PWD"')
                self.assertEqual(project.read_text(), spec)
        self.assertEqual((self.root / 'calls').read_text(), 'called\n' * 4)

    def test_push_hook_keeps_commit_completeness_for_project_changes(self):
        for relative in ('.githooks/pre-push', 'Scripts/agent-push-gate.sh',
                         'Scripts/assert-generated-output.sh', 'Scripts/change-classification.sh',
                         'Scripts/lib/classification-plan.sh', 'Scripts/lib/smoke-classes.sh',
                         'Scripts/config/smoke-classes.txt', 'Scripts/swift-source-dirs.env',
                         'Scripts/build-inputs.env', 'Scripts/format-dirs.env'):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        for filename in ('check-api-bans.sh', 'check-exclusivity-footguns.sh',
                         'check-agent-invariants.sh', 'check-comment-ban.sh',
                         'change-budget.sh', 'test.sh'):
            self.write('Scripts/' + filename, '#!/bin/bash\nexit 0\n', executable=True)
        self.write('Scripts/check-accessibility-ids.py', '')
        self.write('Scripts/generate.sh',
                   '#!/bin/bash\nsource Scripts/lib/project-generation.sh\n'
                   'trinket_generate_project "$PWD" "$PWD"\n', executable=True)
        self.write('Scripts/config/generated-paths.tsv', 'project|Trinket.xcodeproj/project.pbxproj\n')
        identifier = 'A' * 24
        canonical = ('Begin PBXNativeTarget section\n' + identifier
                     + ' /* target */\nEnd PBXNativeTarget section\n')
        self.write('Smoke.xctestplan', '{"identifier":"' + identifier + '"}\n')
        self.write('project.yml', canonical)
        self.write('Trinket.xcodeproj/project.pbxproj', canonical)
        self.git('add', '.')
        self.git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'push fixture')
        for changed, drift, expected_calls, status in (
            ('code.swift', False, 0, 0), ('project.yml', False, 1, 0),
            ('project.yml', True, 1, 1),
        ):
            with self.subTest(changed=changed, drift=drift):
                calls = self.root / 'calls'
                calls.unlink(missing_ok=True)
                path = self.root / changed
                path.write_text(path.read_text() + '\n')
                if changed == 'project.yml' and not drift:
                    self.write('Trinket.xcodeproj/project.pbxproj', path.read_text())
                self.git('add', changed, 'Trinket.xcodeproj/project.pbxproj')
                self.git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'push case')
                result = self.run_command('bash', '.githooks/pre-push', expected=status)
                count = len(calls.read_text().splitlines()) if calls.exists() else 0
                self.assertEqual(count, expected_calls, result.stdout + result.stderr)
                if drift:
                    self.assertIn('Generated output is stale or uncommitted', result.stderr)

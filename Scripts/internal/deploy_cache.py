"""Content-scoped local UI evidence; never substitutes for exact-commit hosted CI."""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess

from internal.cli import write_json_atomic
from internal.ui_registration import registrations


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


class Inputs:
    def __init__(self, root, identity):
        self.root = root
        self.environment = {key: value for key, value in identity.items() if key != 'root'}
        self.environment['build'] = {key: value for key, value in identity['build'].items() if key != 'commit'}
        self.environment['profile'] = identity['profile']
        self.environment['settings'] = {key: value for key, value in os.environ.items()
            if key.startswith('TRINKET_') and not key.startswith(('TRINKET_DEPLOY_', 'TRINKET_TESTFLIGHT_', 'TRINKET_CI_WAIT_'))
            and key not in ('TRINKET_DIAGNOSTICS_SESSION_ID', 'TRINKET_RUN_ID')}
        rows = subprocess.check_output(['git', '-C', str(root), 'ls-tree', '-r', '-z', 'HEAD']).split(b'\0')
        self.files = {}
        for row in filter(None, rows):
            metadata, path = row.split(b'\t', 1)
            self.files[path.decode()] = metadata.decode()
        registered = {row['name']: row['suite'] for row in registrations(root)}
        self.classes, self.shared = {}, set()
        for path in self.files:
            if not path.startswith('TrinketUITests/') or not path.endswith('.swift'):
                continue
            text = (root / path).read_text()
            names = re.findall(r'^\s*(?:final\s+)?class\s+(\w+)\s*:', text, re.M)
            for name in names:
                if name in registered:
                    if name in self.classes:
                        raise ValueError(f'Duplicate UI class: {name}')
                    self.classes[name] = path
            # Helpers can live outside Support (e.g. AudioLifecycle extensions).
            # Unknown or shared declarations invalidate every UI phase conservatively.
            if (not names or any(name not in registered for name in names)
                    or re.search(r'^\s*extension\s|^(?:(?:public|private|fileprivate|internal)\s+)*(?:func|struct|enum|typealias|let|var)\s', text, re.M)):
                self.shared.add(path)
        self.allowed = {name for name, suite in registered.items() if suite in ('Smoke', 'FullUI')}
        self.smoke = {name for name, suite in registered.items() if suite == 'Smoke'}
        owned = set(self.classes.values())
        product = {path: blob for path, blob in self.files.items()
                   if not path.endswith('.md') and not path.startswith('Docs/')
                   and not (path.startswith('Packages/') and '/Tests/' in path)
                   and path not in owned}
        self.product = digest(product)

    def key(self, phase):
        if not phase.startswith('ui:'):
            return None
        selector = phase.removeprefix('ui:')
        name = selector.split('/')[0]
        if name not in self.allowed or name not in self.classes:
            return None
        selected = {self.classes[name], *self.shared}
        # Include any other registered test class explicitly referenced by helpers.
        pending = list(selected)
        while pending:
            text = (self.root / pending.pop()).read_text()
            for other, path in self.classes.items():
                if path not in selected and re.search(rf'\b{re.escape(other)}\b', text):
                    selected.add(path)
                    pending.append(path)
        return digest(dict(schema=1, phase=phase, product=self.product, environment=self.environment,
                           tests={path: self.files[path] for path in sorted(selected)}))

    def changed_cases(self, paths):
        if paths is None:
            return []
        changed = set(paths)
        direct = sorted(name for name, path in self.classes.items() if name in self.allowed and path in changed)
        if changed.intersection(self.shared) or any(
                path.startswith('TrinketUITests/') and path not in self.classes.values() for path in changed):
            return list(dict.fromkeys(direct + sorted(self.smoke)))
        return direct


class PhaseCache:
    def __init__(self, root: Path, inputs: Inputs):
        self.root, self.inputs = root, inputs

    def path(self, phase, suffix):
        return self.root / f'{digest(phase)}{suffix}.json'

    def read(self, path):
        try:
            value = json.loads(path.read_text())
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError):
            return {}

    def proof(self, phase):
        key = self.inputs.key(phase)
        if key is None:
            return None
        value = self.read(self.path(phase, f'-{key}'))
        if value.get('schema') == 1 and value.get('phase') == phase and value.get('key') == key:
            result = value.get('result')
            if (isinstance(result, dict) and result.get('evidence') == 'local'
                    and isinstance(result.get('commit'), str) and re.fullmatch(r'[a-f0-9]{40,64}', result['commit'])
                    and type(result.get('seconds')) in (int, float) and math.isfinite(result['seconds']) and result['seconds'] >= 0):
                return result
        return None

    def failed_cases(self):
        cases = []
        for path in self.root.glob('*-failed.json'):
            value = self.read(path)
            phase = value.get('phase', '')
            if value.get('schema') != 1 or not isinstance(phase, str):
                continue
            # Only the authored functional registry can select executable test targets.
            selector = phase.removeprefix('ui:')
            if (phase.startswith('ui:') and re.fullmatch(r'\w+(?:/test\w+)?', selector)
                    and selector.split('/')[0] in self.inputs.allowed):
                cases.append(selector)
        return sorted(set(cases))

    def failed(self, phase):
        key = self.inputs.key(phase)
        if key is None:
            return
        self.root.mkdir(parents=True, exist_ok=True)
        owner = phase.split('/')[0]
        for path in self.root.glob('*.json'):
            saved = self.read(path)
            if isinstance(saved.get('phase'), str) and saved['phase'].split('/')[0] == owner and 'result' in saved:
                path.unlink(missing_ok=True)
        write_json_atomic(self.path(owner, '-failed'), dict(schema=1, phase=owner, key=key))

    def passed(self, phase, result, previous_failure):
        key = self.inputs.key(phase)
        if key is None:
            return
        self.root.mkdir(parents=True, exist_ok=True)
        write_json_atomic(self.path(phase, f'-{key}'), dict(schema=1, phase=phase, key=key, result=result))
        failure = self.path(phase, '-failed')
        if self.read(failure) == previous_failure:
            failure.unlink(missing_ok=True)

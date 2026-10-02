"""On-demand lexical invocation hints; no type resolution or persistent index."""

from __future__ import annotations

import ast
from pathlib import Path

from internal.cli import ROOT
from internal.source_declarations import source_declarations
from internal.swift_policy import formatter_tokens


def invocation_lines(path: Path, source: str, symbol: str) -> list[int]:
    if path.suffix == '.py':
        return sorted({node.lineno for node in ast.walk(ast.parse(source))
                       if isinstance(node, ast.Call) and
                       ((isinstance(node.func, ast.Name) and node.func.id == symbol) or
                        (isinstance(node.func, ast.Attribute) and node.func.attr == symbol))})
    tokens = []
    comments, strings, line = [], [], 1
    for token in formatter_tokens(source, ROOT):
        kind, value = token['type'], token['string']
        start = line
        line += value.count('\n')
        if comments:
            if kind == 'startOfScope' and value == '/*':
                comments.append(value)
            elif (kind == 'endOfScope' and value == '*/') or (kind == 'linebreak' and comments[-1] == '//'):
                comments.pop()
            continue
        if strings:
            if kind == 'startOfScope' and '"' in value:
                strings.append(value)
            elif kind == 'endOfScope' and '"' in value:
                strings.pop()
            continue
        if kind == 'startOfScope' and value in {'//', '/*'}:
            comments.append(value)
        elif kind == 'startOfScope' and '"' in value:
            strings.append(value)
            tokens.append(('literal', '<string>', start))
        elif kind not in {'space', 'linebreak', 'commentBody'}:
            tokens.append((kind, value, start))
    return sorted({number for index, (kind, value, number) in enumerate(tokens[:-1])
                   if kind == 'identifier' and value.strip('`') == symbol
                   and tokens[index + 1][1] == '('
                   and (index == 0 or tokens[index - 1][1] not in {'func', 'macro'})})


def caller_rows(root: Path, files: list[str], symbol: str) -> list[str]:
    rows = []
    for name in files:
        path = root / name
        if path.suffix not in {'.swift', '.py'}:
            continue
        source = path.read_text(encoding='utf-8')
        calls = invocation_lines(path, source, symbol)
        if not calls:
            continue
        declarations = source_declarations(path, source)
        for line in calls:
            enclosing = [entry for entry in declarations if entry.start <= line <= entry.end]
            owner = min(enclosing, key=lambda entry: (entry.end - entry.start, -entry.start)) if enclosing else None
            context = f'{owner.name} [{owner.start}:{owner.end}]' if owner else 'file scope'
            rows.append(f'{name}:{line}: {context}')
    return rows

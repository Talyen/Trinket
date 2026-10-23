"""On-demand lexical invocation hints; no type resolution or persistent index."""

from __future__ import annotations

import ast
from pathlib import Path

from internal.source_declarations import source_declarations, swift_code_tokens


def invocation_lines(path: Path, source: str, symbol: str, *, tokens=None) -> list[int]:
    if path.suffix == '.py':
        return sorted({node.lineno for node in ast.walk(ast.parse(source))
                       if isinstance(node, ast.Call) and
                       ((isinstance(node.func, ast.Name) and node.func.id == symbol) or
                        (isinstance(node.func, ast.Attribute) and node.func.attr == symbol))})
    tokens = swift_code_tokens(source) if tokens is None else tokens
    return sorted({number for index, (kind, value, number, _, _) in enumerate(tokens[:-1])
                   if kind == 'identifier' and value.strip('`') == symbol
                   and tokens[index + 1][1] == '('
                   and (index == 0 or tokens[index - 1][1] not in {'func', 'macro'})})


def caller_units(root: Path, files: list[str], symbol: str, *, contents: dict[str, str] | None = None):
    """Share invocation discovery between search and the compatibility bundle."""
    for name in files:
        path = root / name
        if path.suffix not in {'.swift', '.py'}:
            continue
        source = contents[name] if contents is not None else path.read_text(encoding='utf-8')
        if symbol not in source:
            continue
        tokens = swift_code_tokens(source) if path.suffix == '.swift' else None
        calls = invocation_lines(path, source, symbol, tokens=tokens)
        if not calls:
            continue
        declarations = source_declarations(path, source, tokens=tokens)
        for line in calls:
            enclosing = [entry for entry in declarations if entry.start <= line <= entry.end]
            owner = min(enclosing, key=lambda entry: (entry.end - entry.start, -entry.start)) if enclosing else None
            yield name, line, owner


def caller_rows(root: Path, files: list[str], symbol: str) -> list[str]:
    return [f'{name}:{line}: ' + (f'{owner.name} [{owner.start}:{owner.end}]' if owner else 'file scope')
            for name, line, owner in caller_units(root, files, symbol)]

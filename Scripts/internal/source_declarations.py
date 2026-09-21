"""Lexical source ranges for navigation, not a semantic symbol index."""
from __future__ import annotations

import ast
import io
import tokenize
from dataclasses import dataclass
from pathlib import Path

from internal.cli import ROOT
from internal.swift_policy import formatter_tokens


@dataclass(frozen=True)
class Declaration:
    name: str
    kind: str
    start: int
    end: int
    signature: str = ''
    documentation: str = ''


def python_signature(source: str) -> str:
    """Stop before a suite or assignment, respecting nested defaults and annotations."""
    lines = source.splitlines(keepends=True)
    depth = 0
    for token in tokenize.generate_tokens(io.StringIO(source).readline):
        if token.type != tokenize.OP:
            continue
        if token.string in {'(', '[', '{'}:
            depth += 1
        elif token.string in {')', ']', '}'}:
            depth -= 1
        elif depth == 0 and token.string in {':', '='}:
            # A colon in an annotated assignment is part of its signature.
            if token.string == ':' and not source.lstrip().startswith(('def ', 'async def ', 'class ')):
                continue
            end = sum(map(len, lines[:token.start[0] - 1])) + token.start[1]
            return source[:end].strip()
    return source.strip()


def documented_start(lines: list[str], start: int) -> int:
    """Include attached comments and attributes, including multiline attributes."""
    cursor = start - 1
    balance = 0
    while cursor > 0:
        text = lines[cursor - 1].strip()
        if not text:
            break
        if balance or (text.endswith(')') and not text.startswith(('//', '/*', '*'))):
            balance += text.count(')') - text.count('(')
            cursor -= 1
            if balance <= 0:
                if not text.startswith('@'):
                    return start
                balance = 0
        elif text.startswith(('///', '//', '/**', '/*', '*', '@', '#')):
            cursor -= 1
        elif text.endswith('*/'):
            cursor -= 1
            while cursor > 0 and '/*' not in lines[cursor]:
                cursor -= 1
        else:
            break
    return cursor + 1 if not balance else start


def python_declarations(source: str, include_locals: bool) -> list[Declaration]:
    lines = source.splitlines()
    found = []

    def visit(node: ast.AST, owner: str = '', local: bool = False):
        kind = None
        names = []
        if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            names = [node.name]
            kind = 'class' if isinstance(node, ast.ClassDef) else 'def'
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            names, kind = [node.target.id], 'var'
        elif isinstance(node, ast.Assign):
            names, kind = [t.id for t in node.targets if isinstance(t, ast.Name)], 'var'
        next_owner, next_local = owner, local
        if kind:
            start = min([node.lineno, *(d.lineno for d in getattr(node, 'decorator_list', []))])
            for name in names:
                qualified = f'{owner}.{name}' if owner else name
                if include_locals or not local:
                    documented = documented_start(lines, start)
                    segment = ast.get_source_segment(source, node)
                    found.append(Declaration(qualified, kind, documented, node.end_lineno,
                                             python_signature(segment),
                                             '\n'.join(lines[documented - 1:node.lineno - 1])))
            if names and kind in {'class', 'def'}:
                next_owner = f'{owner}.{names[0]}' if owner else names[0]
                next_local = local or kind == 'def'
        for child in ast.iter_child_nodes(node):
            visit(child, next_owner, next_local)
    visit(ast.parse(source))
    return sorted(found, key=lambda entry: (entry.start, entry.name))


def swift_declarations(source: str, include_locals: bool) -> list[Declaration]:
    # Retain scope tokens, but make strings/comments opaque. Braces and keywords
    # inside literals (including interpolation) cannot delimit declarations.
    raw = formatter_tokens(source, ROOT)
    tokens, offsets = [], []
    offset = 0
    line, comments, strings = 1, [], []
    for token in raw:
        kind, value = token['type'], token['string']
        token_offset = offset
        offset += len(value)
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
                if not strings:
                    tokens[-1] = ('literal', '<string>', tokens[-1][2], line)
            continue
        if kind == 'startOfScope' and value in {'//', '/*'}:
            comments.append(value)
        elif kind == 'startOfScope' and '"' in value:
            strings.append(value)
            tokens.append(('literal', '<string>', start, line))
            offsets.append(token_offset)
        elif kind not in {'space', 'linebreak', 'commentBody'}:
            tokens.append((kind, value, start, line))
            offsets.append(token_offset)
    pairs, stack = {}, []
    for i, (kind, value, _, _) in enumerate(tokens):
        if kind == 'startOfScope' and value in {'{', '(', '[', '<'}:
            stack.append((value, i))
        elif kind == 'endOfScope' and value in {'}', ')', ']', '>'}:
            if not stack or stack[-1][0] != {'}': '{', ')': '(', ']': '[', '>': '<'}[value]:
                raise ValueError('unbalanced Swift scopes; use an explicit source range')
            _, opening = stack.pop()
            pairs[opening] = i
    if stack:
        raise ValueError('unclosed Swift scope; use an explicit source range')
    types = {'struct', 'class', 'enum', 'actor', 'protocol', 'extension'}
    declarations = types | {'func', 'typealias', 'associatedtype', 'init', 'deinit', 'subscript', 'var', 'let'}
    modifiers = {'public', 'private', 'fileprivate', 'internal', 'package', 'open', 'static', 'final',
                 'override', 'nonisolated', 'mutating', 'nonmutating', 'required', 'convenience', 'indirect'}
    lines = source.splitlines()
    line_offsets = [0]
    for line_text in source.splitlines(keepends=True):
        line_offsets.append(line_offsets[-1] + len(line_text))
    found = []

    def scan(begin: int, stop: int, owner: str = '', local: bool = False):
        i = begin
        while i < stop:
            kind, value, number, _ = tokens[i]
            if i in pairs:
                if value == '{':
                    scan(i + 1, pairs[i], owner, True)
                i = pairs[i] + 1
                continue
            if kind != 'keyword' or value not in declarations or (
                value == 'class' and i + 1 < stop and tokens[i + 1][1] in {'func', 'var', 'subscript'}
            ):
                i += 1
                continue
            name_index = i + 1
            if value in {'init', 'deinit', 'subscript'}:
                name, name_index = value, i
            elif name_index < stop and tokens[name_index][0] in {'identifier', 'operator', 'keyword'}:
                name = tokens[name_index][1].strip('`')
            else:
                i += 1
                continue
            if value == 'extension':
                while name_index + 2 < stop and tokens[name_index + 1][1] == '.':
                    name += '.' + tokens[name_index + 2][1].strip('`')
                    name_index += 2
            qualified = f'{owner}.{name}' if owner else name
            j, body, last = name_index + 1, None, name_index
            signature_end = None
            while j < stop:
                next_kind, next_value, next_line, _ = tokens[j]
                previous = tokens[last]
                if next_value in {';', '}'}:
                    break
                if next_line > previous[3]:
                    starts_declaration = next_value in declarations | modifiers or next_value.startswith('@')
                    continued = previous[1] in {'=', ',', ':', '->', '.', 'where'} or next_value in {'.', '{', 'where', '->', ':', '='}
                    if starts_declaration or (value in {'let', 'var', 'typealias', 'associatedtype'} and not continued):
                        break
                if j in pairs:
                    last = pairs[j]
                    if next_value == '{':
                        if signature_end is None:
                            signature_end = offsets[j]
                        body = j
                        j = last + 1
                        if value in {'var', 'let'}:
                            # Stored closure values can be immediately invoked or
                            # followed by a multiline call chain. Keep that tail.
                            continue
                        break
                    j = last + 1
                else:
                    if next_value == '=' and value in {'var', 'let'} and signature_end is None:
                        signature_end = offsets[j]
                    last, j = j, j + 1
            start = documented_start(lines, number)
            if include_locals or not local:
                if signature_end is None:
                    signature_end = offsets[j] if j < stop else line_offsets[tokens[last][3]]
                # Include same-line modifiers; nested one-line declarations begin after the enclosing brace.
                signature_start = line_offsets[number - 1]
                prior = source[signature_start:offsets[i]]
                if '{' in prior or ';' in prior:
                    signature_start += max(prior.rfind('{'), prior.rfind(';')) + 1
                found.append(Declaration(qualified, value, start, tokens[last][3],
                                         source[signature_start:signature_end].strip(),
                                         '\n'.join(lines[start - 1:number - 1])))
            if body is not None:
                scan(body + 1, pairs[body], qualified, local or value not in types)
            i = max(j, i + 1)
    scan(0, len(tokens))
    return sorted(found, key=lambda entry: (entry.start, entry.name))


def source_declarations(path: Path, source: str, include_locals: bool = False) -> list[Declaration]:
    return python_declarations(source, include_locals) if path.suffix == '.py' else swift_declarations(source, include_locals)

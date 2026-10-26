"""Shared file ownership, guidance, and structured verification plans."""
from __future__ import annotations

from dataclasses import dataclass, field
import os
from pathlib import Path
import re
import shlex
import subprocess

from internal.agent_status import changes
from internal.cli import ROOT
from internal.ui_registration import registrations
from internal.path_matching import matches
from internal.source_ownership import build_inputs, generated_paths


def beneath(path: str, roots: tuple[str, ...]) -> bool:
    return any(path == entry or path.startswith(entry + '/') for entry in roots)


def normalize_paths(paths: list[str], root: Path = ROOT) -> list[str]:
    normalized = []
    for raw in paths:
        if not raw or any(char in raw for char in '\n\r\0'):
            raise ValueError('--paths requires non-empty single-line paths')
        path = (root / raw).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError(f'--paths must stay within the repository: {raw}')
        if path.is_dir():
            raise ValueError(f'--paths requires individual files, not directories: {raw}')
        normalized.append(path.relative_to(root.resolve()).as_posix())
    return sorted(set(normalized))


def task_ancestor(base: str, root: Path) -> str:
    revision = subprocess.check_output(
        ['git', 'rev-parse', '--verify', '--end-of-options', base + '^{commit}'], cwd=root, text=True).strip()
    return subprocess.check_output(['git', 'merge-base', revision, 'HEAD'], cwd=root, text=True).strip()


def collect_paths(paths: list[str] | None, root: Path = ROOT, *, base: str | None = None) -> list[str]:
    if base is not None:
        if paths is not None:
            raise ValueError('--base cannot combine with --paths')
        # Include committed work and both dirty endpoints, even if a later edit
        # undoes a committed change. Never silently fall back after a Git error.
        ancestor = task_ancestor(base, root)
        committed = subprocess.check_output(
            ['git', 'diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', ancestor, 'HEAD', '--'], cwd=root)
        dirty = {path for entry in changes(root) for path in (entry.path, entry.original) if path}
        return normalize_paths([*(os.fsdecode(path) for path in committed.split(b'\0') if path), *dirty], root)
    if paths is not None:
        return normalize_paths(paths, root)
    return sorted({path for entry in changes(root) for path in (entry.path, entry.original) if path})


# Guidance follows stable owners. Behavior depth is read on demand; renaming a
# source leaf must not silently change its contracts.
ACTION = 'Docs/AgentContext/battle-actions.md'
PRESENTATION = 'Docs/AgentContext/battle-presentation.md'
STORAGE = 'Docs/AgentContext/persistence-storage.md'
CONTENT = 'Docs/AgentContext/content-and-manifests.md'
PROGRESSION = 'Docs/AgentContext/persistence-progression.md'
RUNTIME = 'Docs/AgentContext/battle-runtime.md'
LAUNCH = 'Docs/AgentContext/battle-launch.md'
ENGINE = 'Docs/AgentContext/battle-engine.md'
PERSISTENCE = 'Docs/AgentContext/persistence.md'
BALANCE = 'Docs/AgentContext/battle-balance.md'
UI = 'Docs/AgentContext/swiftui-features.md'
UI_PERFORMANCE = 'Docs/AgentContext/ui-performance.md'
AUDIO = 'Docs/AgentContext/audio.md'
TALENTS = 'Docs/AgentContext/battle-talents.md'


def sections(document: str, *names: str) -> tuple[str, ...]:
    return tuple(document + '#' + name for name in names)


OWNER_GUIDANCE = (
    (('Packages/BattleEngine',), (ENGINE, ACTION, 'Docs/AgentContext/battle-damage.md', 'Docs/AgentContext/battle-healing.md')),
    (('Packages/BattleEngine/Sources/BattleBalanceTools', 'Packages/BattleEngine/Sources/BalanceSweepCLI'), (BALANCE,)),
    (('Packages/TrinketPersistence',), (PERSISTENCE, STORAGE, PROGRESSION)),
    (('Packages/TrinketBattleFeature',), (RUNTIME, PRESENTATION, LAUNCH)),
    (('Packages/TrinketAppState/Sources/TrinketAppState/Play', 'Packages/TrinketAppState/Sources/TrinketAppState/App',
      'Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts',
      'Packages/BattleEngine/Sources/BattleEngine/Runtime', 'Trinket/App'), (RUNTIME, LAUNCH)),
    (('Packages/TrinketAppState/Sources/TrinketAppState/Audio',), (AUDIO,)),
    (('Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork', 'Trinket/App', 'Trinket/Features/Collection'), (UI_PERFORMANCE,)),
)
CONTENT_GUIDANCE = (
    (('ContentManifest',), sections(CONTENT, 'manifests')),
    (('Packages/TrinketContent/Sources/TrinketContent/Abilities',), sections(CONTENT, 'abilities')),
    (('ArtManifest', 'MusicManifest', 'SoundManifest', 'Raw Assets', 'AssetSources', 'Trinket/Assets.xcassets', 'Trinket/Media'), sections(CONTENT, 'media-assets')),
    (('Scripts/internal/content',), sections(CONTENT, 'generation-tooling')),
)
VISUAL_PATHS = ('Trinket/Features/*', 'Packages/TrinketBattleFeature/Sources/*/Features/*', 'Packages/TrinketBattleFeature/Sources/*/Views/*', 'Packages/TrinketFeatureSupport/Sources/*/Features/*', 'Packages/TrinketFeatureSupport/Sources/*/FeatureAdapters/*', *(f'Packages/TrinketFeatureSupport/Sources/*/Shared/{part}/*' for part in ('Cards', 'Detail', 'Forms', 'Encounters', 'Rewards')), 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/*')
BEHAVIOR_CARDS = {ACTION, PRESENTATION, STORAGE, PROGRESSION, BALANCE, LAUNCH, UI_PERFORMANCE, TALENTS, 'Docs/AgentContext/battle-damage.md', 'Docs/AgentContext/battle-healing.md'}


def guidance_references() -> set[str]:
    references = {'Docs/Platform/Localization.md', CONTENT, PERSISTENCE, RUNTIME, LAUNCH, ENGINE, BALANCE, UI, UI_PERFORMANCE, AUDIO, TALENTS, UI + '#interaction-constraints', *sections(CONTENT, 'shared-safeguards', 'project-generation', 'generation-tooling')}
    for _, values in (*OWNER_GUIDANCE, *CONTENT_GUIDANCE):
        references.update(values)
    return references


@dataclass
class Route:
    paths: list[str]
    authored: list[str] = field(default_factory=list)
    generated: list[str] = field(default_factory=list)
    packages: list[str] = field(default_factory=list)
    cards: list[str] = field(default_factory=list)
    guides: list[str] = field(default_factory=list)
    skills: list[str] = field(default_factory=list)
    knowledge: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    generated_warnings: list[str] = field(default_factory=list)
    smoke_targets: list[str] = field(default_factory=list)
    needs: set[str] = field(default_factory=set)
    features: set[str] = field(default_factory=set)
    smoke_unresolved: bool = False
    compile_reasons: list[str] = field(default_factory=list)

    def add(self, collection: str, *values: str) -> None:
        target = getattr(self, collection)
        for value in values:
            if collection == 'cards':
                name = value.partition('#')[0]
                if name in target:
                    continue
                if '#' not in value:
                    target[:] = [item for item in target if item.partition('#')[0] != name]
            if value not in target:
                target.append(value)



def classify(paths: list[str], root: Path = ROOT, *, base: str | None = None) -> Route:
    route = Route(paths)
    comparison = task_ancestor(base, root) if base is not None else 'HEAD'
    arrays = build_inputs(root / 'Scripts')
    packages = arrays['TRINKET_TEST_PACKAGES']
    smoke = {row['key']: row['name'] for row in registrations(root) if row['suite'] == 'Smoke'}
    scripts = root / 'Scripts'
    has_registry = (scripts / 'config/generated-paths.tsv').exists()
    generated_roots = generated_paths(scripts, ('content', 'asset')) if has_registry else ()
    asset_roots = generated_paths(scripts, ('asset',)) if has_registry else ()

    def add_smoke(path: str) -> None:
        key = None
        if matches(path, 'Trinket/Features/Monetization/*'): key = 'MONETIZATION'
        elif matches(path, 'Packages/TrinketBattleFeature/Sources/*', 'TrinketUITests/Battle/*'): key = 'BATTLE'
        elif matches(path, 'Trinket/Features/Collection/*', 'Trinket/Features/Homestead/*', 'Trinket/Features/Options/*', 'TrinketUITests/Collection/*', 'TrinketUITests/Support/*'): key = 'SHELL'
        elif matches(path, *(f'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/{name}' for name in ('Accessibility/AccessibilityID.swift', 'Artwork/PreparedArtworkCache.swift', 'Artwork/PreparedArtwork.swift'))): key = 'SHELL'
        elif matches(path, 'Trinket/Features/Play/Shop/*'): key = 'SHOP'
        elif matches(path, 'Trinket/Features/Onboarding/*'): key = 'SHELL'
        elif matches(path, 'Trinket/Features/Play/*', 'TrinketUITests/Play/*'): key = 'SHELL'
        elif matches(path, 'TrinketUITests/Smoke/*.swift'):
            route.add('smoke_targets', Path(path).stem)
            return
        if key is None: route.smoke_unresolved = True
        else: route.add('smoke_targets', smoke[key])

    for path in paths:
        package = path.split('/')[1] if path.startswith('Packages/') else ''
        if path.endswith('.md'):
            route.needs.add('docs'); route.authored.append(path)
        else:
            for kind, name in (('content', 'TRINKET_CONTENT_GENERATION_INPUTS'), ('assets', 'TRINKET_ASSET_GENERATION_INPUTS')):
                if beneath(path, arrays[name]): route.features.add(kind); route.needs.add(kind)
            if matches(path, *arrays['TRINKET_PROJECT_GENERATION_INPUTS']): route.features.add('project'); route.needs.add('project')
            if path in {'.swiftlint.yml', '.swiftformat', 'Scripts/tool-versions.env', 'Scripts/format-dirs.env', 'Scripts/build-inputs.env'}:
                route.needs.add('style'); route.authored.append(path)
                continue
            if beneath(path, tuple(generated_roots)) or matches(path, '*/Generated/*', '*.generated.*', 'Trinket/Assets.xcassets/*', 'Trinket/Media/*'):
                route.generated.append(path)
                if beneath(path, tuple(asset_roots)):
                    route.needs.add('assets'); route.add('generated_warnings', 'Prepared asset output detected; edit the manifest/AssetSources source and run ./Scripts/prepare-assets.sh.')
                elif matches(path, 'Packages/*/Generated/*'):
                    if matches(path, 'Packages/*/Generated/*SourceHashes.generated.tsv'):
                        route.needs.add('assets'); route.add('generated_warnings', 'Generated asset hash state detected; edit the manifest/AssetSources source and run ./Scripts/generate.sh --assets.')
                    else:
                        route.needs.add('content'); route.add('generated_warnings', 'Generated package output detected; edit the authored source and run ./Scripts/generate.sh.')
                else:
                    route.needs.add('assets'); route.add('generated_warnings', 'Processed app output detected; edit the manifest/AssetSources source and run the appropriate generation command.')
            else:
                route.authored.append(path)
                if path.endswith('.swift') and package:
                    route.needs.add('style')
                    if package in packages:
                        route.add('packages', package)
                    if matches(path, 'Packages/TrinketContent/Sources/TrinketContent/Abilities/*.swift'): route.features.add('content'); route.needs.add('content')
                    if matches(path, 'Packages/TrinketContent/Sources/TrinketContentTestSupport/*'): route.add('packages', 'BattleEngine', 'TrinketAppState', 'TrinketBattleFeature', 'TrinketFeatureSupport')
                    if package == 'TrinketDesignSystem' and '/Sources/' in path: route.add('skills', '.agents/skills/apple-design/SKILL.md')
                    if package == 'TrinketFeatureSupport' and matches(path, *(f'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/{name}' for name in ('Accessibility/AccessibilityID.swift', 'Artwork/PreparedArtworkCache.swift', 'Artwork/PreparedArtwork.swift'))): route.needs.add('smoke'); add_smoke(path)
                    if package == 'TrinketBattleFeature': route.features.add('feature'); route.needs.add('smoke'); add_smoke(path)
                    if package == 'TrinketAppState' and '/Audio/' in path: route.features.add('audio'); route.needs.add('smoke'); route.add('smoke_targets', smoke['SHELL'])
                elif path == 'project.yml': route.features.add('project'); route.needs.add('project')
                elif matches(path, 'Trinket/App/*'): route.needs.update(('style', 'build'))
                elif matches(path, 'Scripts/*', '.github/*', '.githooks/*', 'Gemfile', 'Gemfile.lock'): route.needs.add('scripts')
                elif matches(path, 'Docs/*'): route.needs.add('docs')
                elif matches(path, 'Trinket/Features/*', 'TrinketUITests/*'): route.needs.update(('style', 'smoke')); route.features.add('feature'); add_smoke(path)
                elif path.endswith('.swift'): route.needs.add('style')
                elif matches(path, 'project.pbxproj', '*/project.pbxproj'):
                    route.needs.update(('project', 'content')); route.add('warnings', 'project.pbxproj is generated/protected; edit project.yml and run ./Scripts/generate.sh instead.')
            if package:
                warnings = {'TrinketDesignSystem': 'TrinketDesignSystem may depend on TrinketCore only; keep app, BattleEngine, and TrinketContent imports out.', 'TrinketFeatureSupport': 'TrinketFeatureSupport must stay below TrinketBattleFeature and TrinketAppState in the package DAG.', 'TrinketBattleFeature': 'TrinketBattleFeature must not import or depend on TrinketAppState.'}
                route.add('warnings', warnings.get(package, 'Packages must not import the Trinket app; keep dependencies within the enforced package DAG.'))

    if route.needs & {'assets', 'project'}: route.needs.add('content')
    if route.features & {'content', 'assets'}:
        route.add('cards', *sections(CONTENT, 'shared-safeguards'))
        for path in paths:
            for owners, references in CONTENT_GUIDANCE:
                if beneath(path, owners): route.add('cards', *references)
            if matches(path, 'Scripts/content_codegen.py', 'Scripts/internal/content/*', 'Scripts/generate.sh', 'Scripts/assert-generated-output.sh', 'Scripts/config/generated-paths.tsv', 'Packages/TrinketContent/Package.swift'): route.add('cards', *sections(CONTENT, 'generation-tooling'))
    if 'TrinketPersistence' in route.packages: route.add('cards', PERSISTENCE)
    if 'audio' in route.features: route.add('cards', AUDIO)
    if any(matches(path, 'Scripts/balance-sweep.sh', 'Packages/BattleEngine/*Balance*') for path in paths): route.add('cards', BALANCE)
    if 'project' in route.features: route.add('cards', *sections(CONTENT, 'shared-safeguards', 'project-generation'))
    for path in paths:
        if path.endswith('.swift'):
            tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', path], cwd=root, capture_output=True).returncode == 0
            diff = subprocess.check_output(['git', 'diff', '--no-ext-diff', '--unified=0', comparison, '--', path], cwd=root, text=True) if tracked else (root / path).read_text() if (root / path).is_file() else ''
            if re.search(r'//.*(swiftlint:|swiftformat:|[A-Za-z]+Check:\s*allow|Concurrency-Safety:)', diff): route.add('skills', '.agents/skills/doc-budget/SKILL.md')
            # A changed enum case can break external exhaustive switches without
            # changing a line containing "public". Treat API-bearing files broadly.
            source = (root / path).read_text() if (root / path).is_file() else ''
            if diff and re.search(r'\b(?:public|open)\b', diff + '\n' + source):
                declaration_change = re.search(
                    r'^[-+](?![-+])\s*(?:@[\w.]+(?:\([^\n]*?\))?\s+)*'
                    r'(?:(?:nonisolated|final|static|override)\s+)*(?:public|open)\s+'
                    r'(?:(?:final|static|class|nonisolated|override|mutating|private\(set\))\s+)*'
                    r'(?:actor|class|struct|enum|protocol|func|var|let|typealias|init|subscript|case)\b',
                    diff, re.MULTILINE)
                route.features.add('public-api' if declaration_change else 'api-consumer-check')
                route.compile_reasons.append(f'{path}: ' + ('public declaration changed' if declaration_change
                    else 'conservative consumer check: implementation changed in an API-bearing file'))
            public = r'(public\s+(actor|class|enum|struct|protocol|typealias)|(^|\s)protocol\s|@Model|[A-Za-z0-9_]+Schema|@attached)'
            if re.search(r'^\+(?!\+).*' + public if tracked else public, diff, re.MULTILINE): route.add('skills', '.agents/skills/architect/SKILL.md'); route.add('knowledge', '.agents/knowledge/patterns/module-dag-containment.md')
        for owners, references in OWNER_GUIDANCE:
            if beneath(path, owners): route.add('cards', *references)
        if path.startswith('ContentManifest/') and Path(path).stem == 'talents': route.add('cards', TALENTS)
        if path.endswith('/Package.swift'): route.add('knowledge', '.agents/knowledge/patterns/module-dag-containment.md')
        for parent in (root / path).parents:
            if parent == root: break
            if (parent / 'AGENTS.md').is_file(): route.add('guides', (parent / 'AGENTS.md').relative_to(root).as_posix())
    if any(matches(path, 'Localization/*', '*.xcstrings', 'Scripts/*localization*', 'Scripts/internal/localization*') for path in paths): route.add('cards', 'Docs/Platform/Localization.md')
    if any(matches(path, *VISUAL_PATHS) for path in paths):
        route.add('skills', '.agents/skills/apple-design/SKILL.md', '.agents/skills/swiftui-specialist/SKILL.md')
        route.add('cards', UI)
    return route


@dataclass(frozen=True)
class Check:
    id: str
    label: str
    argv: tuple[str, ...]
    environment: tuple[tuple[str, str], ...] = ()
    deferred: bool = False

    @property
    def command(self) -> str:
        return shlex.join([*(f'{key}={value}' for key, value in self.environment), *self.argv])


def lightweight(environment: dict[str, str]) -> bool:
    return environment.get('GITHUB_ACTIONS') != 'true' and environment.get('TRINKET_ALLOW_HEAVY_LOCAL') != '1'


def verification_plan(route: Route, *, root: Path = ROOT, environment: dict[str, str] | None = None, smoke: bool = False, final: bool = False, keep_plan: bool = False, mirror: bool = False) -> list[Check]:
    environment = os.environ if environment is None else environment
    local = lightweight(environment)
    checks = []
    def add(identifier: str, label: str, *argv: str, heavy: bool = False, env: tuple = ()) -> None:
        checks.append(Check(identifier, label, tuple(argv), env, local and heavy))
    if final: add('docs-final', 'final documentation check', 'python3', './Scripts/check-docs.py', '--final', *(['--keep-plan'] if keep_plan else []), '--paths', *route.paths)
    if route.needs & {'content', 'assets', 'project'}:
        assets = 'assets' in route.needs and not local
        add('generate', 'generation', './Scripts/generate.sh', *(['--assets'] if assets else []), heavy=True)
        add('assert', 'generated idempotence', './Scripts/assert-generated-output.sh', '--idempotent', *(['--assets'] if assets else []), heavy=True)
    if 'style' in route.needs:
        swift = [path for path in route.authored if path.endswith('.swift') and (root / path).is_file()]
        full_style = any(matches(path, '.swiftlint.yml', '.swiftformat', 'Scripts/tool-versions.env', 'Scripts/format-dirs.env', 'Scripts/build-inputs.env', 'Scripts/*', '.github/*') for path in route.paths)
        add('style', 'style', './Scripts/test.sh', 'style', *(swift if local or not full_style else []), heavy=local and not swift)
    if 'scripts' in route.needs:
        if local:
            add('scripts-syntax', 'script syntax', './Scripts/test-scripts.sh', '--syntax-only', '--paths', *route.paths)
        flag = ['--skip-docs'] if final or 'docs' in route.needs else []
        add('scripts', 'script regressions', './Scripts/test-scripts.sh', *flag, '--paths', *route.paths, heavy=True)
    if not final and ('docs' in route.needs or local and 'scripts' in route.needs):
        add('docs', 'documentation', 'python3', './Scripts/check-docs.py', *(['--paths', *route.paths] if local else []))
    if route.packages: add('package', 'package tests', './Scripts/test-package.sh', *route.packages, heavy=True, env=(('SKIP_GENERATE', '1'),))
    if 'build' in route.needs or 'feature' in route.features and (not route.smoke_targets or not smoke):
        add('build', 'app compilation', './Scripts/build.sh', heavy=True, env=(('SKIP_GENERATE', '1'),))
    if 'smoke' in route.needs and smoke and route.smoke_targets:
        add('smoke', 'UI smoke', './Scripts/test.sh', 'smoke', *route.smoke_targets, heavy=True, env=(('SKIP_GENERATE', '1'),))
    if local and 'assets' in route.needs: add('assets', 'prepared asset integrity', './Scripts/ci-assets-gate.sh')
    style_checked = any(check.id == 'style' and not check.deferred for check in checks)
    config = Path(environment.get('TRINKET_CHEAP_SLICES_CONFIG', 'Scripts/config/cheap-slices.txt'))
    if not config.is_absolute(): config = root / config
    # Unknown input owners retain all slices, including in mixed scopes.
    known = all(path.endswith('.md') or
                path.startswith(('Packages/', 'Trinket/', 'TrinketUITests/', 'Scripts/',
                                 'Localization/', 'ContentManifest/', 'ArtManifest/',
                                 'MusicManifest/', 'SoundManifest/', 'ReleaseNotes/', '.github/')) or
                path in {'project.yml', 'Gemfile', 'Gemfile.lock', '.swiftlint.yml', '.swiftformat', 'cliff.toml'}
                for path in route.paths)
    count = 0
    for line in config.read_text().splitlines():
        command, _, flags = line.partition('#')
        if not command.strip(): continue
        count += 1
        if style_checked and 'skip-when-style-checked' in flags: continue
        local_paths = re.search(r'(?:^|\s)local-paths=(\S+)', flags)
        # CI retains the complete registry. Unknown non-document inputs keep all
        # slices; known routes select by the check's declared input surface.
        if local and known and local_paths:
            patterns = local_paths[1].split(',')
            inputs = [path for path in route.paths if not path.endswith('.md') or path in patterns]
            if not any(matches(path, *patterns) for path in inputs): continue
        lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|<>')
        lexer.whitespace_split = True
        argv = list(lexer)
        if any(token in {';', '&&', '||', '|', '>', '<'} for token in argv): raise ValueError('Cheap slices must be executable argument lists, not shell expressions')
        if local and argv == ['python3', 'Scripts/localization.py', 'check']:
            argv.extend(['--paths', *route.paths])
        add(f'cheap-{count}', 'cheap CI slice: ' + command.strip(), *argv)
    if not count: raise ValueError('Cheap-slice registry is empty.')
    if mirror and (route.needs & {'build', 'content', 'project'} or route.packages or 'feature' in route.features):
        if local:
            raise ValueError('Simulator mirroring is CI-owned; a bounded local diagnostic requires TRINKET_ALLOW_HEAVY_LOCAL=1')
        add('mirror', 'mirror', './Scripts/promote.sh', '--quiet', heavy=True)
    return checks


def automatic_plan(route: Route, *, root: Path = ROOT, environment: dict[str, str], final: bool = False, keep_plan: bool = False) -> list[Check]:
    """Keep routine local work static, even with an inherited heavy-local flag."""
    planning_environment = environment if environment.get('GITHUB_ACTIONS') == 'true' else {**environment, 'TRINKET_ALLOW_HEAVY_LOCAL': ''}
    checks = verification_plan(route, root=root, environment=planning_environment, smoke=True, final=final, keep_plan=keep_plan)
    if environment.get('GITHUB_ACTIONS') == 'true':
        return checks
    compile_app = ('build' in route.needs or bool(route.features & {'feature', 'public-api', 'api-consumer-check'}) or
                   '.agents/skills/architect/SKILL.md' in route.skills or
                   any(path.endswith('/Package.swift') for path in route.paths))
    selected = []
    for check in checks:
        if check.id == 'package':
            for package in route.packages:
                selected.append(Check('package:' + package, 'package tests: ' + package,
                                      ('./Scripts/test-package.sh', package),
                                      (('SKIP_GENERATE', '1'),), deferred=True))
        elif check.id == 'build':
            # App-only compilation includes unchanged consumers of shared APIs.
            if compile_app:
                selected.append(Check('build', 'app compilation', ('./Scripts/test.sh', 'unit', '--app-only'),
                                      (('SKIP_GENERATE', '1'),), deferred=True))
            else:
                selected.append(check)
        else:
            selected.append(check)
    if compile_app and not any(check.id == 'build' for check in selected):
        selected.append(Check('build', 'app compilation', ('./Scripts/test.sh', 'unit', '--app-only'),
                              (('SKIP_GENERATE', '1'),), deferred=True))
    return selected


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Normalize explicit file scope or list working-tree endpoints.')
    parser.add_argument('--requires', choices=('assets', 'content', 'project'))
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument('--paths', nargs=argparse.REMAINDER)
    scope.add_argument('--working-tree', action='store_true')
    args = parser.parse_args()
    try:
        if args.paths == []:
            raise ValueError('--paths requires at least one file')
        paths = collect_paths(args.paths)
        print(str(args.requires in classify(paths).needs).lower() if args.requires else '\n'.join(paths))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(2, f'Scope failed: {error}\n')

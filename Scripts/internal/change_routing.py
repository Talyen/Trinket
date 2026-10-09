"""Shared file ownership, guidance, and structured verification plans."""
from __future__ import annotations

from dataclasses import dataclass, field
from fnmatch import fnmatchcase
import os
from pathlib import Path
import re
import shlex
import subprocess

from internal.agent_status import changes
from internal.cli import ROOT, read_env_arrays
from internal.ui_registration import registrations


def matches(path: str, *patterns: str) -> bool:
    return any(fnmatchcase(path, pattern) for pattern in patterns)


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


def collect_paths(paths: list[str] | None, root: Path = ROOT) -> list[str]:
    if paths is not None:
        return normalize_paths(paths, root)
    return sorted({path for entry in changes(root) for path in (entry.path, entry.original) if path})


# Ordered, first-match guidance rules. These same definitions are validated by check-docs.
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


def actions(*names: str) -> tuple[str, ...]:
    return sections(ACTION, 'shared-action-invariants', *names)


def presentation(*names: str) -> tuple[str, ...]:
    return sections(PRESENTATION, 'display-lifetime', 'display-work-lifecycle', *names)


def storage(*names: str) -> tuple[str, ...]:
    return sections(STORAGE, 'save-compatibility', 'durable-acceptance-and-recovery', *names)


RUNTIME_RULES = (
    (('*.md',), ()),
    (('*/PlaySession+BattleLaunch.swift', '*/PlaySession+BattleCompletion.swift', '*/PlayBattleLaunch+Configuration.swift', '*/BattleSession+Progression.swift'), (LAUNCH,)),
    (('*/Features/Feedback/*', '*/State/Feedback/*'), presentation('floating-combat-feedback')),
    (('*/Features/BattleAbilityCardView.swift', '*/Features/BattleHandView.swift', '*/Features/BattleFieldLane+CardPlay.swift'), presentation('continuous-card-input', 'card-visibility')),
    (('*/Features/Battlefield/*', '*/Features/Effects/*'), presentation('attack-and-impact-presentation', 'card-visibility')),
    (('*/Features/BattleCombatantProjectionPane.swift', '*/Features/BattleLogSheet.swift', '*/Features/BattleAutoToggle.swift', '*/Features/Layout/*', '*/State/BattleCard*.swift', '*/State/BattlePresentationState.swift', '*/State/BattleCommandState.swift', '*/State/BattleMotion.swift', '*/State/BattleSpectacle*.swift', '*/State/BattleSession+CardCues.swift', '*/State/BattleSession+Transitions.swift'), (PRESENTATION,)),
    (('*',), (LAUNCH, PRESENTATION)),
)
ENGINE_RULES = (
    (('*/Sources/BattleEngine/ManaEmpowermentBudget.swift',), actions('card-preparations', 'action-identity-and-selected-outcomes', 'mana-payments-and-cadence', 'card-assessment')),
    (('*/Sources/BattleEngine/Cards/BattleCardCombatEngine+OpeningHand.swift', '*/Sources/BattleEngine/Cards/BattleCardCombatEngine+TurnDraw.swift'), actions('hand-contract', 'turn-ordering')),
    (('*/Sources/BattleEngine/Cards/BattleCardAssessment.swift', '*/Sources/BattleEngine/Cards/BattleCardAssessment+Resources.swift'), actions('action-identity-and-selected-outcomes', 'mana-payments-and-cadence', 'card-assessment')),
    (('*/Sources/BattleBalanceTools/*', '*/Sources/BalanceSweepCLI/*', '*/Tests/BattleBalanceToolsTests/*'), (BALANCE,)),
    (('*/Triggers/CombatTriggerEngine+Damage.swift', '*/Triggers/CombatTriggerEngine+BlockAndDefense.swift', '*/Triggers/CombatTriggerEngine+Dodge.swift', '*/Turns/BattleTurnEngine+Resolution.swift', '*/Damage/*', '*/EffectHandlers/*', '*DoT*', '*EffectTurnEngine*', '*DamagePipeline*'), ('Docs/AgentContext/battle-damage.md',)),
    (('*Healing*', '*Leech*'), ('Docs/AgentContext/battle-healing.md',)),
    (('*/Cards/*', '*BattleHand*', '*CombatDeck*', '*Mana*', '*CardPlay*', '*CombatResolution*', '*BattleActionContext*'), (ACTION,)),
    (('*.md',), ()),
    (('*',), ('Docs/AgentContext/battle-damage.md', ACTION, 'Docs/AgentContext/battle-healing.md')),
)
PERSISTENCE_RULES = (
    (('*/Sources/TrinketPersistence/Encounters/ShopPurchaseApplier.swift', '*/Sources/TrinketPersistence/Encounters/ShopStockPersistence.swift'), sections(PROGRESSION, 'shop-stock-and-encounter-identity', 'noncombat-completion', 'voyage-identities')),
    (('*/Sources/TrinketPersistence/PlayerSaveStore+Homestead.swift',), sections(PROGRESSION, 'shop-stock-and-encounter-identity', 'homestead-transactions')),
    (('*/Sources/TrinketPersistence/PlayerSaveStore+Roster.swift',), (*storage('schema-and-sanitization'), PROGRESSION)),
    (('*/Sources/TrinketPersistence/PlayerSaveSanitizer.swift', '*/Sources/TrinketPersistence/PlayerSaveGraph/InventoryModel+ValueMapping.swift', '*/Sources/TrinketPersistence/PlayerSaveGraph/RosterModel+ValueMapping.swift'), storage('schema-and-sanitization', 'voyage-payload')),
    (('*/Sources/TrinketPersistence/Progression/*', '*/Sources/TrinketPersistence/Encounters/*'), (PROGRESSION,)),
    (('*/PlayerSaveGraph/*', '*/ModelContainerBootstrap.swift', '*/PlayerSaveSanitizer.swift', '*/PlayerSaveStoreConfiguration.swift'), (STORAGE,)),
    (('*.md',), ()),
    (('*',), (STORAGE, PROGRESSION)),
)
CONTENT_RULES = (
    (('Packages/TrinketContent/Sources/TrinketContent/Abilities/*', 'Scripts/internal/content/abilities.py'), sections(CONTENT, 'abilities')),
    (('ContentManifest/*',), sections(CONTENT, 'manifests')),
    (('Scripts/internal/content/trigger_families/*', 'Scripts/internal/content/modifiers.json', 'Scripts/internal/content/modifier_schema.py', 'Scripts/internal/content/content_codegen_triggers.py', 'Scripts/internal/content/content_codegen_modifiers.py', 'Scripts/internal/content/affix_rolling.py'), sections(CONTENT, 'trigger-schemas')),
    (('ArtManifest/*', 'MusicManifest/*', 'SoundManifest/*', 'Raw Assets/*', 'Trinket/Assets.xcassets/*', 'Trinket/Media/*', 'Scripts/prepare-*-assets.sh', 'Scripts/prepare-app-icon.sh', 'Scripts/lib/media-assets.sh', 'Scripts/asset-library.py', '*/PreparedAssets.generated.json'), sections(CONTENT, 'media-assets')),
)
VISUAL_PATHS = ('Trinket/Features/*', 'Packages/TrinketBattleFeature/Sources/*/Features/*', 'Packages/TrinketBattleFeature/Sources/*/Views/*', 'Packages/TrinketFeatureSupport/Sources/*/Features/*', 'Packages/TrinketFeatureSupport/Sources/*/FeatureAdapters/*', *(f'Packages/TrinketFeatureSupport/Sources/*/Shared/{part}/*' for part in ('Cards', 'Detail', 'Forms', 'Encounters', 'Rewards')), 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Artwork/*')
KNOWLEDGE_RULES = (
    (('*PreparedArtwork*', 'Trinket/App/TrinketApp.swift', '*PerformanceInvestigationPlaybook.md', 'Scripts/check-artwork-budget.sh', 'Scripts/check-agent-invariants.sh', 'Scripts/prepare-art-assets.sh', 'ArtManifest/*', 'Raw Assets/*'), '.agents/knowledge/patterns/artwork-working-set.md'),
    (('*/Package.swift', 'Packages/BattleEngine/*BattleState*', 'Packages/TrinketPersistence/*PlayerSaveStore*', 'Packages/TrinketAppState/*AppState*', 'Packages/TrinketAppState/*PlayBattle*', 'Packages/BattleEngine/EffectHandlers/*', 'Packages/BattleEngine/*DamagePipeline*', 'Docs/Platform/Architecture.md'), '.agents/knowledge/patterns/module-dag-containment.md'),
    (('*CloudKit*', 'Packages/TrinketContent/Package.swift', 'Packages/TrinketFeatureSupport/Package.swift', 'Packages/TrinketBattleFeature/*Feedback*', 'Packages/TrinketBattleFeature/*Spectacle*', 'Packages/TrinketBattleFeature/*Projection*', 'Packages/TrinketBattleFeature/*Ultimate*', 'Docs/Platform/Architecture.md'), '.agents/knowledge/patterns/architecture-deferred-seams.md'),
)
BEHAVIOR_CARDS = {ACTION, PRESENTATION, STORAGE, PROGRESSION, BALANCE, LAUNCH, UI_PERFORMANCE, TALENTS, 'Docs/AgentContext/battle-damage.md', 'Docs/AgentContext/battle-healing.md'}


def guidance_references() -> set[str]:
    references = {CONTENT, PERSISTENCE, RUNTIME, LAUNCH, ENGINE, BALANCE, UI, UI_PERFORMANCE, AUDIO, TALENTS, *sections(CONTENT, 'shared-safeguards', 'project-generation', 'generation-tooling')}
    for rules in (RUNTIME_RULES, ENGINE_RULES, PERSISTENCE_RULES, CONTENT_RULES):
        references.update(reference for _, values in rules for reference in values)
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

    def rule(self, path: str, rules: tuple) -> None:
        for patterns, references in rules:
            if matches(path, *patterns):
                self.add('cards', *references)
                return


def classify(paths: list[str], root: Path = ROOT) -> Route:
    route = Route(paths)
    arrays = read_env_arrays(root / 'Scripts/build-inputs.env', ['TRINKET_TEST_PACKAGES', 'TRINKET_CONTENT_GENERATION_INPUTS', 'TRINKET_ASSET_GENERATION_INPUTS', 'TRINKET_PROJECT_GENERATION_INPUTS'])
    packages = arrays['TRINKET_TEST_PACKAGES']
    smoke = {row['key']: row['name'] for row in registrations(root) if row['suite'] == 'Smoke'}
    registry = root / 'Scripts/config/generated-paths.tsv'
    generated_roots, asset_roots = [], []
    if registry.exists():
        for line in registry.read_text().splitlines():
            if line.startswith('#') or '|' not in line:
                continue
            kind, entry = line.split('|', 1)
            if kind in {'content', 'asset'} and entry:
                generated_roots.append(entry.rstrip('/'))
                if kind == 'asset':
                    asset_roots.append(entry.rstrip('/'))

    def add_smoke(path: str) -> None:
        key = None
        if matches(path, 'Trinket/Features/Monetization/*'): key = 'MONETIZATION'
        elif matches(path, 'Packages/TrinketBattleFeature/Sources/*', 'TrinketUITests/Battle/*'): key = 'BATTLE'
        elif matches(path, 'Trinket/Features/Collection/*', 'Trinket/Features/Homestead/*', 'Trinket/Features/Options/*', 'TrinketUITests/Collection/*', 'TrinketUITests/Support/*'): key = 'SHELL'
        elif matches(path, *(f'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/{name}' for name in ('Accessibility/AccessibilityID.swift', 'Artwork/PreparedArtworkCache.swift', 'Artwork/PreparedArtwork.swift'))): key = 'SHELL'
        elif matches(path, 'Trinket/Features/Play/Shop/*'): key = 'SHOP'
        elif matches(path, 'Trinket/Features/Onboarding/*'): key = 'ONBOARDING'
        elif matches(path, 'Trinket/Features/Play/*', 'TrinketUITests/Play/*'): key = 'SHELL'
        elif matches(path, 'TrinketUITests/Smoke/*.swift'):
            route.add('smoke_targets', Path(path).stem)
            if Path(path).stem == 'SmokeShellTests': key = 'ONBOARDING'
            else: return
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
                    route.needs.add('assets'); route.add('generated_warnings', 'Prepared asset output detected; edit the manifest/Asset Library source and run ./Scripts/prepare-assets.sh.')
                elif matches(path, 'Packages/*/Generated/*'):
                    if matches(path, 'Packages/*/Generated/*SourceHashes.generated.tsv'):
                        route.needs.add('assets'); route.add('generated_warnings', 'Generated asset hash state detected; edit the manifest/Asset Library source and run ./Scripts/generate.sh --assets.')
                    else:
                        route.needs.add('content'); route.add('generated_warnings', 'Generated package output detected; edit the authored source and run ./Scripts/generate.sh.')
                else:
                    route.needs.add('assets'); route.add('generated_warnings', 'Processed app output detected; edit the manifest/Asset Library source and run the appropriate generation command.')
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
            route.rule(path, CONTENT_RULES)
            if matches(path, 'Scripts/content_codegen.py', 'Scripts/internal/content/*', 'Scripts/generate.sh', 'Scripts/assert-generated-output.sh', 'Scripts/config/generated-paths.tsv', 'Packages/TrinketContent/Package.swift'): route.add('cards', *sections(CONTENT, 'generation-tooling'))
    if 'TrinketPersistence' in route.packages: route.add('cards', PERSISTENCE)
    if 'audio' in route.features: route.add('cards', AUDIO)
    if any(matches(path, 'Scripts/balance-sweep.sh', 'Packages/BattleEngine/*Balance*') for path in paths): route.add('cards', BALANCE)
    if 'project' in route.features: route.add('cards', *sections(CONTENT, 'shared-safeguards', 'project-generation'))
    for path in paths:
        if path.endswith('.swift'):
            tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', path], cwd=root, capture_output=True).returncode == 0
            diff = subprocess.check_output(['git', 'diff', '--no-ext-diff', '--unified=0', '--', path], cwd=root, text=True) if tracked else '\n'.join((root / path).read_text().splitlines()[:240]) if (root / path).is_file() else ''
            if re.search(r'//.*(swiftlint:|swiftformat:|[A-Za-z]+Check:\s*allow|Concurrency-Safety:)', diff): route.add('skills', '.agents/skills/doc-budget/SKILL.md')
            public = r'(public\s+(actor|class|enum|struct|protocol|typealias)|(^|\s)protocol\s|@Model|[A-Za-z0-9_]+Schema|@attached)'
            if re.search(r'^\+[^+].*' + public if tracked else public, diff, re.MULTILINE): route.add('skills', '.agents/skills/architect/SKILL.md'); route.add('knowledge', '.agents/knowledge/patterns/module-dag-containment.md')
        runtime_path = matches(path, 'Trinket/App/TrinketApp.swift', 'Packages/BattleEngine/Sources/BattleEngine/Runtime/BattleRuntime*.swift', 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattleRuntime.swift', 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattlePresentationDependencies.swift', 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattleProgressionDelegate.swift', 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts/BattlePreparedPreview.swift', 'Packages/TrinketBattleFeature/*') or (path.startswith('Packages/TrinketAppState/') and '/Audio/' not in path and matches(path, '*Battle*', '*/Encounter*', '*/Play/*', '*/App/AppState.swift'))
        if runtime_path: route.add('cards', RUNTIME); route.rule(path, RUNTIME_RULES)
        elif path.startswith('Packages/BattleEngine/'): route.add('cards', ENGINE); route.rule(path, ENGINE_RULES)
        if path.startswith('Packages/TrinketPersistence/'): route.add('cards', PERSISTENCE); route.rule(path, PERSISTENCE_RULES)
        if path == 'ContentManifest/talents.tsv': route.add('cards', TALENTS)
        if matches(path, 'Trinket/App/*', '*PreparedArtwork*', '*ArtworkViewportPrewarm*', 'Trinket/Features/Collection/*', '*LaunchWarmup*', '*HiddenTabPrewarm*'): route.add('cards', UI_PERFORMANCE)
        for patterns, reference in KNOWLEDGE_RULES:
            if matches(path, *patterns): route.add('knowledge', reference)
        for parent in (root / path).parents:
            if parent == root: break
            if (parent / 'AGENTS.md').is_file(): route.add('guides', (parent / 'AGENTS.md').relative_to(root).as_posix())
    if any(matches(path, *VISUAL_PATHS) for path in paths): route.add('skills', '.agents/skills/apple-design/SKILL.md'); route.add('cards', UI)
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
        flag = ['--fast'] if local else ['--skip-docs'] if final or 'docs' in route.needs else []
        add('scripts', 'script regressions', './Scripts/test-scripts.sh', *flag, '--paths', *route.paths)
    if not final and ('docs' in route.needs or local and 'scripts' in route.needs): add('docs', 'documentation', 'python3', './Scripts/check-docs.py')
    if route.packages: add('package', 'package tests', './Scripts/test-package.sh', *route.packages, heavy=True, env=(('SKIP_GENERATE', '1'),))
    if 'build' in route.needs or 'feature' in route.features and (not route.smoke_targets or not smoke):
        add('build', 'app compilation', './Scripts/build.sh', heavy=True, env=(('SKIP_GENERATE', '1'),))
    if 'smoke' in route.needs and smoke and route.smoke_targets:
        add('smoke', 'UI smoke', './Scripts/test.sh', 'smoke', *route.smoke_targets, heavy=True, env=(('SKIP_GENERATE', '1'),))
    if local and 'assets' in route.needs: add('assets', 'prepared asset integrity', './Scripts/ci-assets-gate.sh')
    style_checked = any(check.id == 'style' and not check.deferred for check in checks)
    config = Path(environment.get('TRINKET_CHEAP_SLICES_CONFIG', 'Scripts/config/cheap-slices.txt'))
    if not config.is_absolute(): config = root / config
    count = 0
    for line in config.read_text().splitlines():
        command, _, flags = line.partition('#')
        if not command.strip() or style_checked and 'skip-when-style-checked' in flags: continue
        lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|<>')
        lexer.whitespace_split = True
        argv = list(lexer)
        if any(token in {';', '&&', '||', '|', '>', '<'} for token in argv): raise ValueError('Cheap slices must be executable argument lists, not shell expressions')
        count += 1
        add(f'cheap-{count}', 'cheap CI slice: ' + command.strip(), *argv)
    if not count: raise ValueError('Cheap-slice registry is empty.')
    if mirror and (route.needs & {'build', 'content', 'project'} or route.packages or 'feature' in route.features):
        if local:
            raise ValueError('Simulator mirroring is CI-owned; an expressly requested local diagnostic requires TRINKET_ALLOW_HEAVY_LOCAL=1')
        add('mirror', 'mirror', './Scripts/promote.sh', '--quiet', heavy=True)
    return checks


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

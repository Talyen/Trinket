"""The enforced package DAG and the app's concrete battle composition seams."""

from __future__ import annotations

import re

from internal.policy_scan import SourceScan

SUPPORT = 'TrinketFeatureSupport'
CONTRACTS = 'TrinketFeatureContracts'
ADAPTERS = 'TrinketFeatureAdapters'
BATTLE = 'TrinketBattleFeature'
APP = 'TrinketAppState'
ENGINE = 'BattleEngine'
SAVE = 'TrinketPersistence'
DESIGN = 'TrinketDesignSystem'
CONTENT = 'TrinketContent'
FORBIDDEN = {
    CONTENT: (ENGINE, SAVE, DESIGN, SUPPORT, BATTLE, APP),
    DESIGN: (CONTENT, ENGINE, SAVE, SUPPORT, BATTLE, APP),
    ENGINE: (SAVE, SUPPORT, BATTLE, APP),
    SAVE: (ENGINE, SUPPORT, BATTLE, APP),
    SUPPORT: (BATTLE, APP),
    BATTLE: (APP, ADAPTERS),
}
BATTLE_SEAMS = {
    'Trinket/App/ContentView.swift', 'Trinket/App/DebugFPSOverlay.swift', 'Trinket/App/TrinketApp.swift',
    'Trinket/Features/Collection/SalvageDissolvePresentation.swift', 'Trinket/Features/Options/OptionsView.swift',
    'Trinket/Features/Play/PlayView.swift', 'Trinket/Features/Play/PlayBattleOverlay.swift',
}


def violations(scan: SourceScan) -> list[str]:
    findings = []

    def imports(folder, forbidden, owner):
        for dependency in forbidden:
            for path, _, _ in scan.matches(f'^import {dependency}$', folder, generated=True):
                message = f'{owner} must not import {dependency}'
                findings.append(f'{path.relative_to(scan.root)}: {message}')

    imports('Packages', ('Trinket',), 'packages')
    for path, _, _ in scan.matches(r'^\s*(public|open)(\s|$)', f'Packages/{SAVE}/Sources/{SAVE}/PlayerSaveGraph', generated=True):
        findings.append(f'{path.relative_to(scan.root)}: persistence graph must not export public storage models, mappings, or schema')
    for owner, forbidden in FORBIDDEN.items():
        imports(f'Packages/{owner}/Sources', forbidden, owner)
        manifest = f'Packages/{owner}/Package.swift'
        for dependency in forbidden:
            if f'"{dependency}"' in scan.text(scan.root / manifest):
                findings.append(f'{manifest}: {owner} must not depend on {dependency}')
    imports(f'Packages/{SUPPORT}/Sources/{SUPPORT}', (ENGINE, SAVE), SUPPORT)
    imports(f'Packages/{SUPPORT}/Sources/{ADAPTERS}', (ENGINE,), ADAPTERS)
    imports(f'Packages/{APP}/Sources', (BATTLE, ADAPTERS, SUPPORT), APP)
    imports(f'Packages/{SUPPORT}/Sources/{CONTRACTS}', ('SwiftUI', 'UIKit', DESIGN, SAVE, SUPPORT, ADAPTERS, BATTLE, APP), CONTRACTS)
    imports(f'Packages/{ENGINE}/Sources', ('SwiftUI', 'UIKit', CONTRACTS, BATTLE, APP), ENGINE)

    # Tests may depend on presentation while shipping targets stay below it.
    for owner, target, forbidden in (
        (APP, None, (BATTLE, ADAPTERS)),
        (SUPPORT, CONTRACTS, ('SwiftUI', 'UIKit', DESIGN, SAVE, SUPPORT, ADAPTERS, BATTLE, APP)),
        (SUPPORT, ADAPTERS, (ENGINE,)),
    ):
        active = in_target = False
        for line in scan.lines(scan.root / f'Packages/{owner}/Package.swift'):
            if '.target(' in line:
                in_target = True
                active = target is None
            if '.testTarget(' in line:
                active = in_target = False
            elif in_target and target and re.search(rf'name:\s*"{target}"', line):
                active = True
            for dependency in forbidden if active else ():
                if f'"{dependency}"' in line:
                    message = ('production target must depend on FeatureContracts, not BattleFeature' if dependency == BATTLE and owner == APP
                               else f'{target or owner} production target must not depend on {dependency}')
                    findings.append(f'Packages/{owner}/Package.swift: {message}')
    for path, _, _ in scan.matches(f'^import {BATTLE}$', 'Trinket', generated=True):
        relative = path.relative_to(scan.root).as_posix()
        if relative not in BATTLE_SEAMS:
            findings.append(f'{relative}: app product screens must use BattleRuntime/FeatureSupport instead of importing BattleFeature')
    return list(dict.fromkeys(findings))

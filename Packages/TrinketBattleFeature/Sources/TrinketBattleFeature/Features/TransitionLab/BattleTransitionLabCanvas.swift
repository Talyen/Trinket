import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

#if DEBUG
@MainActor
final class BattleTransitionLabFixture {
    let session: BattleSession
    let configuration: BattleRunConfiguration
    let summary: BattleVictorySummary

    init(stage: Stage) {
        let hero = GameContent.hero(matching: "rogue") ?? GameContent.heroes.first
            ?? Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.slash])
        let companion = GameContent.companions.first { $0.id == "wolf" } ?? GameContent.companions.first
            ?? Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [.slash])
        let enemy = stage.resolvedBattleEnemyID(worldSeed: 1772)
            .flatMap { GameContent.enemy(matching: $0)?.combatant }
        configuration = BattleRunConfiguration(
            runKey: nil,
            rngSeed: 1772,
            hero: .init(combatant: hero, progression: .initial, equipmentLoadout: .init(), modifiers: .zero),
            companion: .init(combatant: companion, progression: .initial, equipmentLoadout: .init(), modifiers: .zero),
            enemy: enemy,
            enemyEncounterLevel: nil,
            enemyModifiers: .zero,
        )
        session = BattleSession(presentationEnvironment: BattlePresentationDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
        ))
        _ = session.activate(configuration, presentation: .empty)
        // Freeze the opening projection. The lab never drives turns or gameplay input.
        session.setSuspendedForScenePhase(true)
        let plan = BattleRewardPlan(
            stageGold: 75, goldFindPercent: 0,
            heroExperience: 24, companionExperience: 18, materials: [], items: [],
        )
        summary = BattleVictorySummary.make(
            configuration: configuration,
            settlement: plan.settle(
                battleGold: BattleGoldFlow(gained: 12),
                inputs: BattleSession.fallbackRewardInputs(for: configuration),
            ),
            heroName: hero.name,
            companionName: companion.name,
        )
    }
}

struct BattleTransitionLabCanvas: View {
    let fixture: BattleTransitionLabFixture

    var body: some View {
        GeometryReader { geometry in
            let handFrame = BattleHandLayout.frame(in: geometry.size)
            let handScale = BattleHandLayout.scale(for: geometry.size.width)
            let battlefieldSize = BattleHandLayout.battlefieldSize(in: geometry.size)
            let layout = BattleCardGridLayout.metrics(in: battlefieldSize)
            ZStack(alignment: .bottom) {
                BattlefieldView(
                    layout: layout,
                    presentation: fixture.session.presentation,
                    hapticsEnabled: false,
                    onCombatantTap: { _ in },
                    interactionState: BattleInteractionState(),
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                BattleHandView(
                    cards: fixture.session.presentation.hand,
                    isDetailPresented: false,
                    isPlayable: { _ in true },
                    onInspect: { _ in },
                    onPlay: { _, _ in false },
                    onPlayDenied: { _ in },
                    hapticsEnabled: false,
                )
                .frame(height: handFrame.height)
                .offset(y: -BattleHandLayout.bottomRise * handScale)
            }
            .clipped()
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif

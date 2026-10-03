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
        session = BattleSession(presentationEnvironment: BattleRuntimeDependencies(
            playSFX: { _ in },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 0 },
            shouldAutoSkipUltimateCinematic: { _, _ in true },
            ultimateCinematicAnimationsEnabled: { false },
        ))
        _ = session.activate(configuration, presentation: .empty)
        // Freeze the opening projection. The lab never drives turns or gameplay input.
        session.setSuspendedForScenePhase(true)
        let plan = BattlePresentationContext(
            inventoryItems: [],
            stageReward: StageReward(gold: 75, itemTemplateIDs: []),
            rewardItems: [],
            pendingRewardItem: nil,
            experienceBonusPercent: 0,
            goldFindPercent: 0,
            stageRewardsAlreadyClaimed: false,
            hasProgressionRewards: true,
            musicStageID: nil,
            heroExperienceAward: 24,
            companionExperienceAward: 18,
            materialRewards: [],
        ).rewardPlan
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
            let battlefieldSize = CGSize(
                width: geometry.size.width,
                height: max(0, geometry.size.height - BattleHandLayout.reservedHeight + BattleHandLayout.overlapAllowance),
            )
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
                .frame(height: BattleHandLayout.reservedHeight)
                .offset(y: -BattleHandLayout.bottomRise)
            }
            .clipped()
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif

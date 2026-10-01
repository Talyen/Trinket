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

    init() {
        let hero = GameContent.hero(matching: "rogue") ?? GameContent.heroes.first
            ?? Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.slash])
        let companion = GameContent.companions.first { $0.id == "wolf" } ?? GameContent.companions.first
            ?? Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [.slash])
        let enemy = GameContent.enemies.first?.combatant
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
    let screen: BattleTransitionScreen
    let gathersPortraits: Bool
    let entrySettled: Bool
    let handVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let battlefieldSize = CGSize(
                width: size.width,
                height: max(0, size.height - BattleHandLayout.reservedHeight + BattleHandLayout.overlapAllowance),
            )
            let layout = BattleCardGridLayout.metrics(in: battlefieldSize)
            ZStack(alignment: .bottom) {
                if gathersPortraits || screen == .preview {
                    portraits(size: size, layout: layout)
                } else {
                    BattlefieldView(
                        layout: layout,
                        presentation: fixture.session.presentation,
                        hapticsEnabled: false,
                        onCombatantTap: { _ in },
                        interactionState: BattleInteractionState(),
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                previewControls
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .trinketPresentationVisibility(screen == .preview && !entrySettled)

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
                .offset(y: handVisible ? -BattleHandLayout.bottomRise : BattleHandLayout.reservedHeight + 80)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .clipped()
            .coordinateSpace(.named(BattleCoordinateSpace.field))
        }
    }

    private var previewControls: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            Text("ENCOUNTER PREVIEW")
                .trinketTypography(.eyebrow)
                .foregroundStyle(.secondary)
            Text(fixture.configuration.enemy?.name ?? "Battle")
                .trinketTypography(.sectionDisplay)
            Text("\(fixture.configuration.hero.combatant.name) · \(fixture.configuration.companion.combatant.name)")
                .trinketTypography(.secondaryBody)
            Text("Choose a replay from Controls")
                .trinketTypography(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(TrinketDesign.Layout.contentMargin)
        .frame(maxWidth: .infinity)
        .background(TrinketDesign.Colors.surface)
    }

    private func portraits(size: CGSize, layout: BattleCardGridLayout.Metrics) -> some View {
        let previewEnemy = CGSize(width: size.width * 0.88, height: min(size.height * 0.30, size.width * 0.66))
        let previewParty = CGSize(width: size.width * 0.27, height: size.width * 0.36)
        let partyY = layout.enemySize.height + layout.cardSpacing + layout.partySize.height / 2
        return ZStack {
            portrait(.enemy)
                .frame(
                    width: entrySettled ? layout.enemySize.width : previewEnemy.width,
                    height: entrySettled ? layout.enemySize.height : previewEnemy.height,
                )
                .position(x: size.width / 2, y: entrySettled ? layout.enemySize.height / 2 : previewEnemy.height / 2 + 20)
            portrait(.hero)
                .frame(
                    width: entrySettled ? layout.partySize.width : previewParty.width,
                    height: entrySettled ? layout.partySize.height : previewParty.height,
                )
                .position(
                    x: size.width / 2 - (entrySettled ? layout.partySize.width + layout.cardSpacing : previewParty.width + 16) / 2,
                    y: entrySettled ? partyY : previewEnemy.height + 50 + previewParty.height / 2,
                )
            portrait(.companion)
                .frame(
                    width: entrySettled ? layout.partySize.width : previewParty.width,
                    height: entrySettled ? layout.partySize.height : previewParty.height,
                )
                .position(
                    x: size.width / 2 + (entrySettled ? layout.partySize.width + layout.cardSpacing : previewParty.width + 16) / 2,
                    y: entrySettled ? partyY : previewEnemy.height + 50 + previewParty.height / 2,
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func portrait(_ role: BattleCombatantProjectionPane.Role) -> some View {
        BattleCombatantProjectionPane(
            presentation: fixture.session.presentation,
            role: role,
            hapticsEnabled: false,
            onCombatantTap: { _ in },
        )
    }
}
#endif

import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketFeatureContracts
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionSettlementFallbackTests {
    @Test(arguments: [false, true])
    func `victory uses captured plan only when settlement lookup is unavailable`(authoritative: Bool) throws {
        let party = BattlePartyFixtures.quickWinParty()
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            hero: party.hero, companion: party.companion, enemy: party.enemy,
            heroExperienceAward: 24, companionExperienceAward: 12,
        )
        let session = BattleSession(outcomePresentationDelayOverride: .zero)
        let alternative = Self.alternativePlan
        Self.configure(session, context: context, plan: authoritative ? alternative : nil)
        #expect(session.activate(configuration))
        defer { session.endBattle() }

        var state = try #require(session.engineState)
        state.roster.enemy.currentHealth = 0
        session.engineState = state
        session.handleOutcomeIfNeeded(at: .now)

        let summary = try #require(session.spectacle.outcomePresentation.victorySummaryIfAvailable)
        let inputs = context.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration)
        let expected = (authoritative ? alternative : context.rewardPlan).settle(
            battleGold: state.goldFlow, inputs: inputs,
        )
        #expect(session.outcome == .victory)
        #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        #expect(summary.settlement == expected)
        #expect(summary.experience > 0)
    }

    @Test(arguments: [false, true], [false, true])
    func `normal defeat and retreat use the same settlement fallback`(retreat: Bool, authoritative: Bool) throws {
        let (configuration, context) = BattleRunConfigurationTestSupport.make(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroExperienceAward: 100, companionExperienceAward: 60,
        )
        let session = BattleSession(outcomePresentationDelayOverride: .zero)
        let alternative = Self.alternativePlan
        Self.configure(session, context: context, plan: authoritative ? alternative : nil)
        #expect(session.activate(configuration))
        defer { session.endBattle() }

        var state = try #require(session.engineState)
        state.roster.enemy.currentHealth = 41
        if !retreat {
            state.roster.hero.currentHealth = 0
            state.roster.companion.currentHealth = 0
        }
        session.engineState = state
        if retreat {
            #expect(session.retreatFromBattle())
        } else {
            session.handleOutcomeIfNeeded(at: .now)
        }

        guard case let .defeat(settlement) = session.spectacle.outcomePresentation else {
            Issue.record("Expected defeat reveal")
            return
        }
        let progress = try #require(session.resolvedDefeatProgress)
        let inputs = context.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration)
        let expected = (authoritative ? alternative : context.rewardPlan).settleDefeat(
            progress: progress, inputs: inputs,
        )
        #expect(session.outcome == .defeat)
        #expect(settlement == expected)
        #expect(settlement.award.heroExperience > 0)
    }

    private static let alternativePlan = BattleRewardPlan(
        stageGold: 31, goldFindPercent: 0,
        heroExperience: 200, companionExperience: 120,
        materials: [], items: [],
    )

    private static func configure(
        _ session: BattleSession,
        context: BattlePresentationContext,
        plan: BattleRewardPlan?,
    ) {
        session.configureProgression(
            presentation: { _ in context },
            settleRewards: { configuration, gold in
                plan?.settle(
                    battleGold: gold,
                    inputs: context.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration),
                )
            },
            completeVictory: { _, _, _, _ in .unavailable },
            settleDefeat: { [weak session] configuration in
                guard let plan, let progress = session?.resolvedDefeatProgress else { return nil }
                return plan.settleDefeat(
                    progress: progress,
                    inputs: context.rewardInputs ?? BattleSession.fallbackRewardInputs(for: configuration),
                )
            },
            completeDefeat: { _, _, _ in .unavailable },
            finishPresentation: { _ in },
        )
    }
}

import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionRetreatTests {
    @Test(arguments: [100, 41])
    func `retreat freezes progress and immediately presents defeat`(remainingHealth: Int) throws {
        let session = BattleSession(outcomePresentationDelayOverride: 60)
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroExperienceAward: 100,
            companionExperienceAward: 60,
        )
        #expect(session.activate(configuration, presentation: presentation))
        defer { session.endBattle() }
        var state = try #require(session.engineState)
        state.roster.enemy.currentHealth = remainingHealth
        session.engineState = state
        let progress = state.defeatProgress

        #expect(session.retreatFromBattle())
        #expect(session.outcome == .defeat)
        #expect(session.resolvedDefeatProgress == progress)
        guard case let .defeat(settlement) = session.spectacle.outcomePresentation else {
            Issue.record("Retreat must present defeat without a delay")
            return
        }
        #expect(settlement.award.heroExperience == (100 - remainingHealth) / 2)
        #expect(settlement.award.companionExperience == 60 * (100 - remainingHealth) / 100 / 2)
        #expect(settlement.award.goldDelta == 0)
        #expect(settlement.award.materials.isEmpty)
        #expect(settlement.award.items.isEmpty)
        #expect(!session.canRetreat)
        #expect(!session.canInteractWithHand)
        #expect(!session.hasPendingAutoEnd)
        #expect(!session.transitionTask.hasPendingTask)
        #expect(!session.spectacle.outcomeTask.hasPendingTask)
        #expect(!session.retreatFromBattle())
        #expect(session.playCard(cardID: 0) == .rejected)
        session.endTurn()
        session.setSuspendedForScenePhase(true)
        session.setSuspendedForScenePhase(false)
        for participant in [BattleParticipant.hero, .companion, .enemy] {
            #expect(session.engineState?.roster[participant] == state.roster[participant])
        }
        #expect(session.engineState?.turnCount == state.turnCount)
        #expect(session.resolvedDefeatProgress == progress)
        #expect(session.spectacle.outcomePresentation == .defeat(settlement))

        #expect(session.restart(configuration, presentation: presentation))
        #expect(session.outcome == nil)
        #expect(session.resolvedDefeatProgress == nil)
        #expect(session.canRetreat)
        session.endBattle()
        #expect(session.resolvedDefeatProgress == nil)
    }

    @Test func `retreat cannot replace a resolved victory`() {
        let session = BattleSessionTestSupport.makeConfiguredSession(enemy: CombatantFixtures.passiveEnemy(maxHealth: 1))
        defer { session.endBattle() }
        BattleSessionTestSupport.driveUntilOutcome(session)
        #expect(session.outcome == .victory)
        let presentation = session.spectacle.outcomePresentation
        #expect(!session.retreatFromBattle())
        #expect(session.outcome == .victory)
        #expect(session.spectacle.outcomePresentation == presentation)
    }
}

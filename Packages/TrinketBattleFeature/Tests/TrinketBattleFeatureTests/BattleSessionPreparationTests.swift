import Foundation
import Testing
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSessionPreparationTests {
    @Test func lifecycleTransitionsUpdateEngineAndPresentationAtomically() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.activate(configuration))
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.hasActiveSimulation)
        #expect(session.lifecyclePhase == .active)
        #expect(session.presentation.configurationID == configuration.id)

        session.endBattle()

        #expect(session.activeBattle == nil)
        #expect(!session.hasActiveSimulation)
        #expect(session.lifecyclePhase == .idle)
        #expect(session.presentation.configurationID == nil)
    }

    @Test func preparedBattlePresentationRevisionChangesOnlyForReplacedRuns() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-run")
        let session = BattleSession(openingHandDrawStagger: 0)
        let (configuration, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(configuration))
        let initialRevision = session.preparedBattlePresentationRevision
        #expect(initialRevision == 1)

        #expect(session.prepareBattleRun(configuration))
        #expect(session.preparedBattlePresentationRevision == initialRevision)

        let (replacement, _) = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        #expect(session.prepareBattleRun(replacement))
        #expect(session.preparedBattlePresentationRevision == initialRevision + 1)
    }

    @Test func replacementOpeningHandDealRetainsTaskOwnershipAfterCancellation() async throws {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        let expectedOpeningHandCount = min(
            BattleHand.maxSize,
            party.hero.abilityLoadout.abilities.count
                + party.companion.abilityLoadout.abilities.count
        )
        let session = BattleSession(openingHandDrawStagger: 0.05)
        let (initialConfiguration, _) = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let (replacementConfiguration, _) = BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.activate(initialConfiguration))
        #expect(session.restart(replacementConfiguration))

        for _ in 0 ..< 40 where session.hand.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(!session.hand.isEmpty)
        #expect(session.isDealingOpeningHand)

        for _ in 0 ..< 100 where session.isDealingOpeningHand {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(session.hand.count == expectedOpeningHandCount)
        #expect(!session.isDealingOpeningHand)
        #expect(session.activeBattle?.id == replacementConfiguration.id)
    }
}

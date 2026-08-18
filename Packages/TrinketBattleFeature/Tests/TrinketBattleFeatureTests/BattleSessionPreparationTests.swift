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

    @Test func keepPreparedRunsDropsStalePreparedBattles() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0)
        let keptKey = BattleRunKey("test|keep")
        let droppedKey = BattleRunKey("test|drop")
        let (kept, _) = BattleRunConfigurationTestSupport.make(
            runKey: keptKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let (dropped, _) = BattleRunConfigurationTestSupport.make(
            runKey: droppedKey,
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.prepareBattleRun(kept))
        #expect(session.prepareBattleRun(dropped))
        #expect(session.preparedBattleRuns.count == 2)

        session.keepPreparedRuns([keptKey])

        #expect(session.preparedBattleRuns.count == 1)
        #expect(session.preparedBattleRun(for: keptKey) != nil)
        #expect(session.preparedBattleRun(for: droppedKey) == nil)
        #expect(session.lifecyclePhase == .prepared)
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

        #expect(try await BattleSessionTestSupport.waitUntil { !session.hand.isEmpty })

        #expect(!session.hand.isEmpty)
        #expect(session.isDealingOpeningHand)

        #expect(try await BattleSessionTestSupport.waitUntil { !session.isDealingOpeningHand })

        #expect(session.hand.count == expectedOpeningHandCount)
        #expect(!session.isDealingOpeningHand)
        #expect(session.activeBattle?.id == replacementConfiguration.id)
    }
}

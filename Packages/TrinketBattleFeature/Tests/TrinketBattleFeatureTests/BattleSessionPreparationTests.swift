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
    @Test func runtimeOwnsLifecycleAndPresentationMirrorsItsTransitions() {
        let party = BattlePartyFixtures.quickWinParty()
        let runtime = BattleRuntimeSession()
        let session = BattleSession(
            runtime: runtime,
            openingHandDrawStagger: 0
        )
        let configuration = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(runtime.activate(configuration))
        #expect(runtime.activeBattle?.id == configuration.id)
        #expect(runtime.hasActiveSimulation)
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.lifecyclePhase == .active)
        #expect(session.presentation.configurationID == configuration.id)

        runtime.endBattle()

        #expect(runtime.activeBattle == nil)
        #expect(!runtime.hasActiveSimulation)
        #expect(session.activeBattle == nil)
        #expect(session.lifecyclePhase == .idle)
        #expect(session.presentation.configurationID == nil)
    }

    @Test func preparedBattlePresentationRevisionChangesOnlyForReplacedRuns() {
        let party = BattlePartyFixtures.quickWinParty()
        let runKey = BattleRunKey("test|prepared-run")
        let session = BattleSession(openingHandDrawStagger: 0)
        let configuration = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(session.runtime.prepareBattleRun(configuration))
        let initialRevision = session.preparedBattlePresentationRevision
        #expect(initialRevision == 1)

        #expect(session.runtime.prepareBattleRun(configuration))
        #expect(session.preparedBattlePresentationRevision == initialRevision)

        let replacement = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        #expect(session.runtime.prepareBattleRun(replacement))
        #expect(session.preparedBattlePresentationRevision == initialRevision + 1)
    }

    @Test func replacementOpeningHandDealRetainsTaskOwnershipAfterCancellation() async throws {
        let party = BattlePartyFixtures.quickWinParty(heroAbilities: [.slash, .heal, .smite])
        let expectedOpeningHandCount = min(
            BattleHand.maxSize,
            party.hero.abilityLoadout.abilities.count
                + party.companion.abilityLoadout.abilities.count
        )
        let runtime = BattleRuntimeSession()
        let session = BattleSession(
            runtime: runtime,
            openingHandDrawStagger: 0.05
        )
        let initialConfiguration = BattleRunConfigurationTestSupport.make(
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        let replacementConfiguration = BattleRunConfigurationTestSupport.make(
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )

        #expect(runtime.activate(initialConfiguration))
        #expect(runtime.restart(replacementConfiguration))

        for _ in 0 ..< 40 where session.hand.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(!session.hand.isEmpty)
        #expect(session.commandCoordinator.isDealingOpeningHand)

        for _ in 0 ..< 100 where session.commandCoordinator.isDealingOpeningHand {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(session.hand.count == expectedOpeningHandCount)
        #expect(!session.commandCoordinator.isDealingOpeningHand)
        #expect(session.activeBattle?.id == replacementConfiguration.id)
    }
}

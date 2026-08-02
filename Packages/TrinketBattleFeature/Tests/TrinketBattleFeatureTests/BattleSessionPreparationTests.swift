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
        #expect(runtime.simulation.hasState)
        #expect(session.activeBattle?.id == configuration.id)
        #expect(session.lifecyclePhase == .active)
        #expect(session.presentation.configurationID == configuration.id)

        runtime.endBattle()

        #expect(runtime.activeBattle == nil)
        #expect(!runtime.simulation.hasState)
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
}

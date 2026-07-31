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

        #expect(session.prepareBattleRun(configuration))
        let initialRevision = session.preparedBattlePresentationRevision
        #expect(initialRevision == 1)

        #expect(session.prepareBattleRun(configuration))
        #expect(session.preparedBattlePresentationRevision == initialRevision)

        let replacement = BattleRunConfigurationTestSupport.make(
            runKey: runKey,
            rngSeed: 1,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy
        )
        #expect(session.prepareBattleRun(replacement))
        #expect(session.preparedBattlePresentationRevision == initialRevision + 1)
    }
}

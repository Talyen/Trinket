import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleClaimedVictoryTests {
    @Test(arguments: [false, true])
    func `claimed victory completes once without an overlay and failed completion presents retry`(fails: Bool) {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true,
        )
        var claimedVictories: [(configurationID: UUID, earnedGold: Int)] = []
        BattleSessionTestSupport.configureProgression(session, presentation: presentation) { configuration, earnedGold, _ in
            claimedVictories.append((configuration.id, earnedGold.net))
            return fails ? .persistenceFailed : .completed
        }
        _ = session.activate(configuration)
        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session)
        session.handleOutcomeIfNeeded(at: .now)

        #expect(claimedVictories.count == 1)
        #expect(claimedVictories.first?.configurationID == configuration.id)
        #expect(claimedVictories.first?.earnedGold == earnedGold)
        #expect((session.completionError != nil) == fails)
        #expect(session.spectacle.outcomePresentation.isVictoryPresented == fails)
    }

    @Test func `claimed victory delivery resets for restart`() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let first = BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true,
        )
        var deliveredConfigurationIDs: [UUID] = []
        BattleSessionTestSupport.configureProgression(session, presentation: first.presentation) { configuration, _, _ in
            deliveredConfigurationIDs.append(configuration.id)
            return .completed
        }
        _ = session.activate(first.configuration)
        BattleSessionTestSupport.driveUntilOutcome(session)

        let second = BattleRunConfigurationTestSupport.make(
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true,
        )
        _ = session.restart(second.configuration, presentation: second.presentation)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(deliveredConfigurationIDs == [first.configuration.id, second.configuration.id])
    }
}

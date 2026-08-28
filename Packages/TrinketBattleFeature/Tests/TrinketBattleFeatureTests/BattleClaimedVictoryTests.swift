import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import TrinketBattleFeature

@MainActor
struct BattleClaimedVictoryTests {
    @Test func claimedVictoryIsDeliveredOnceWhenHandlerInstallsLate() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true
        )
        _ = session.activate(configuration)
        session.installPresentationContext(presentation)
        var claimedVictories: [(configurationID: UUID, earnedGold: Int)] = []

        let earnedGold = BattleSessionTestSupport.driveUntilOutcome(session)
        session.installClaimedVictoryHandler(ownerID: UUID()) { configuration, earnedGold in
            claimedVictories.append((configuration.id, earnedGold))
        }
        session.handleOutcomeIfNeeded(at: .now)

        #expect(claimedVictories.count == 1)
        #expect(claimedVictories.first?.configurationID == configuration.id)
        #expect(claimedVictories.first?.earnedGold == earnedGold)
    }

    @Test func claimedVictoryDeliveryResetsForRestart() {
        let party = BattlePartyFixtures.quickWinParty()
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = .zero
        let first = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true
        )
        _ = session.activate(first.configuration)
        session.installPresentationContext(first.presentation)
        var deliveredConfigurationIDs: [UUID] = []
        session.installClaimedVictoryHandler(ownerID: UUID()) { configuration, _ in
            deliveredConfigurationIDs.append(configuration.id)
        }

        BattleSessionTestSupport.driveUntilOutcome(session)

        let second = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: party.hero,
            companion: party.companion,
            enemy: party.enemy,
            stageRewardsAlreadyClaimed: true
        )
        _ = session.restart(second.configuration)
        session.installPresentationContext(second.presentation)
        BattleSessionTestSupport.driveUntilOutcome(session)

        #expect(deliveredConfigurationIDs == [first.configuration.id, second.configuration.id])
    }
}

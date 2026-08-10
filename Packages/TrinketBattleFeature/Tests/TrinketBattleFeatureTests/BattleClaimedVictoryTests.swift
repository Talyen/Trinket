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
        session.partyCelebrateDelayOverride = 0
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
        session.partyCelebrateDelayOverride = 0
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

    @Test func claimedVictoryDeliversImmediatelyWhenUltimateHasNoCinematicVideo() {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.bloodthorn]
        )
        let companion = CombatantFixtures.combatant(
            id: "companion",
            role: .companion,
            abilities: []
        )
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 3,
            abilities: []
        )
        let session = BattleSession(openingHandDrawStagger: 0, outcomePresentationDelayOverride: 0)
        session.partyCelebrateDelayOverride = 0
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            rngSeed: BattleSessionTestSupport.deterministicBattleSeed,
            hero: hero,
            companion: companion,
            enemy: enemy,
            stageRewardsAlreadyClaimed: true
        )
        _ = session.activate(configuration)
        session.installPresentationContext(presentation)
        var deliveryCount = 0
        session.installClaimedVictoryHandler(ownerID: UUID()) { _, _ in
            deliveryCount += 1
        }
        let now = Date()

        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: now
        )

        #expect(session.outcome == .victory)
        #expect(session.spectacle.activeCinematic == nil)
        #expect(deliveryCount == 1)
    }
}

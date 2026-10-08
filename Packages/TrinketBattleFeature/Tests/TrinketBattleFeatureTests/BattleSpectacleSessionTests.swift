import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSpectacleSessionTests {
    @Test(arguments: [false, true])
    func `ultimate killing blow presents victory without blocking`(alreadyClaimed: Bool) {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.bloodthorn],
        )
        var deliveryCount = 0
        let progression = BattleProgressionProbe(completeVictory: { _, _, _ in
            deliveryCount += 1
            return .completed
        })
        defer { withExtendedLifetime(progression) {} }
        let session = BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 3,
                abilities: [],
            ),
            stageRewardsAlreadyClaimed: alreadyClaimed,
            progression: progression,
        )
        let now = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: now,
        )

        #expect(session.outcome == .victory)
        #expect(!session.canRetreat)
        if alreadyClaimed {
            #expect(deliveryCount == 1)
            #expect(!session.spectacle.outcomePresentation.isVictoryPresented)
        } else {
            #expect(deliveryCount == 0)
            #expect(session.spectacle.outcomePresentation.victorySummaryIfAvailable != nil)
            #expect(session.spectacle.outcomePresentation.isVictoryPresented)
        }
    }

    @Test func `ultimate aligns feedback with impact without blocking combat`() throws {
        let session = BattleSessionTestSupport.makeUltimateSession(
            heroID: "hero",
            abilities: [.slash, .fireball, .bloodthorn],
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now,
            ),
        )
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        presentPendingImpacts(in: session)
        #expect(!session.feedback.activeItems.isEmpty)
        #expect(session.canEndTurn == true)
    }

    @Test func `hero ultimate keeps combat ready while presenting impact feedback`() throws {
        let session = BattleSessionTestSupport.makeUltimateSession()
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now,
            ),
        )
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        presentPendingImpacts(in: session)
        #expect(!session.feedback.activeItems.isEmpty)
        #expect(session.canEndTurn == true)
    }

    @Test func `clear all presentation cancels pending celebration and outcome`() {
        let session = BattleSession(outcomePresentationDelayOverride: 60)
        session.partyCelebrateDelayOverride = .seconds(60)

        session.scheduleVictoryPresentation(after: .now)

        #expect(session.spectacle.celebrateTask.task != nil)
        #expect(session.spectacle.outcomeTask.task != nil)

        session.clearAllPresentation()

        #expect(session.spectacle.celebrateTask.task == nil)
        #expect(session.spectacle.outcomeTask.task == nil)
    }

    private func presentPendingImpacts(in session: BattleSession) {
        for impact in session.feedback.scheduledActions.filter(\.hasPendingImpact).map(\.impactAt).sorted() {
            session.feedback.advance(to: impact)
        }
    }
}

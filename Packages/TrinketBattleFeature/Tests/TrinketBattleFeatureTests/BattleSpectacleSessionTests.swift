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

    @Test(arguments: [false, true])
    func `abandoned suspended battle releases its presentation and cancels its wait`(atOutcome: Bool) async throws {
        let party = BattlePartyFixtures.quickWinParty()
        let (configuration, presentation) = BattleRunConfigurationTestSupport.make(
            hero: party.hero, companion: party.companion, enemy: party.enemy,
        )
        var session: BattleSession? = BattleSession(
            outcomePresentationDelayOverride: 60, partyCelebrateDelayOverride: 60,
        )
        if !atOutcome {
            session?.setSuspendedForScenePhase(true)
        }
        #expect(session?.activate(configuration, presentation: presentation) == true)
        if atOutcome {
            try BattleSessionTestSupport.driveUntilOutcome(#require(session))
            #expect(session?.outcome == .victory)
            session?.setSuspendedForScenePhase(true)
        }
        let task = try #require(atOutcome ? session?.spectacle.outcomeTask.task : session?.transitionTask.task)
        defer { task.cancel() }
        weak var releasedSession = session
        weak var releasedPresentation = session?.presentation

        // Let the owner task enter its suspended loop before releasing the last
        // external owner; a weak capture promoted across sleep would retain it.
        try await Task.sleep(for: .milliseconds(20))
        session = nil

        #expect(releasedSession == nil)
        #expect(releasedPresentation == nil)
        #expect(task.isCancelled)
        task.cancel()
        await task.value
    }

    private func presentPendingImpacts(in session: BattleSession) {
        for impact in session.feedback.scheduledActions.filter(\.hasPendingImpact).map(\.impactAt).sorted() {
            session.feedback.advance(to: impact)
        }
    }
}

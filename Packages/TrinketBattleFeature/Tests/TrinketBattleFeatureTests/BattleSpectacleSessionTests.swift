import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketTestSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

@MainActor
struct BattleSpectacleSessionTests {
    @Test(arguments: [false, true])
    func `unmapped ultimate killing blow presents victory without blocking`(alreadyClaimed: Bool) throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.bloodthorn],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 3,
                abilities: [],
            ),
            stageRewardsAlreadyClaimed: alreadyClaimed,
        )
        var deliveryCount = 0
        session.installClaimedVictoryHandler(ownerID: UUID()) { _, _ in
            deliveryCount += 1
        }
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
        #expect(session.spectacle.ultimateHighlightsByActorID.isEmpty || session.spectacle.ultimateHighlightsByActorID["hero"] != nil)
    }

    @Test func `unmapped ultimate records feedback immediately with in-frame highlight`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball, .bloodthorn],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: [],
            ),
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now,
            ),
        )
        let beforeFeedbackCount = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
        #expect(session.spectacle.ultimateHighlightsByActorID["hero"] != nil)
        #expect(session.canEndTurn == true)
    }

    @Test func `mapped hero ultimate shows in-frame highlight without blocking combat`() throws {
        let hero = CombatantFixtures.combatant(
            id: "knight",
            role: .hero,
            abilities: [.slash, .fireball, .avatarOfJustice],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: [],
            ),
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now,
            ),
        )
        let beforeFeedbackCount = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        let highlight = try #require(session.spectacle.ultimateHighlightsByActorID["knight"])
        #expect(highlight.abilityID == Ability.avatarOfJustice.id)
        #expect(highlight.actorID == "knight")
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
        #expect(session.canEndTurn == true)

        session.clearUltimateHighlight(for: "knight")
        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
    }

    @Test func `in-frame highlight auto clears after duration`() async throws {
        let hero = CombatantFixtures.combatant(
            id: "knight",
            role: .hero,
            abilities: [.slash, .fireball, .avatarOfJustice],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: [],
            ),
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now,
            ),
        )
        _ = session.playCard(cardID: ultimate.id, at: now)
        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] != nil)
        try await Task.sleep(for: .milliseconds(3300)) // TestSleepCheck: allow - deterministic highlight duration wait
        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] == nil)
        #expect(session.canEndTurn)
    }

    @Test func `always policy skips in-frame highlight but keeps feedback`() throws {
        let hero = CombatantFixtures.combatant(
            id: "knight",
            role: .hero,
            abilities: [.slash, .fireball, .avatarOfJustice],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: [],
            ),
            presentationEnvironment: BattleSessionTestSupport.presentationEnvironment(
                shouldAutoSkipUltimateCinematic: { _, _ in true },
            ),
        )

        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now,
            ),
        )
        let beforeFeedbackCount = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
    }

    @Test func `once per battle shows highlight once then skips`() throws {
        let hero = CombatantFixtures.combatant(
            id: "knight",
            role: .hero,
            abilities: [.slash, .fireball, .avatarOfJustice],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 2000,
                abilities: [],
            ),
            presentationEnvironment: BattleSessionTestSupport.presentationEnvironment(
                shouldAutoSkipUltimateCinematic: { actorID, presentedActors in
                    presentedActors.contains(actorID)
                },
            ),
        )

        let firstUltimateAt = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.avatarOfJustice.id,
            on: session,
            at: firstUltimateAt,
        )
        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] != nil)
        session.clearUltimateHighlight(for: "knight")

        let secondUltimateAt = firstUltimateAt.addingTimeInterval(10)
        let secondUltimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: secondUltimateAt,
            ),
        )
        let playAt = secondUltimateAt.addingTimeInterval(5)
        session.feedback.pruneExpired(at: playAt, notifyPresentation: false)
        let feedbackBefore = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: secondUltimate.id,
            at: playAt,
        )
        #expect(session.spectacle.ultimateHighlightsByActorID["knight"] == nil)
        #expect(session.feedback.activeItems.count > feedbackBefore)
    }

    @Test func `enemy ultimate does not present highlight`() throws {
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 200,
            abilities: [.slash, .fireball, .bloodthorn],
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 200,
                abilities: [],
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 200,
                abilities: [],
            ),
            enemy: enemy,
        )

        for _ in 0 ..< 6 {
            session.endTurn()
        }

        #expect(session.spectacle.ultimateHighlightsByActorID.isEmpty)
    }

    @Test func `clear all presentation cancels pending celebration and highlights`() {
        let session = BattleSession(outcomePresentationDelayOverride: 60)
        session.partyCelebrateDelayOverride = .seconds(60)

        session.scheduleVictoryPresentation(after: .now)

        #expect(session.spectacle.pendingPartyCelebrateTask != nil)
        #expect(session.spectacle.pendingOutcomePresentationTask != nil)

        session.clearAllPresentation()

        #expect(session.spectacle.pendingPartyCelebrateTask == nil)
        #expect(session.spectacle.pendingOutcomePresentationTask == nil)
    }
}

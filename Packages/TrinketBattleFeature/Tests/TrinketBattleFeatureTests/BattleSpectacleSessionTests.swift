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
    func `unmapped ultimate killing blow presents victory without cinematic`(
        alreadyClaimed: Bool,
    ) throws {
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
        #expect(session.spectacle.activeCinematic == nil)
        #expect(!session.canRetreat)
        if alreadyClaimed {
            #expect(deliveryCount == 1)
            #expect(!(session.spectacle.isShowingVictory))
        } else {
            #expect(deliveryCount == 0)
            #expect(session.spectacle.victorySummary != nil)
            #expect(session.spectacle.isShowingVictory)
        }
    }

    @Test func `unmapped ultimate skips cinematic and records feedback`() throws {
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

        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
    }

    @Test func `playing mapped hero ultimate defers feedback until cinematic completes`() throws {
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

        let cinematic = try #require(session.spectacle.activeCinematic)
        #expect(cinematic.abilityID == Ability.avatarOfJustice.id)
        #expect(cinematic.actorID == "knight")
        #expect(session.feedback.activeItems.count == beforeFeedbackCount)
        #expect(session.canEndTurn == false)

        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        #expect(session.spectacle.activeCinematic?.phase == .collapsing)

        session.completeCinematicCollapse(at: now.addingTimeInterval(1))
        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)

        let flushAt = now.addingTimeInterval(1)
        let deferredItems = session.feedback.activeItems.filter { $0.availableAt >= flushAt }
        let stagger = BattleMotion.feedbackStreamStagger
        for targetItems in Dictionary(grouping: deferredItems, by: \.targetID).values {
            let starts = targetItems.map(\.availableAt).sorted()
            for (earlier, later) in zip(starts, starts.dropFirst()) {
                #expect(abs(later.timeIntervalSince(earlier) - stagger) < 0.001)
            }
        }
    }

    @Test func `cinematic session watchdog clears stuck ultimate overlay`() async throws {
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
        session.cinematicSessionWatchdogOverride = .milliseconds(50)
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.avatarOfJustice.id,
                on: session,
                at: now,
            ),
        )
        _ = session.playCard(cardID: ultimate.id, at: now)
        #expect(session.spectacle.activeCinematic != nil)
        #expect(
            try await BattleSessionTestSupport.waitUntil {
                session.spectacle.activeCinematic == nil
            },
        )
        #expect(session.canEndTurn)
    }

    @Test func `always policy auto skips ultimate cinematic`() throws {
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

        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
    }

    @Test func `once per battle shows hero ultimate once then auto skips`() throws {
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
        #expect(session.spectacle.activeCinematic?.actorID == "knight")
        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        session.completeCinematicCollapse(at: firstUltimateAt.addingTimeInterval(1))

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
        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > feedbackBefore)
    }

    @Test func `enemy ultimate does not present cinematic`() throws {
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

        #expect(session.spectacle.activeCinematic == nil)
    }

    @Test func `begin cinematic collapse ignores stale expected ID`() throws {
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
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
        )

        let cinematic = try #require(session.spectacle.activeCinematic)
        session.markCinematicPlaying()

        session.beginCinematicCollapse(expectedID: cinematic.id &+ 1)
        #expect(session.spectacle.activeCinematic?.phase == .playing)
        #expect(session.spectacle.activeCinematic?.id == cinematic.id)

        session.beginCinematicCollapse(expectedID: cinematic.id)
        #expect(session.spectacle.activeCinematic?.phase == .collapsing)
    }

    @Test func `clear all presentation cancels pending celebration`() {
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

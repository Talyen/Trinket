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
    @Test func playingSkillCardShowsCallout() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 200,
                abilities: []
            )
        )

        let now = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.fireball.id,
            on: session,
            at: now
        )

        let callout = try #require(session.spectacle.activeSkillCallout)
        #expect(callout.actorID == "hero")
        #expect(callout.abilityID == Ability.fireball.id)
        #expect(callout.abilityName == Ability.fireball.name)
        #expect(callout.expiresAt > now)
    }

    @Test func ultimateKillingBlowDefersVictoryUntilCinematicCollapse() throws {
        // Only Bloodthorn in the deck so draw cycling cannot kill before the Ultimate.
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 3,
                abilities: []
            )
        )
        let now = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: now
        )

        #expect(session.outcome == .victory)
        #expect(session.spectacle.activeCinematic != nil)
        #expect(session.spectacle.victorySummary != nil)
        #expect(!session.spectacle.isShowingVictory)
        #expect(!session.canRetreat)

        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        session.completeCinematicCollapse(at: now.addingTimeInterval(1))

        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.spectacle.isShowingVictory)
        #expect(!session.canRetreat)
    }

    @Test func playingHeroUltimateDefersFeedbackUntilCinematicCompletes() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: []
            )
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now
            )
        )
        let beforeFeedbackCount = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now
        )

        let cinematic = try #require(session.spectacle.activeCinematic)
        #expect(cinematic.abilityID == Ability.bloodthorn.id)
        #expect(cinematic.actorID == "hero")
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
        let stagger = TrinketMotion.Battle.feedbackStreamStagger
        for targetItems in Dictionary(grouping: deferredItems, by: \.targetID).values {
            let starts = targetItems.map(\.availableAt).sorted()
            for (earlier, later) in zip(starts, starts.dropFirst()) {
                #expect(abs(later.timeIntervalSince(earlier) - stagger) < 0.001)
            }
        }
    }

    @Test func alwaysPolicyAutoSkipsUltimateCinematic() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: []
            ),
            presentationEnvironment: BattleSessionTestSupport.presentationEnvironment(
                shouldAutoSkipUltimateCinematic: { _, _ in true }
            )
        )

        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now
            )
        )
        let beforeFeedbackCount = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now
        )

        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > beforeFeedbackCount)
    }

    @Test func oncePerBattleShowsHeroUltimateOnceThenAutoSkips() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 2000,
                abilities: []
            ),
            presentationEnvironment: BattleSessionTestSupport.presentationEnvironment(
                shouldAutoSkipUltimateCinematic: { actorID, presentedActors in
                    presentedActors.contains(actorID)
                }
            )
        )

        let firstUltimateAt = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: firstUltimateAt
        )
        #expect(session.spectacle.activeCinematic?.actorID == "hero")
        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        session.completeCinematicCollapse(at: firstUltimateAt.addingTimeInterval(1))

        let secondUltimateAt = Date()
        let secondUltimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: secondUltimateAt
            )
        )
        let feedbackBefore = session.feedback.activeItems.count
        _ = session.playCard(
            cardID: secondUltimate.id,
            at: secondUltimateAt
        )
        #expect(session.spectacle.activeCinematic == nil)
        #expect(session.feedback.activeItems.count > feedbackBefore)
    }

    @Test func enemyUltimateUsesSkillCalloutNotCinematic() throws {
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 200,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.combatant(
                id: "hero",
                role: .hero,
                maxHealth: 200,
                abilities: []
            ),
            companion: CombatantFixtures.combatant(
                id: "companion",
                role: .companion,
                maxHealth: 200,
                abilities: []
            ),
            enemy: enemy
        )

        // Enemy ultimate cadence is every 6th action.
        for _ in 0 ..< 6 {
            session.endTurn()
        }

        #expect(session.spectacle.activeCinematic == nil)
        let callout = try #require(session.spectacle.activeSkillCallout)
        #expect(callout.actorID == "enemy")
        #expect(callout.abilityTierMatchesUltimateOrSkill)
    }

    @Test func beginCinematicCollapseIgnoresStaleExpectedID() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                abilities: []
            )
        )
        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now
            )
        )
        _ = session.playCard(
            cardID: ultimate.id,
            at: now
        )

        let cinematic = try #require(session.spectacle.activeCinematic)
        session.markCinematicPlaying()

        // Stale fallback/video task from a prior overlay must not collapse the live cinematic.
        session.beginCinematicCollapse(expectedID: cinematic.id &+ 1)
        #expect(session.spectacle.activeCinematic?.phase == .playing)
        #expect(session.spectacle.activeCinematic?.id == cinematic.id)

        session.beginCinematicCollapse(expectedID: cinematic.id)
        #expect(session.spectacle.activeCinematic?.phase == .collapsing)
    }

    @Test func clearAllPresentationCancelsPendingCelebration() {
        let session = BattleSession(outcomePresentationDelayOverride: 60)
        session.partyCelebrateDelayOverride = 60

        session.scheduleVictoryPresentation(after: .now)

        #expect(session.spectacle.pendingPartyCelebrateTask != nil)
        #expect(session.spectacle.pendingOutcomePresentationTask != nil)

        session.clearAllPresentation()

        #expect(session.spectacle.pendingPartyCelebrateTask == nil)
        #expect(session.spectacle.pendingOutcomePresentationTask == nil)
    }
}

private extension SkillCalloutPresentation {
    var abilityTierMatchesUltimateOrSkill: Bool {
        abilityID == Ability.bloodthorn.id || abilityID == Ability.fireball.id
    }
}

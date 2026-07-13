import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence
import TrinketTestSupport
@testable import BattleEngine
@testable import Trinket

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

        let callout = try #require(session.activeSkillCallout)
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
                maxHealth: 5,
                abilities: []
            )
        )
        let options = try OptionsStore(
            defaults: #require(UserDefaults(suiteName: "BattleSpectacleKillCinematic.\(UUID().uuidString)"))
        )
        options.ultimateCinematicSkipPolicy = .always
        session.options = options

        let now = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: now
        )

        #expect(session.outcome == .victory)
        #expect(session.activeCinematic != nil)
        #expect(session.victorySummary != nil)
        #expect(!session.isShowingVictory)
        #expect(!session.canRetreat)

        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        session.completeCinematicCollapse(at: now.addingTimeInterval(1))

        #expect(session.activeCinematic == nil)
        #expect(session.isShowingVictory)
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
        let options = try OptionsStore(
            defaults: #require(UserDefaults(suiteName: "BattleSpectacleSessionTests.\(UUID().uuidString)"))
        )
        options.ultimateCinematicSkipPolicy = .always
        session.options = options

        let now = Date()
        let ultimate = try #require(
            BattleSessionTestSupport.drawUntilPlayable(
                Ability.bloodthorn.id,
                on: session,
                at: now
            )
        )
        let beforeFeedbackCount = session.activeFeedbackEvents.count
        _ = session.playCard(
            cardID: ultimate.id,
            at: now,
            journey: .initial,
            homestead: .freshStart
        )

        let cinematic = try #require(session.activeCinematic)
        #expect(cinematic.abilityID == Ability.bloodthorn.id)
        #expect(cinematic.actorID == "hero")
        #expect(session.activeFeedbackEvents.count == beforeFeedbackCount)
        #expect(session.canEndTurn == false)

        session.markCinematicPlaying()
        session.requestSkipCinematic(at: now.addingTimeInterval(TrinketMotion.Battle.ultimateSkipLockout + 0.01))
        #expect(session.activeCinematic?.phase == .collapsing)

        session.completeCinematicCollapse(at: now.addingTimeInterval(1))
        #expect(session.activeCinematic == nil)
        #expect(session.activeFeedbackEvents.count > beforeFeedbackCount)
        #expect(session.activeFeedbackItems.count > beforeFeedbackCount)

        let flushAt = now.addingTimeInterval(1)
        let availableOffsets = session.activeFeedbackItems
            .filter { $0.availableAt >= flushAt }
            .map { $0.availableAt.timeIntervalSince(flushAt) }
            .sorted()
        if availableOffsets.count >= 2 {
            #expect(availableOffsets[1] >= TrinketMotion.Battle.ultimateChipStagger - 0.001)
        }
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
            )
        )
        let options = try OptionsStore(
            defaults: #require(UserDefaults(suiteName: "BattleSpectacleOncePerBattle.\(UUID().uuidString)"))
        )
        options.ultimateCinematicSkipPolicy = .oncePerBattle
        session.options = options

        let firstUltimateAt = Date()
        _ = BattleSessionTestSupport.playAbility(
            Ability.bloodthorn.id,
            on: session,
            at: firstUltimateAt
        )
        #expect(session.activeCinematic?.actorID == "hero")
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
        let feedbackBefore = session.activeFeedbackEvents.count
        _ = session.playCard(
            cardID: secondUltimate.id,
            at: secondUltimateAt,
            journey: .initial,
            homestead: .freshStart
        )
        #expect(session.activeCinematic == nil)
        #expect(session.activeFeedbackEvents.count > feedbackBefore)
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
            _ = session.endTurn(journey: .initial, homestead: .freshStart)
        }

        #expect(session.activeCinematic == nil)
        let callout = try #require(session.activeSkillCallout)
        #expect(callout.actorID == "enemy")
        #expect(callout.abilityTierMatchesUltimateOrSkill)
    }
}

private extension SkillCalloutPresentation {
    var abilityTierMatchesUltimateOrSkill: Bool {
        abilityID == Ability.bloodthorn.id || abilityID == Ability.fireball.id
    }
}

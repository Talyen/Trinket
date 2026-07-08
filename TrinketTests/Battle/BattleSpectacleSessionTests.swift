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
    @Test func skillCastSoftHoldsTickAdvancementAndShowsCallout() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash, .fireball]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 200,
                actionIntervalTicks: 100,
                abilities: []
            )
        )

        // actionCount 0 → turn 1 basic; 1 → turn 2 basic; 2 → turn 3 skill
        _ = session.advanceOneStep()
        _ = session.advanceOneStep()
        let now = Date()
        _ = session.advanceOneStep(at: now)

        let callout = try #require(session.activeSkillCallout)
        #expect(callout.actorID == "hero")
        #expect(callout.abilityID == Ability.fireball.id)
        #expect(callout.abilityName == Ability.fireball.name)
        #expect(session.canAutoAdvanceTick(at: now) == false)
        #expect(session.canAutoAdvanceTick(at: now.addingTimeInterval(TrinketMotion.Battle.skillSoftHold + 0.05)))
    }

    @Test func heroUltimateDefersFeedbackUntilCinematicCompletes() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 500,
                actionIntervalTicks: 100,
                abilities: []
            )
        )
        let options = try OptionsStore(defaults: #require(UserDefaults(suiteName: "BattleSpectacleSessionTests.\(UUID().uuidString)")))
        options.ultimateCinematicSkipPolicy = .always
        session.options = options

        // Turns 1–5: basics/skills; turn 6: ultimate
        for _ in 0 ..< 5 {
            _ = session.advanceOneStep()
        }
        let beforeFeedbackCount = session.activeFeedbackEvents.count
        let now = Date()
        _ = session.advanceOneStep(at: now)

        let cinematic = try #require(session.activeCinematic)
        #expect(cinematic.abilityID == Ability.bloodthorn.id)
        #expect(cinematic.actorID == "hero")
        #expect(session.activeFeedbackEvents.count == beforeFeedbackCount)
        #expect(session.canAutoAdvanceTick(at: now) == false)
        #expect(session.isPaused)

        session.markCinematicPlaying()
        session.requestSkipCinematic(at: now.addingTimeInterval(TrinketMotion.Battle.ultimateSkipLockout + 0.01))
        #expect(session.activeCinematic?.phase == .collapsing)

        session.completeCinematicCollapse(at: now.addingTimeInterval(1))
        #expect(session.activeCinematic == nil)
        #expect(session.activeFeedbackEvents.count > beforeFeedbackCount)
    }

    @Test func oncePerBattleShowsHeroUltimateOnceThenAutoSkips() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 1,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: hero,
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100, abilities: []),
            enemy: CombatantFixtures.combatant(
                id: "enemy",
                role: .enemy,
                maxHealth: 2000,
                actionIntervalTicks: 100,
                abilities: []
            )
        )
        let options = try OptionsStore(
            defaults: #require(UserDefaults(suiteName: "BattleSpectacleOncePerBattle.\(UUID().uuidString)"))
        )
        options.ultimateCinematicSkipPolicy = .oncePerBattle
        session.options = options

        // First Ultimate (turn 6)
        for _ in 0 ..< 5 {
            _ = session.advanceOneStep()
        }
        let firstUltimateAt = Date()
        _ = session.advanceOneStep(at: firstUltimateAt)
        #expect(session.activeCinematic?.actorID == "hero")
        session.markCinematicPlaying()
        session.beginCinematicCollapse()
        session.completeCinematicCollapse(at: firstUltimateAt.addingTimeInterval(1))

        // Next Ultimate for same hero (turn 12) should auto-skip cinematic
        for _ in 0 ..< 5 {
            _ = session.advanceOneStep()
        }
        let secondUltimateAt = Date()
        let feedbackBefore = session.activeFeedbackEvents.count
        _ = session.advanceOneStep(at: secondUltimateAt)
        #expect(session.activeCinematic == nil)
        #expect(session.activeFeedbackEvents.count > feedbackBefore)
        #expect(session.canAutoAdvanceTick(at: secondUltimateAt))
    }

    @Test func enemyUltimateUsesSkillCalloutNotCinematic() throws {
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: 200,
            actionIntervalTicks: 1,
            abilities: [.slash, .fireball, .bloodthorn]
        )
        let session = try BattleSessionTestSupport.makeConfiguredSession(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 200, actionIntervalTicks: 100, abilities: []),
            pet: CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 200, actionIntervalTicks: 100, abilities: []),
            enemy: enemy
        )

        for _ in 0 ..< 5 {
            _ = session.advanceOneStep()
        }
        _ = session.advanceOneStep()

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

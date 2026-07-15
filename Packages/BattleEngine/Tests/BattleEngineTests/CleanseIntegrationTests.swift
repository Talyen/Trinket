import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for cleanse abilities through card combat.
struct CleanseIntegrationTests {
    @Test func cleanseAllRemovesDebuffsButLeavesShields() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.cleanse]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 10), remainingTicks: 6)
            ]
        )

        _ = try BattleTestFixtures.playUntilAbility("Cleanse", on: &battle)

        try #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
        try #expect(battle.hasHeroEffect {
            if case .shield = $0 {
                return true
            }; return false
        })
    }

    @Test func cleanseSpecificKeywordRemovesMatchingDebuffsOnUse() throws {
        let cleansePoison = Ability(
            id: "cleanse-poison",
            name: "Cleanse Poison",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Poisoned.",
            effects: [.cleanse(.poison)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            abilities: [cleansePoison]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ]
        )

        let events = try BattleTestFixtures.playCardNamed("Cleanse Poison", owner: .hero, on: &battle)

        try #expect(events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        try #expect(!(battle.hasHeroEffect {
            if case .poison = $0 {
                return true
            }; return false
        }))
        try #expect(battle.hasHeroEffect {
            if case .burn = $0 {
                return true
            }; return false
        })
    }

    @Test func cleanseStunRemovesControlMeterBuildup() throws {
        let cleanseAbility = Ability(
            id: "test-cleanse",
            name: "Test Cleanse",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse Stunned.",
            targetedEffects: [TargetedEffect(.cleanse(.stun))]
        )
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [cleanseAbility]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)
            ]
        )

        _ = try BattleTestFixtures.playCardNamed("Test Cleanse", owner: .hero, on: &battle)

        try #expect(!battle.hasHeroEffect { $0.isControlMeter }, "Cleanse removed buildup")
    }
}

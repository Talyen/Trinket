import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for cleanse abilities through full battle ticks.
@Suite
struct CleanseIntegrationTests {
    @Test func cleanseAllRemovesDebuffsWhenAbilityFires() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            abilities: [.slash, .cleanse, .smite]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(2), remainingTicks: 0)
            ]
        )

        BattleTestFixtures.advanceTicks(6, on: &battle)

        #expect(!(battle.activeEffects(of: battle.hero)).contains(where: \.effect.isRemovableDebuff))
    }

    @Test func cleanseSpecificKeywordRemovesMatchingDebuffsOnUse() {
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
            actionIntervalTicks: 2,
            abilities: [cleansePoison]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        let step = battle.advanceOneStep()

        #expect(step.events.contains { $0.effectKind == .cleanseApplied && $0.keyword == .poison })
        #expect(!(battle.hasHeroEffect { if case .poison = $0 { return true }; return false }))
        #expect(battle.hasHeroEffect { if case .burn = $0 { return true }; return false })
    }

    @Test func cleanseAllRemovesAllDebuffsButLeavesShields() {
        let cleanseAll = Ability(
            id: "cleanse-all",
            name: "Cleanse All",
            tier: .basic,
            directDamage: 0,
            description: "Cleanse all.",
            effects: [.cleanse(nil)]
        )
        let hero = Combatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [cleanseAll]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 10, 6), remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        let step = battle.advanceOneStep()

        #expect(step.events.contains { $0.effectKind == .cleanseApplied })
        #expect(!(battle.hasHeroEffect { if case .poison = $0 { return true }; return false }))
        #expect(!(battle.hasHeroEffect { if case .burn = $0 { return true }; return false }))
        #expect(battle.hasHeroEffect { if case .shield = $0 { return true }; return false })
    }

    @Test func cleanseStunRemovesControlMeterBuildup() {
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
            actionIntervalTicks: 1,
            abilities: [cleanseAbility]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 10)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 5, 10), remainingTicks: 0)
            ]
        )

        BattleTestFixtures.advanceTicks(1, on: &battle)

        #expect(!(battle.hasHeroEffect { $0.isControlMeter }, "Cleanse removed buildup"))
    }
}

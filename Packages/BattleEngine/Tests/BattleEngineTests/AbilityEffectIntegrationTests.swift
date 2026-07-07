import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for catalog abilities that combine damage, effects, and resources.
@Suite
struct AbilityEffectIntegrationTests {
    @Test func blackjackGrantsGoldAlongsideStunDamage() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.blackjack]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy, initialGold: 0)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        #expect(battle.gold == 1)
    }

    @Test func poisonEffectAppliesThroughTargetedEffects() {
        let poisonAbility = Ability(
            id: "legacy",
            name: "Legacy",
            tier: .basic,
            directDamage: 1,
            description: "Legacy",
            targetedEffects: [TargetedEffect(.poison(2))]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [poisonAbility])
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)

        #expect(battle.activeEffects(of: battle.enemy).contains { $0.keyword == .poison })
    }

    @Test func bloodthornDealsComponentDamageAndAppliesDoTs() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            actionIntervalTicks: 2,
            abilities: [.bloodthorn]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        _ = try #require(
            BattleTestFixtures.advanceUntilAbility("Bloodthorn", on: &battle),
            "Expected Bloodthorn to resolve in battle"
        )

        // Three typed damage components (2 nature, 2 bleed, 2 poison) resolve
        // before the seeded DoTs tick.
        #expect(battle.health(of: battle.enemy) == 94)
        #expect(battle.hasEnemyEffect { if case .bleed = $0 { return true }; return false })
        #expect(battle.hasEnemyEffect { if case .poison = $0 { return true }; return false })
        #expect(battle.hasHeroEffect { if case .leech = $0 { return true }; return false })
    }

    @Test func prayerCleanseRandomRemovesOneDebuffAndHeals() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 10,
            actionIntervalTicks: 2,
            abilities: [.prayer]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        #expect(battle.health(of: battle.hero) < 10)

        let step = BattleTestFixtures.advanceUntilAbility("Prayer", on: &battle)
        guard let step else {
            return Issue.record("Expected Prayer to resolve in battle")
        }
        #expect(step.events.contains { $0.effectKind == .instantHeal && $0.keyword == .health })
        #expect(battle.activeEffects(of: battle.hero).filter(ActiveEffect.isDebuff).count == 1)
    }
}

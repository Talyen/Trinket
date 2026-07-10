import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for healing and leech through card combat.
@Suite
struct RestorationIntegrationTests {
    @Test func instantHealRestoresHealth() throws {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [heal])
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(events.contains { event in
            guard event.effectKind == .instantHeal else { return false }
            return ActionEventFormatter.display(for: event).text == "+\(event.amount) Health"
        })
    }

    @Test func leechHealsAttackerOnDamageDealt() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [.slash])
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .standardLeechBuff, remainingTicks: 6)
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Slash", owner: .hero, on: &battle)

        // 10% leech of 1 damage → ceil(0.1) = 1 heal.
        try #expect(battle.health(of: battle.hero) == 9)
        try #expect(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech })
    }

    /// Verifies that an enemy `instantHeal` ability restores health when below max.
    /// Uses `activeEnemyEffects` burn to pre-damage the enemy before it acts.
    @Test func enemyInstantHealRestoresHealthWhenBelowMax() throws {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)]
        )
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            abilities: [selfHeal]
        )
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        // Enemy acts during endTurn (before effect tick). Burn is still at full potency
        // for the apply-on-seed path; damage from burn happens at end-of-round after enemy heal.
        // Seed damage manually so enemy is below max when it heals.
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 16 }
        }

        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
        // After heal to full, burn may tick; health should still be near max.
        try #expect(battle.health(of: battle.enemy) >= 16)
    }
}

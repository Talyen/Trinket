import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for healing and leech through card combat.
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
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
    }

    @Test func leechHealsAttackerOnDamageDealt() throws {
        let leechSlash = Ability(
            id: "leech-slash",
            name: "Leech Slash",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .physical,
            hasLeech: true
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [leechSlash])
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTurns: 0),
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Leech Slash", owner: .hero, on: &battle)

        // 50% leech of 2 damage → 1 heal.
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
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            abilities: [selfHeal]
        )
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ]
        )

        // Enemy acts during endTurn (before the effect pass). Burn is still at full potency
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

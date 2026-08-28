import BattleEngine
import Testing
import TrinketContent
import TrinketCore

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
        let companion = BattleTestFixtures.passiveCompanion()
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
        let companion = BattleTestFixtures.passiveCompanion()
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

        try #expect(battle.health(of: battle.hero) > 8)
        try #expect(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech && $0.amount > 0 })
    }

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
        let companion = BattleTestFixtures.passiveCompanion()
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

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 16 }
        }

        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
        try #expect(battle.health(of: battle.enemy) >= 16)
    }
}

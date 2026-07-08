import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for healing and leech through full battle ticks.
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
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [heal])
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

        _ = battle.advanceOneStep()
        try #expect(battle.health(of: battle.hero) == 8)

        let events = battle.advanceOneStep().events

        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(events.contains { event in
            guard event.effectKind == .instantHeal else { return false }
            return ActionEventFormatter.display(for: event).text == "+\(event.amount) Health"
        })
    }

    @Test func leechHealsAttackerOnDamageDealt() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [.slash])
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

        _ = battle.advanceOneStep()
        try #expect(battle.health(of: battle.hero) == 8)

        let events = battle.advanceOneStep().events

        try #expect(battle.health(of: battle.hero) == 8)
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
            actionIntervalTicks: 1,
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

        let step = battle.advanceOneStep()

        try #expect(battle.health(of: battle.enemy) == 20)
        try #expect(step.events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
    }
}

import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for shield, armor, and mitigation through card combat.
@Suite
struct MitigationIntegrationTests {
    @Test func shieldAbsorbsDamageBeforeHealth() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 10), remainingTicks: 10)
            ]
        )

        BattleTestFixtures.endTurns(3, on: &battle)

        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func armorMitigatesIncomingDamage() throws {
        let hero = BattleTestFixtures.passiveCombatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.judgment])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        // One enemy Judgment hit with 50% armor: 6 → 3 damage.
        _ = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: battle.hero) == 17)
    }

    @Test func effectiveDamageMatchesEventAmount() throws {
        let hero = BattleTestFixtures.passiveCombatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.judgment])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        let events = BattleTestFixtures.endTurn(on: &battle)
        let damageEvent = events.first { $0.kind == .ability && $0.actorName == "Enemy" }

        try #expect(damageEvent?.amount == 3)
        try #expect(battle.health(of: battle.hero) == 17)
    }

    @Test func sunderArmorHalvesEnemyArmor() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.sunderArmor])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)
            ]
        )

        _ = try BattleTestFixtures.playCardNamed("Sunder Armor", owner: .pet, on: &battle)

        try #expect(battle.hasEnemyEffect { effect in
            if case .mitigation(.armor, 0.20, _) = effect { return true }
            return false
        })
    }
}

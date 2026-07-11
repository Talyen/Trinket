import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for shield, armor, and mitigation through card combat.
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
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 0)
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

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
                ActiveEffect(id: 1, effect: .mitigation(.armor, 3), remainingTicks: 0)
            ]
        )

        // One enemy Judgment hit with flat Armor 3: 6 → reduce by min(3, floor(6/2))=3 → 3 damage.
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
                ActiveEffect(id: 1, effect: .mitigation(.armor, 3), remainingTicks: 0)
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
                ActiveEffect(id: 1, effect: .mitigation(.armor, 3), remainingTicks: 6)
            ]
        )

        _ = try BattleTestFixtures.playCardNamed("Sunder Armor", owner: .pet, on: &battle)

        try #expect(battle.hasEnemyEffect { effect in
            if case .mitigation(.armor, 1) = effect {
                return true
            }
            return false
        })
    }
}

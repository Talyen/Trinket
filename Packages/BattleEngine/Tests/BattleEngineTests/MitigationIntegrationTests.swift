import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Integration tests for Block absorption and Toughness-based inherent mitigation through card combat.
struct MitigationIntegrationTests {
    @Test func shieldAbsorbsDamageBeforeHealth() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 0)
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func toughnessMitigatesIncomingDamage() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 15),
            maxHealth: 20,
            actionIntervalTicks: 100
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.judgment])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy
        )
        let initial = battle.health(of: battle.hero)

        // One enemy Judgment hit: 6 → reduce by min(toughnessMitigation=3, floor(6/2)=3) → 3 damage.
        let events = BattleTestFixtures.endTurn(on: &battle)
        let damageEvent = events.first { $0.kind == .ability && $0.actorName == "Enemy" }

        try #expect(damageEvent?.amount == 3)
        try #expect(battle.health(of: battle.hero) == initial - 3)
    }

    @Test func sunderHalvesEnemyBlock() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [.sunderArmor])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTicks: 0)
            ]
        )

        // Sunder's own 3 damage absorbs into Block first (10 → 7), then halves the remainder (7 → 3).
        _ = try BattleTestFixtures.playCardNamed("Sunder", owner: .companion, on: &battle)

        try #expect(battle.hasEnemyEffect { effect in
            if case .shield(.block, 3) = effect {
                return true
            }
            return false
        })
    }
}

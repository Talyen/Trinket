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
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)
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
            actionIntervalTurns: 100
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let heavyStrike = Ability(
            id: "heavy-strike",
            name: "Heavy Strike",
            tier: .ultimate,
            directDamage: 6,
            description: "Deal 6 Physical damage."
        )
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [heavyStrike])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy
        )
        let initial = battle.health(of: battle.hero)

        // One enemy Heavy Strike: 6 damage.
        // Toughness 15 DR% = 15 / (15 + 80) = 0.15789.
        // 6 * (1 - 0.15789) = 5.052 → rounded to 5 damage.
        let events = BattleTestFixtures.endTurn(on: &battle)
        let damageEvent = events.first { $0.kind == .ability && $0.actorName == "Enemy" }

        try #expect(damageEvent?.amount == 5)
        try #expect(battle.health(of: battle.hero) == initial - 5)
    }

    @Test func sunderHalvesEnemyBlock() throws {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let companion = Combatant(id: "companion", name: "Companion", role: .companion, maxHealth: 20, abilities: [.sunder])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)
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

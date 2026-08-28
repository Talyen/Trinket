import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct MitigationIntegrationTests {
    @Test func toughnessMitigatesIncomingDamage() throws {
        let hero = BattleTestFixtures.statHero(
            abilities: [],
            stats: PrimaryStats(toughness: 15),
            maxHealth: 20,
            actionIntervalTurns: 100
        )
        let companion = BattleTestFixtures.passiveCompanion()
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
                ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0),
            ]
        )

        _ = try BattleTestFixtures.playCardNamed("Sunder", owner: .companion, on: &battle)

        try #expect(battle.hasEnemyEffect { effect in
            if case .shield(.block, 3) = effect {
                return true
            }
            return false
        })
    }
}

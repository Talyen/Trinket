import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct RestorationIntegrationTests {
    @Test func `lingering blessing keeps pixies healing bonuses and protective bloom`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 50, companionMaxHealth: 50,
            heroModifiers: CombatModifierProfile(healthRestoredBonus: 7),
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t2_1", "pixie_health_t2_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        let card = BattleCardCombatEngine.deal(.heal, owner: .companion, context: &battle)
        try battle.playCard(cardID: card.id)

        for _ in 0 ..< 3 {
            let health = battle.health(of: battle.hero)
            let enemyHealth = battle.health(of: battle.enemy)
            let events = battle.endTurn()
            let tick = try #require(events.first { $0.abilityName == "Lingering Blessing" })
            #expect(battle.health(of: battle.hero) - health == (tick.isCritical ? 2 : 1))
            #expect(enemyHealth - battle.health(of: battle.enemy) == 2)
        }
        let health = battle.health(of: battle.hero)
        let events = battle.endTurn()
        #expect(battle.health(of: battle.hero) == health)
        #expect(!events.contains { $0.abilityName == "Lingering Blessing" })
    }

    @Test func `instant heal restores health`() throws {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)],
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [heal])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ],
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Heal", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) == 10)
        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
    }

    @Test func `leech heals attacker on damage dealt`() throws {
        let leechSlash = Ability(
            id: "leech-slash",
            name: "Leech Slash",
            tier: .basic,
            directDamage: 2,
            damageKeyword: .physical,
            hasLeech: true,
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, abilities: [leechSlash])
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTurns: 0),
            ],
        )

        _ = BattleTestFixtures.endTurn(on: &battle)
        try #expect(battle.health(of: battle.hero) == 8)

        let events = try BattleTestFixtures.playCardNamed("Leech Slash", owner: .hero, on: &battle)

        try #expect(battle.health(of: battle.hero) > 8)
        try #expect(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech && $0.amount > 0 })
    }

    @Test func `enemy instant heal restores health when below max`() throws {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", name: "Hero", role: .hero)
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            abilities: [selfHeal],
        )
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTurns: 0),
            ],
        )

        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: enemy) { $0.currentHealth = 16 }
        }

        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(events.contains { $0.effectKind == .instantHeal && $0.amount > 0 })
        try #expect(battle.health(of: battle.enemy) >= 16)
    }
}

import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsResistanceRegressionTests {
    @Test func `fully resisted Retaliatory reflection grants neither Spiteful nor Spitebloom`() throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spiteful", "spitebloom"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 5,
            heroModifiers: profile,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 1)]),
        )
        battle.appliesFightPacing = false

        let reflected = battle.resolveDamage(DamageRequest(
            amount: 20, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
        #expect(!reflected.events.contains { $0.abilityName == "Spiteful" || $0.abilityName == "Spitebloom" })
        let ordinary = battle.resolveDamage(DamageRequest(
            amount: 20, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(ordinary.healthLost == 20)
    }

    @Test(arguments: [Keyword.physical, .holy, .poison])
    func `Briar Ward resists actual Thorns including converted retaliation`(keyword: Keyword) {
        var hero = CombatModifierProfile.zero
        hero.triggers.thornsDealHoly = keyword == .holy
        hero.triggers.thornShedding = keyword == .poison
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: hero,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 0.5)]),
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let hit = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(hit.events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 4 })
        let ordinary = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(ordinary.healthLost == 8)
    }
}

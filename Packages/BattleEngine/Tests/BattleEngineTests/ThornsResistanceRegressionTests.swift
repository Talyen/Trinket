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
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 5,
            heroModifiers: profile,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 1)]), appliesFightPacing: false,
        )

        let reflected = battle.recordingResult { context in context.resolveTestDamage(
            20,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }

        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
        #expect(!reflected.events.contains { $0.abilityName == "Spiteful" || $0.abilityName == "Spitebloom" })
        let ordinary = battle.resolveTestDamage(
            20,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(ordinary.healthLost == 20)
    }

    @Test(arguments: [Keyword.physical, .holy])
    func `Briar Ward resists actual Thorns including converted retaliation`(keyword: Keyword) {
        var hero = CombatModifierProfile.zero
        hero.triggers.thornsDealHoly = keyword == .holy
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: hero,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 0.5)]), appliesFightPacing: false,
        )
        battle.insertEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let hit = battle.recordingResult { context in context.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(hit.events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 4 })
        let ordinary = battle.resolveTestDamage(8, options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1))
        #expect(ordinary.healthLost == 8)
    }
}

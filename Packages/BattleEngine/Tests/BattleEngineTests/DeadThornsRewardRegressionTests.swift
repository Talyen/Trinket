import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DeadThornsRewardRegressionTests {
    @Test(arguments: [false, true])
    func `Spiteful requires its wearer to survive the hit while committed Thorns still returns damage`(
        finallyDefeated: Bool,
    ) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "spiteful"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1,
            companionHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = finallyDefeated
        battle.insertEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let outcome = battle.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.roster.enemy.currentHealth == 92)
        #expect(battle.roster.hero.currentHealth == (finallyDefeated ? 0 : 3))
        #expect(battle.roster.companion.currentHealth == 5)
        #expect(outcome.events.contains {
            $0.abilityName == "Spiteful" && $0.effectKind == .instantHeal && $0.amount == 2
        } == !finallyDefeated)
    }

    @Test(arguments: [false, true])
    func `Retaliatory earns Spiteful once even when a Thorns stack also fires`(hasStack: Bool) throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spiteful"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 5,
            heroModifiers: profile, appliesFightPacing: false,
        )
        if hasStack {
            battle.insertEffect(.thorns(3), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let hit = battle.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.health(of: battle.companion) == 7)
        #expect(hit.events.count(where: { $0.abilityName == "Spiteful" && $0.effectKind == .instantHeal }) == 1)
        #expect(battle.health(of: battle.enemy) == (hasStack ? 96 : 99))
    }

    @Test(arguments: [0, 2])
    func `Spitebloom strengthens Retaliatory before enemy Block`(enemyBlock: Int) throws {
        var profile = CombatModifierProfile.zero
        for id in ["retaliatory", "spitebloom"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.insertEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        DefensePoolEngine.set(enemyBlock, on: battle.enemy, in: &battle)

        _ = battle.resolveTestDamage(
            10,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.health(of: battle.enemy) == (enemyBlock == 0 ? 98 : 100))
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == 1)
    }
}

import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [0, 1])
    func `prismatic burn attaches only damage that reaches health`(block: Int) {
        var battle = capstoneBattle(hero: ["wildcard_physical_t1_1"])
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.heroTalentDamage(.burn, source: battle.hero, in: &battle)
        #expect(before - battle.roster.enemy.currentHealth == 1 - block)
        #expect(talentPoints(.burn, on: .enemy, in: battle) == 1 - block)
    }

    @Test(arguments: [0, 2, 4])
    func `thorn shedding poison stacks match retaliation health damage`(block: Int) {
        var battle = capstoneBattle(hero: ["druid_poison_t4_1"])
        seedHeroTalentEffect(.thorns(4), on: .companion, in: &battle)
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(before - battle.roster.enemy.currentHealth == 4 - block)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 4 - block)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 0)
        #expect(outcome.events.filter { $0.effectKind == .thornsTriggered }.reduce(0) { $0 + $1.amount } == 4 - block)
    }

    @Test(arguments: [false, true])
    func `sunwall converts actual holy damage without scaling it again`(lethal: Bool) {
        var battle = capstoneBattle(hero: ["knight_holy_t4_1"])
        battle.appliesFightPacing = true
        battle.turnCount = 8
        if lethal {
            battle.roster.enemy.currentHealth = 3
        }
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .holy, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(outcome.healthLost > 0)
        #expect(talentPoints(.shield, on: .companion, in: battle) == outcome.healthLost)
    }

    @Test(arguments: [0, 1, 2])
    func `venomous arrows deals its poison hit before attaching stacks`(poisonBlock: Int) {
        var battle = capstoneBattle(hero: ["ranger_poison_t1_1"])
        DefensePoolEngine.set(1 + poisonBlock, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(before - battle.roster.enemy.currentHealth == 2 - poisonBlock)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2 - poisonBlock)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
    }

    @Test(arguments: [0, 1, 2])
    func `venomous skin damages the attacker before attaching poison`(block: Int) {
        var battle = capstoneBattle(companion: ["lizard_scout_poison_t1_2"])
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(before - battle.roster.enemy.currentHealth == 2 - block)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2 - block)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
    }
}

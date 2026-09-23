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
        _ = CombatTriggerEngine.heroTalentDamage(.burn, source: battle.hero, name: "Prismatic Edge", in: &battle)
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

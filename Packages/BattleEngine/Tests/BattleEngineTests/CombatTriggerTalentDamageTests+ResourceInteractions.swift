import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentDamageTests {
    @Test(arguments: ["bear_physical_t4_1", "wolf_physical_t4_1"])
    func `physical reactions preserve next attack resources`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        let hero = battle.hero
        DefensePoolEngine.set(7, on: hero, in: &battle)
        battle.storedBlockedDamageByActorID[hero.id] = 7
        let reaction = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: hero.id, options: .reaction(),
        ))
        #expect(reaction.healthLost == 2)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 7)
        #expect(battle.storedBlockedDamageByActorID[hero.id] == 7)
        let attack = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical, sourceActorID: hero.id,
            options: DamageOperation.attack(tier: .skill, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(attack.healthLost == 9)
        if talentID == "bear_physical_t4_1" {
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
        } else {
            #expect(battle.storedBlockedDamageByActorID[hero.id] == nil)
        }
    }

    @Test(arguments: [false, true])
    func `armor pierce recognizes leech cards`(hasLeech: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t1_2"]),
            enemyModifiers: CombatModifierProfile(damageTakenReduction: [.physical: 0.5]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: DamageOperation.attack(
                tier: .skill,
                scaling: .items,
                accuracy: .unavoidable,
                abilityCriticalChanceBonus: -1,
                abilityHasLeech: hasLeech,
            ),
        ))
        #expect(outcome.healthLost == (hasLeech ? 10 : 5))
    }

    @Test(arguments: [0, 2, 10])
    func `blood link transfers only excess leech`(missingHealth: Int) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t2_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = $0.maxHealth - missingHealth }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        _ = HealingEngine.leechFromDamage(
            10, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth == 50 - max(0, missingHealth - 5))
        #expect(battle.roster.companion.currentHealth == 1 + max(0, 5 - missingHealth))
    }

    @Test(arguments: [false, true])
    func `protective bloom triggers on sprite touch healing`(injured: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t2_2", "pixie_health_t1_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = injured ? 10 : $0.maxHealth }
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.companion.currentHealth == (injured ? 12 : 20))
        #expect(battle.roster.enemy.currentHealth == (injured ? 48 : 50))
    }
}

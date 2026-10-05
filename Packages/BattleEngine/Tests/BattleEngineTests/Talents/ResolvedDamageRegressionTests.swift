import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ResolvedDamageRegressionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Frozen Burn damage applies its talent multiplier once`(owner: BattleParticipant) {
        let profile = CombatantTalentCatalog.profile(for: [owner == .hero ? "wizard_freeze_t2_1" : "mana_moth_burn_t4_2"])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1000, heroModifiers: owner == .hero ? profile : .zero,
            companionModifiers: owner == .companion ? profile : .zero, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.controlMeter(.freeze, 100, 100), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let result = battle.resolveDamage(DamageRequest(
            amount: 100, target: battle.enemy, keyword: .burn, sourceActorID: battle.roster[owner].id,
            options: .attack(tier: .basic, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(result.healthLost == (owner == .hero ? 150 : 125))
    }

    @Test func `Frozen enemy does not amplify stored Burn a second time`() {
        let profile = CombatantTalentCatalog.profile(for: ["mana_moth_burn_t4_2"])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1000, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.controlMeter(.freeze, 100, 100), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 0)
        let result = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 100, keyword: .burn, target: battle.enemy, sourceActorID: battle.companion.id,
            operation: .resolvedPeriodic, in: &battle,
        ) }
        #expect(result.healthLost == 100)
    }

    @Test(arguments: [DamageOperation.periodic, .reaction(), .attack(tier: .basic, accuracy: .unavoidable)])
    func `Resonant Shell strengthens Stun attacks only`(operation: DamageOperation) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1000,
            companionModifiers: CombatantTalentCatalog.profile(for: ["shield_scarab_stun_t4_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.thorns(1), to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        var options = operation
        options.abilityCriticalChanceBonus = -1
        let result = battle.resolveDamage(DamageRequest(
            amount: 100, target: battle.enemy, keyword: .stun, sourceActorID: battle.companion.id, options: options,
        ))
        #expect(result.healthLost == (operation.isAttackHit ? 125 : 100))
    }

    @Test func `Toxic Backlash doubles the next stored Poison tick once`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1000, heroModifiers: CombatantTalentCatalog.profile(for: ["ranger_poison_t2_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.poison(20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(tier: .basic, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        let first = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 10, keyword: .poison, target: battle.enemy, sourceActorID: battle.hero.id,
            operation: .resolvedPeriodic, in: &battle,
        ) }
        let second = CombatExecutor.run { await DoTDamage.resolveDamage(
            basePotency: 10, keyword: .poison, target: battle.enemy, sourceActorID: battle.hero.id,
            operation: .resolvedPeriodic, in: &battle,
        ) }
        #expect(first.healthLost == 20)
        #expect(second.healthLost == 10)
        #expect(!battle.roster.hero.talents.pending.doubleNextPoisonDamage)
    }
}

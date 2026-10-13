import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test(arguments: [49, 50])
    func `war chest guarantees physical critical at its gold threshold`(gold: Int) {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(damage: DamageTriggers(warChest: true)),
            initialGold: gold,
        )
        let outcome = battle.resolveDamage(.directAbilityHit(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
        ))
        #expect(outcome.isCritical == (gold >= 50))
    }

    @Test func `pressurePoint doubles physical crit vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        let crit = battle.resolveTestDamage(
            10,
            options: .attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
        )
        var noPoisonBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        let noPoison = noPoisonBattle.resolveTestDamage(
            10,
            options: .attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
        )
        #expect(crit.healthLost > noPoison.healthLost)
    }

    @Test func `toxic coma increases companion poison damage against stunned enemies`() {
        let triggers = CombatTraitTriggers(dot: DotTriggers(poisonDamageVsStunnedMultiplier: 1.2))
        var battle = makeBattle(companionTriggers: triggers)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(Keyword.stun, 100, 10), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        let withStun = battle.resolveTestDamage(8, from: .companion, keyword: .poison, options: .reaction())
        var plain = makeBattle(companionTriggers: triggers)
        let without = plain.resolveTestDamage(8, from: .companion, keyword: .poison, options: .reaction())
        #expect(withStun.healthLost > without.healthLost)
    }

    @Test func `septicemia doubles bleed vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        let withPoison = battle.resolveTestDamage(6, keyword: .bleed, options: .reaction())
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        let without = plain.resolveTestDamage(6, keyword: .bleed, options: .reaction())
        #expect(withPoison.healthLost > without.healthLost)
    }

    @Test func `elementalParadox doubles freeze vs burning`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        let withBurn = battle.resolveTestDamage(8, keyword: .freeze, options: .reaction())
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        let without = plain.resolveTestDamage(8, keyword: .freeze, options: .reaction())
        #expect(withBurn.healthLost > without.healthLost)
    }

    @Test func `companion critical prepares doubled hero poison attack`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicTransfusion: true)))
        _ = battle.resolveTestDamage(
            2,
            from: .companion,
            options: .attack(tier: .skill, scaling: .items, accuracy: .unavoidable, guaranteedCritical: true),
        )
        #expect(battle.roster.hero.talents.pending.doubleNextPoisonAttack)
        let poison = battle.resolveTestDamage(
            4,
            keyword: .poison,
            options: .attack(tier: .skill, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(poison.healthLost == 8)
        #expect(!battle.roster.hero.talents.pending.doubleNextPoisonAttack)
    }

    @Test func `pressurePoint needs critical`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: battle.roster.enemy.combatant)
        let nonCrit = battle.resolveTestDamage(10, options: .attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal))
        var critBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        critBattle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)],
            for: critBattle.roster.enemy.combatant,
        )
        let crit = critBattle.resolveTestDamage(
            10,
            options: .attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
        )
        #expect(crit.healthLost > nonCrit.healthLost)
    }

    @Test func `intense heat only boosts phoenix damage against burning enemies`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(damage: DamageTriggers(companionDamageVsBurningMultiplier: 1.25)))
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        let before = battle.health(of: battle.enemy)
        _ = battle.resolveTestDamage(4, from: .companion, keyword: .burn)
        #expect(before - battle.health(of: battle.enemy) == 5)
    }

    @Test func `pickpocket steals extra gold from poisoned enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            attack: AttackTriggers(onAttackStealGold: 1),
            gold: GoldTriggers(stealGoldBonusVsPoisoned: 1),
        ))
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        _ = battle.resolveTestDamage(2)
        #expect(battle.gold == 2)
    }

    @Test func `bone crushing bites harder through block`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(physicalDamageVsBlockedBonus: 2)))
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        let outcome = battle.resolveTestDamage(4)
        #expect(outcome.healthLost == 1)
    }
}

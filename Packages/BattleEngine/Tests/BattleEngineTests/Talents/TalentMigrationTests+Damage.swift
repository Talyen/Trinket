import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `warChest guarantees physical critical at 50 gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(damage: DamageTriggers(warChest: true)),
            initialGold: 50,
        )
        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }
        #expect(outcome.isCritical)
    }

    @Test func `pressurePoint doubles physical crit vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let crit = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        var noPoisonBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        let noPoison = noPoisonBattle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        #expect(crit.healthLost > noPoison.healthLost)
    }

    @Test func `toxic coma increases companion poison damage against stunned enemies`() {
        let triggers = CombatTraitTriggers(dot: DotTriggers(poisonDamageVsStunnedMultiplier: 1.2))
        var battle = makeBattle(companionTriggers: triggers)
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .controlMeter(Keyword.stun, 100, 10), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let withStun = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.poison,
                sourceActorID: ctx.roster.companion.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(companionTriggers: triggers)
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.poison,
                sourceActorID: ctx.roster.companion.id,
                options: .reaction(),
            ))
        }
        #expect(withStun.healthLost > without.healthLost)
    }

    @Test func `septicemia doubles bleed vs poisoned`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let withPoison = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(septicemia: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 6,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        #expect(withPoison.healthLost > without.healthLost)
    }

    @Test func `elementalParadox doubles freeze vs burning`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let withBurn = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        var plain = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(elementalParadox: true)))
        let without = plain.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 8,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.freeze,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        #expect(withBurn.healthLost > without.healthLost)
    }

    @Test func `companion critical prepares doubled hero poison attack`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(toxicTransfusion: true)))
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 2,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.companion.id,
                options: DamageOperation.attack(
                    tier: .skill, scaling: .items, accuracy: .unavoidable, guaranteedCritical: true,
                ),
            ))
        }
        #expect(battle.roster.hero.talents.pending.doubleNextPoisonAttack)
        let poison = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4, target: ctx.roster.enemy.combatant, keyword: .poison,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(
                    tier: .skill, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
                ),
            ))
        }
        #expect(poison.healthLost == 8)
        #expect(!battle.roster.hero.talents.pending.doubleNextPoisonAttack)
    }

    @Test func `warChest does not crit below 50 gold`() {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(damage: DamageTriggers(warChest: true)),
            initialGold: 49,
        )
        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }
        #expect(!outcome.isCritical)
    }

    @Test func `pressurePoint needs critical`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let nonCrit = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        var critBattle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(pressurePoint: true)))
        critBattle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let crit = critBattle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .basic, scaling: .statsAndItems, accuracy: .normal, guaranteedCritical: true),
            ))
        }
        #expect(crit.healthLost > nonCrit.healthLost)
    }

    @Test func `intense heat only boosts phoenix damage against burning enemies`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers(damage: DamageTriggers(companionDamageVsBurningMultiplier: 1.25)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let before = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.burn,
                sourceActorID: ctx.roster.companion.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(before - battle.health(of: battle.enemy) == 5)
    }

    @Test func `pickpocket steals extra gold from poisoned enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            attack: AttackTriggers(onAttackStealGold: 1),
            gold: GoldTriggers(stealGoldBonusVsPoisoned: 1),
        ))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 2,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.gold == 2)
    }

    @Test func `bone crushing bites harder through block`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(damage: DamageTriggers(physicalDamageVsBlockedBonus: 2)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let outcome = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(outcome.healthLost == 1)
    }
}

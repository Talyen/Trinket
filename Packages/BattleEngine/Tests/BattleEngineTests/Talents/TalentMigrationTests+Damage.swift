import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test(arguments: [49, 50])
    func `war chest guarantees physical critical at its gold threshold`(gold: Int) {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers.configured { $0.warChest = true },
            initialGold: gold,
        )
        let outcome = battle.resolveDamage(.directAbilityHit(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
        ))
        #expect(outcome.isCritical == (gold >= 50))
    }

    @Test(arguments: [
        (
            CombatTraitTriggers.configured { $0.poisonDamageVsStunnedMultiplier = 1.2 },
            BattleParticipant.companion,
            Effect.controlMeter(.stun, 100, 10),
            0,
            8,
            Keyword.poison,
            DamageOperation.reaction(),
        ),
        (CombatTraitTriggers.configured { $0.septicemia = true }, .hero, .poison(2), 2, 6, .bleed, .reaction()),
        (CombatTraitTriggers.configured { $0.elementalParadox = true }, .hero, .burn(2), 2, 8, .freeze, .reaction()),
    ])
    func `status damage talents amplify their owners qualifying hits`(
        triggers: CombatTraitTriggers, owner: BattleParticipant, effect: Effect, turns: Int,
        amount: Int, keyword: Keyword, operation: DamageOperation,
    ) {
        var afflicted = makeBattle(
            heroTriggers: owner == .hero ? triggers : .init(),
            companionTriggers: owner == .companion ? triggers : .init(),
        )
        var plain = afflicted
        afflicted.roster.setActiveEffects([ActiveEffect(id: 1, effect: effect, remainingTurns: turns)], for: afflicted.enemy)
        let withStatus = afflicted.resolveTestDamage(amount, from: owner, keyword: keyword, options: operation)
        let without = plain.resolveTestDamage(amount, from: owner, keyword: keyword, options: operation)
        #expect(withStatus.healthLost > without.healthLost)
    }

    @Test func `companion critical prepares doubled hero poison attack`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.toxicTransfusion = true })
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

    @Test(arguments: [false, true])
    func `pressure point doubles only critical damage against poison`(critical: Bool) {
        func damage(equipped: Bool, poisoned: Bool = true) -> Int {
            var battle = makeBattle(heroTriggers: .configured {
                $0.pressurePoint = equipped
                $0.criticalChanceBonus = -1
            })
            battle.appliesFightPacing = false
            if poisoned {
                battle.insertEffect(.poison(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
            }
            return battle.resolveTestDamage(10, options: .attack(
                accuracy: .unavoidable, guaranteedCritical: critical,
            )).healthLost
        }
        let baseline = damage(equipped: false)
        #expect(damage(equipped: true) == baseline * (critical ? 2 : 1))
        #expect(damage(equipped: true, poisoned: false) == baseline)
    }

    @Test func `intense heat only boosts phoenix damage against burning enemies`() {
        var battle = makeBattle(companionTriggers: CombatTraitTriggers.configured { $0.companionDamageVsBurningMultiplier = 1.25 })
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
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured {
            $0.onAttackStealGold = 1
            $0.stealGoldBonusVsPoisoned = 1
        })
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .poison(3), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        _ = battle.resolveTestDamage(2)
        #expect(battle.gold == 2)
    }

    @Test func `bone crushing bites harder through block`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers.configured { $0.physicalDamageVsBlockedBonus = 2 })
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        let outcome = battle.resolveTestDamage(4)
        #expect(outcome.healthLost == 1)
    }
}

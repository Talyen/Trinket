import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentDamageTests {
    @Test func `dense bones gains reduction only from attack hits up to four`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 100,
            companionModifiers: .init(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(toughnessOnHit: 1, toughnessOnHitCap: 4),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        for options in [DamageOptions.doTTick, .healthCost, .flatReaction] {
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 2, target: battle.companion, keyword: .bleed,
                sourceActorID: options.isHealthCost ? battle.companion.id : battle.enemy.id,
                options: options,
            ))
            #expect(outcome.healthLost == 2)
            #expect(battle.roster.runtime(for: battle.companion)?.flatDamageReductionBonus == 0)
        }
        for hit in 0 ..< 6 {
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 6, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: false, isAttackHit: true),
            ))
            #expect(outcome.healthLost == 6 - min(hit, 4))
            #expect(battle.roster.runtime(for: battle.companion)?.flatDamageReductionBonus == min(hit + 1, 4))
        }
    }

    @Test(arguments: [DamageOptions.healthCost, .doTTick, .flatReaction])
    func `soul sharing heals from enemy damage but not skeleton health costs`(options: DamageOptions) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .init(triggers: CombatTraitTriggers(
                healing: HealingTriggers(companionDamageLeechesToHeroPercent: 0.5),
            )),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 4, target: options.isHealthCost ? battle.companion : battle.enemy,
            keyword: .bleed, sourceActorID: battle.companion.id, options: options,
        ))
        #expect(outcome.healthLost == 4)
        #expect(battle.health(of: battle.hero) == (options.isHealthCost ? 5 : 7))
    }

    @Test func `bloodrush draws on bleed ticks`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .init(triggers: CombatTraitTriggers(dot: DotTriggers(bleedTickDrawChancePercent: 1.0))),
            dealOpeningHand: false,
        )
        battle.companionDeck.putOnBottom(.slash)
        let active = ActiveEffect(
            id: 1, effect: .bleed(4), remainingTurns: 1, sourceActorID: battle.roster.companion.id,
        )
        let outcome = BleedHandler().advanceTurn(
            active, on: battle.roster.enemy.combatant, in: &battle,
        )
        #expect(outcome.events.contains(where: { $0.effectKind == .cardsDrawn }))
    }

    @Test func `bone armor grants block on every health loss except absorbed damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .init(triggers: CombatTraitTriggers(block: BlockTriggers(onSelfHealthLossGainBlock: 1))),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .shield(.block, 5), remainingTurns: 0)], for: battle.hero,
        )
        let absorbed = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .flatReaction,
        ))
        #expect(absorbed.healthLost == 0)
        for turn in 0 ... 1 {
            battle.turnCount = turn
            for expectedBlock in [1, 1] {
                let outcome = battle.resolveDamage(DamageRequest(
                    amount: 1, target: battle.hero, keyword: .bleed, sourceActorID: battle.hero.id,
                    options: .healthCost,
                ))
                #expect(outcome.healthLost == 1)
                let block = outcome.events.filter { $0.effectKind == .shieldApplied }.reduce(0) { $0 + $1.amount }
                #expect(block == expectedBlock)
            }
        }
    }

    @Test(arguments: [1, 8])
    func `cross contamination rolls twenty percent for full poison damage`(amount: Int) {
        var successes = 0
        for seed in UInt64(1) ... 32 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroModifiers: .init(triggers: CombatTraitTriggers(dot: DotTriggers(crossContamination: true))),
                rngSeed: seed, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            var expectedRng = battle.rng
            let shouldProc = BattleChance.succeeds(probability: 0.20, using: &expectedRng)
            var hit = DamageResolutionState(
                amount: amount, combatant: battle.enemy, sourceActorID: battle.hero.id,
                damageKeyword: .bleed, options: .doTTick,
            )
            hit.buildupDamage = amount
            DamagePipeline.applyTalentMirroredReactions(to: &hit, in: &battle)
            let poison = battle.activeEffects(of: battle.enemy).first { $0.effect.keyword == .poison }
            #expect((poison != nil) == shouldProc)
            if shouldProc {
                successes += 1
                #expect(poison?.effect == .poison(amount))
                #expect(battle.health(of: battle.enemy) == battle.maxHealth(of: battle.enemy) - amount)
            }
        }
        #expect(successes > 0 && successes < 32)
    }
}

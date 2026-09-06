import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentDamageTests {
    @Test func `bloodrush draws only once per owner per turn including ticks`() {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(dot: DotTriggers(bloodrush: true)))
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, companionModifiers: profile, dealOpeningHand: false,
        )
        for turn in 0 ... 1 {
            battle.turnCount = turn
            battle.hand = BattleHand()
            battle.heroDeck.putOnBottom(.slash)
            battle.heroDeck.putOnBottom(.slash)
            battle.companionDeck.putOnBottom(.slash)
            battle.companionDeck.putOnBottom(.slash)
            for actor in [battle.hero, battle.companion] {
                for expectedDraw in [1, 0] {
                    var hit = DamageResolutionState(
                        amount: 2, combatant: battle.enemy, sourceActorID: actor.id,
                        damageKeyword: .bleed, options: .doTTick,
                    )
                    hit.buildupDamage = 2
                    DamagePipeline.applyTalentMirroredReactions(to: &hit, in: &battle)
                    #expect(hit.damageEvents.count(where: { $0.effectKind == .cardsDrawn }) == expectedDraw)
                }
            }
            #expect(battle.hand.totalCount == 2)
        }
    }

    @Test func `bone armor counts health loss once per turn but not absorbed damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .init(triggers: CombatTraitTriggers(block: BlockTriggers(onSelfHealthLossGainBlock: 2))),
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
            for expectedBlock in [2, 0] {
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

import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleTurnEngineTests {
    @Test func `random enemy support outcomes preserve attack defenses and resolve once`() {
        let ability = Ability(
            id: "enemy-choice", name: "Enemy Choice", tier: .basic,
            outcomeBranches: [
                AbilityOutcomeBranch(damageComponents: [DamageComponent(2, keyword: .physical)]),
                AbilityOutcomeBranch(effects: [.shield(.block, 3)]),
            ],
        )
        var companionProfile = CombatModifierProfile.zero
        companionProfile.triggers.negateFirstEnemyAttack = true
        var supportOutcomes = 0
        for seed in UInt64(1772) ..< 1784 {
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                enemyAbilities: [ability], companionModifiers: companionProfile,
                rngSeed: seed, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            var expected = battle
            let resolved = BattleAbilityRules.resolveOutcome(ability, actor: battle.enemy, in: &expected)
            let attacks = resolved.dealsCombatDamage
            if !attacks {
                supportOutcomes += 1
            }
            let events = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
            #expect(battle.roster.companion.talents.battle.negatedFirstEnemyAttack == attacks)
            #expect(events.contains { $0.effectKind == .shieldApplied && $0.targetID == battle.enemy.id } == !attacks)
            #expect(battle.rng == expected.rng)
        }
        #expect(supportOutcomes > 0 && supportOutcomes < 12)
    }

    @Test func `attack avoidance preserves enemy support actions and warning bark`() {
        var heroTriggers = CombatTraitTriggers()
        heroTriggers.poisonedEnemyMissChancePercent = 1
        var companionTriggers = CombatTraitTriggers()
        companionTriggers.negateFirstEnemyAttack = true
        companionTriggers.swapAndDodgeForHeroChance = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [.block],
            heroModifiers: CombatModifierProfile(triggers: heroTriggers),
            companionModifiers: CombatModifierProfile(triggers: companionTriggers),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.poison(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        let events = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)

        #expect(events.contains { $0.effectKind == .shieldApplied && $0.targetID == battle.enemy.id })
        #expect(!battle.roster.companion.talents.battle.negatedFirstEnemyAttack)
        #expect(!battle.roster.hero.activeEffects.contains { $0.effect == .evadeNextHit })
    }

    @Test(arguments: [Keyword?.none, .stun, .freeze])
    func `pinning strike does not damage an enemy that cannot attack`(control: Keyword?) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [control == nil ? .block : .slash],
            heroModifiers: CombatantTalentCatalog.profile(for: ["ranger_bleed_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 3)
        if let control {
            battle.appendEffect(.controlMeter(control, 20, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        let events = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)

        #expect(battle.roster.enemy.currentHealth == 100)
        #expect(events.contains { $0.effectKind == (control == nil ? .shieldApplied : .controlActionSkipped) })
    }

    @Test func `extended stun rewards recovery only after the final skipped action`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            heroModifiers: CombatantTalentCatalog.profile(for: ["knight_stun_t2_2", "fox_stun_t3_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.controlMeter(.stun, 20, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        battle.additionalControlSkipsByCombatantID[battle.enemy.id] = 1

        let first = BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle)
        #expect(!first.contains { $0.effectKind == .cardsDrawn })
        #expect(!battle.roster.enemy.activeEffects.contains { $0.effect.isBleed || $0.effect.isDecayingDoT })

        let last = BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle)
        #expect(last.contains { $0.effectKind == .cardsDrawn && $0.amount == 1 })
        #expect(battle.roster.enemy.activeEffects.contains { $0.effect.isBleed })
    }
}

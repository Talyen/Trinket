import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension AbilityEffectIntegrationTests {
    @Test func `avatar refresh survives consuming the previous conversion`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        for _ in 0 ..< 2 {
            context.performTestAction(.avatarOfJustice)
        }
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion belongs to the attack before its nested automatic play`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        context.roster.companion.currentHealth = 0
        context.heroDeck = CombatDeck(abilities: [.slash])
        context.performTestAction(.avatarOfJustice)
        let events = context.performTestAction(.packTactics)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.holy])
    }

    @Test func `recurring damage does not spend avatar attack conversion`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        context.performTestAction(.avatarOfJustice)
        context.performTestAction(.blizzard)
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion enters the holy damage pipeline`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 500,
            heroModifiers: CombatModifierProfile(damageDealtBonus: [.holy: 2]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        context.performTestAction(.avatarOfJustice)

        let attack = Ability(
            id: "converted-attack",
            name: "Converted Attack",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        let events = context.performTestAction(attack)
        let damage = events.first { $0.kind == .abilityDamage }
        #expect(damage?.keyword == .holy)
        #expect(damage?.amount == 4)
    }

    @Test func `feint draws a manual card and dodges the next hit`() throws {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        context.heroDeck = CombatDeck(abilities: [.slash])
        let enemyBefore = context.health(of: context.enemy)

        let feintEvents = context.performTestAction(AbilityCatalog.feint)
        try #expect(!feintEvents.contains { $0.abilityID == Ability.slash.id && $0.kind == .abilityDamage })
        try #expect(context.health(of: context.enemy) == enemyBefore)
        try #expect(context.heroDeck.isEmpty)
        try #expect(context.hand.cards.map(\.ability.id) == [Ability.slash.id])
        try #expect(context.activeEffects(of: context.hero).contains { $0.effect == .evadeNextHit })

        let enemyAttack = Ability(
            id: "enemy-attack",
            name: "Enemy Attack",
            tier: .basic,
            directDamage: 4,
            damageKeyword: .physical,
            criticalChanceBonus: -1,
        )
        let heroBefore = context.health(of: context.hero)
        let dodgeEvents = context.performTestAction(enemyAttack, from: .enemy, to: .hero)
        try #expect(context.health(of: context.hero) == heroBefore)
        try #expect(dodgeEvents.contains { $0.effectKind == .dodgeApplied })
        try #expect(!context.activeEffects(of: context.hero).contains { $0.effect == .evadeNextHit })
    }

    @Test func `avatar deals holy damage and converts the next attack`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        let openingHealth = context.health(of: context.enemy)
        context.performTestAction(.avatarOfJustice)
        #expect(context.health(of: context.enemy) == openingHealth - 6)
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == 6)
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })

        let attack = Ability(
            id: "two-hit-attack",
            name: "Two Hit Attack",
            tier: .basic,
            damageComponents: [
                DamageComponent(2, keyword: .physical),
                DamageComponent(3, keyword: .burn),
            ],
            criticalChanceBonus: -1,
        )
        let events = context.performTestAction(attack)
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.keyword) == [.holy, .holy])
        #expect(!context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion remains through a non damaging card`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        context.performTestAction(.avatarOfJustice)
        context.performTestAction(.block)
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `blizzard and earthquake deal six damage twice`() {
        for ability in [Ability.blizzard, Ability.earthquake] {
            var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
            let initialHealth = context.health(of: context.enemy)
            context.performTestAction(ability)
            #expect(context.health(of: context.enemy) == initialHealth - 6)
            CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &context) }
            #expect(context.health(of: context.enemy) == initialHealth - 12)
            CombatExecutor.run { await EffectTurnEngine.advanceAll(context: &context) }
            #expect(context.health(of: context.enemy) == initialHealth - 12)
        }
    }

    @Test func `hemorrhage applies and detonates bleed`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        context.insertEffect(.bleed(4), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        let before = context.health(of: context.enemy)
        let events = context.performTestAction(.hemorrhage)
        #expect(events.contains { $0.kind == .abilityDamage && $0.keyword == .bleed })
        #expect(context.health(of: context.enemy) < before - 6)
        #expect(!context.activeEffects(of: context.enemy).contains { $0.effect.kind == .bleed })
    }

    @Test func `molten bulwark grants block and thorns without a ward`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        context.performTestAction(.moltenBulwark)
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == 4)
        #expect(context.activeEffects(of: context.hero).contains { $0.effect == .thorns(4) })
        #expect(!context.activeEffects(of: context.hero).contains { $0.effect.kind == .onHitDamage })
    }

    @Test func `thorn mail uses block gained by the same ability`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(4, on: context.hero, in: &context)
        context.performTestAction(.thornMail)
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == 10)
        #expect(context.activeEffects(of: context.hero).contains { $0.effect == .thorns(5) })
    }

    @Test func `bash deals three stun and no physical follow-up`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        let events = context.performTestAction(.bash)
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.count == 1)
        #expect(damage.first?.amount == 3)
        #expect(damage.first?.keyword == .stun)
    }

    @Test(arguments: [false, true])
    func `fire arrow always deals three burn`(enemyAlreadyBurning: Bool) {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        if enemyAlreadyBurning {
            context.insertEffect(.burn(3), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        }
        let events = context.performTestAction(.fireArrow)
        #expect(events.first { $0.kind == .abilityDamage }?.amount == 3)
    }

    @Test func `damage component applies do T stack without immediate tick`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [.kindling])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            rngSeed: CombatantFixtures.deterministicBattleSeed,
            dealOpeningHand: false,
        )
        let startingHealth = context.roster.health(for: enemy)

        let events = context.recordingEvents { context in await BattleTurnEngine.performAction(
            ability: .kindling,
            actor: hero,
            abilityTarget: enemy,
            context: &context,
        ) }

        try #expect(context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .burn })
        let abilityDamage = events
            .filter { $0.kind == ActionEvent.Kind.abilityDamage }
            .reduce(0) { $0 + $1.amount }
        try #expect(context.roster.health(for: enemy) == startingHealth - abilityDamage)
        try #expect(!events.contains { $0.kind == ActionEvent.Kind.status && $0.keyword == .burn })
    }

    @Test(arguments: [false, true])
    func `ice shot builds freeze and doubles against a frozen enemy without consuming it`(frozen: Bool) {
        var context = iceShotBattle(frozenEnemy: frozen)
        let events = context.performTestAction(.iceShot)
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 1)
        #expect(components.map(\.keyword) == [.freeze])
        #expect(components.first?.amount == (frozen ? 4 : 2))
        if frozen {
            #expect(BattleConditionEvaluator.isMet(.enemyFrozen, actor: context.hero, in: context))
        }
    }

    @Test(arguments: [3, 10])
    func `control multiplication doubles buildup after damage and triggers at threshold`(initialAmount: Int) {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        context.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, initialAmount, 20), remainingTurns: 0)],
            for: context.enemy,
        )
        let events = context.performTestAction(Ability(
            id: "control-multiplier", name: "Control Multiplier", tier: .skill,
            directDamage: 1, damageKeyword: .freeze,
            targetedEffects: [TargetedEffect(.multiplyControlMeter(.freeze, 2), target: .enemy)],
        ))
        if initialAmount == 3 {
            let meter = context.activeEffects(of: context.enemy).first { $0.effect.keyword == .freeze }
            #expect(meter?.effect.controlMeterValues?.amount == 8)
            #expect(events.contains { $0.effectKind == .dotAmplified && $0.keyword == .freeze })
        } else {
            #expect(events.contains { $0.effectKind == .controlTriggered && $0.keyword == .freeze })
            #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .freeze))
        }
    }

    @Test func `poison dagger resolves two poison hits`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        let before = context.health(of: context.enemy)

        let events = context.performTestAction(.poisonDagger)

        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.amount) == [1, 1])
        #expect(damage.allSatisfy { $0.keyword == .poison })
        #expect(context.health(of: context.enemy) == before - 2)
    }

    @Test func `spiked shield deals damage and grants one random defense effect`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)

        let events = context.performTestAction(.spikedShield)

        let damage = events.first { $0.kind == .abilityDamage }
        let block = BattleTestFixtures.shieldPoints(for: context.hero, in: context)
        let thorns = context.activeEffects(of: context.hero).contains { $0.effect == .thorns(3) }
        #expect(damage?.amount == 2)
        #expect(damage?.keyword == .physical)
        #expect((block == 3) != thorns)
    }

    @Test func `ray of frost hits twice immediately`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        let before = context.health(of: context.enemy)
        let events = context.performTestAction(.rayOfFrost)
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.amount) == [1, 1])
        #expect(damage.map(\.keyword) == [.freeze, .freeze])
        #expect(context.health(of: context.enemy) == before - 2)
        #expect(!context.activeEffects(of: context.enemy).contains { $0.effect.kind == .recurringDamage })
    }
}

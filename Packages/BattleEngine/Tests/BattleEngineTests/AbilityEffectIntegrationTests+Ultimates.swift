import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension AbilityEffectIntegrationTests {
    @Test func `avatar refresh survives consuming the previous conversion`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        for _ in 0 ..< 2 {
            _ = BattleTurnEngine.performAction(
                ability: .avatarOfJustice, actor: context.hero, abilityTarget: context.enemy, context: &context,
            )
        }
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion belongs to the attack before its nested automatic play`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        context.roster.companion.currentHealth = 0
        context.heroDeck = CombatDeck(abilities: [.slash])
        _ = BattleTurnEngine.performAction(
            ability: .avatarOfJustice, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )
        let events = BattleTurnEngine.performAction(
            ability: .packTactics, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.holy, .physical])
    }

    @Test func `recurring damage does not spend avatar attack conversion`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        _ = BattleTurnEngine.performAction(
            ability: .avatarOfJustice, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )
        _ = BattleTurnEngine.performAction(
            ability: .blizzard, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion enters the holy damage pipeline`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 500,
            heroModifiers: CombatModifierProfile(damageDealtBonus: [.holy: 2]),
            dealOpeningHand: false,
        )
        context.appliesFightPacing = false
        _ = BattleTurnEngine.performAction(
            ability: .avatarOfJustice,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )

        let attack = Ability(
            id: "converted-attack",
            name: "Converted Attack",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)],
            criticalChanceBonus: -1,
        )
        let events = BattleTurnEngine.performAction(
            ability: attack,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let damage = events.first { $0.kind == .abilityDamage }
        #expect(damage?.keyword == .holy)
        #expect(damage?.amount == 4)
    }

    @Test func `shadowstep plays an attack from the actor deck and dodges the next hit`() throws {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        context.heroDeck = CombatDeck(abilities: [.slash])
        let enemyBefore = context.health(of: context.enemy)

        let shadowstepEvents = BattleTurnEngine.performAction(
            ability: .shadowstep,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        try #expect(shadowstepEvents.contains { $0.abilityID == Ability.slash.id && $0.kind == .abilityDamage })
        try #expect(context.health(of: context.enemy) < enemyBefore)
        try #expect(context.heroDeck.abilities.map(\.id) == [Ability.slash.id])
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
        let dodgeEvents = BattleTurnEngine.performAction(
            ability: enemyAttack,
            actor: context.enemy,
            abilityTarget: context.hero,
            context: &context,
        )
        try #expect(context.health(of: context.hero) == heroBefore)
        try #expect(dodgeEvents.contains { $0.effectKind == .dodgeApplied })
        try #expect(!context.activeEffects(of: context.hero).contains { $0.effect == .evadeNextHit })
    }

    @Test func `avatar deals holy damage and converts the next attack`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        let openingHealth = context.health(of: context.enemy)
        _ = BattleTurnEngine.performAction(
            ability: .avatarOfJustice,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
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
        let events = BattleTurnEngine.performAction(
            ability: attack,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.keyword) == [.holy, .holy])
        #expect(!context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `avatar conversion remains through a non damaging card`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        _ = BattleTurnEngine.performAction(
            ability: .avatarOfJustice,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        _ = BattleTurnEngine.performAction(
            ability: .block,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(context.activeEffects(of: context.hero).contains {
            $0.effect == .nextStrikeDamageKeywordOverride(.holy)
        })
    }

    @Test func `blizzard and earthquake deal six damage twice`() {
        for ability in [Ability.blizzard, Ability.earthquake] {
            var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
            context.appliesFightPacing = false
            let initialHealth = context.health(of: context.enemy)
            _ = BattleTurnEngine.performAction(
                ability: ability,
                actor: context.hero,
                abilityTarget: context.enemy,
                context: &context,
            )
            #expect(context.health(of: context.enemy) == initialHealth - 6)
            _ = EffectTurnEngine.advanceAll(context: &context)
            #expect(context.health(of: context.enemy) == initialHealth - 12)
            _ = EffectTurnEngine.advanceAll(context: &context)
            #expect(context.health(of: context.enemy) == initialHealth - 12)
        }
    }

    @Test func `hemorrhage applies and detonates bleed`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        context.appendEffect(.bleed(4), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        let before = context.health(of: context.enemy)
        let events = BattleTurnEngine.performAction(
            ability: .hemorrhage,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(events.contains { $0.kind == .abilityDamage && $0.keyword == .bleed })
        #expect(context.health(of: context.enemy) < before - 6)
        #expect(!context.activeEffects(of: context.enemy).contains { $0.effect.kind == .bleed })
    }

    @Test func `molten bulwark grants block and thorns without a ward`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        _ = BattleTurnEngine.performAction(
            ability: .moltenBulwark,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == 4)
        #expect(context.activeEffects(of: context.hero).contains { $0.effect == .thorns(4) })
        #expect(!context.activeEffects(of: context.hero).contains { $0.effect.kind == .onHitDamage })
    }

    @Test func `thorn mail uses block gained by the same ability`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        DefensePoolEngine.set(4, on: context.hero, in: &context)
        _ = BattleTurnEngine.performAction(
            ability: .thornMail,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == 10)
        #expect(context.activeEffects(of: context.hero).contains { $0.effect == .thorns(5) })
    }

    @Test func `bash deals three stun and no physical follow-up`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        let events = BattleTurnEngine.performAction(
            ability: .bash,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.count == 1)
        #expect(damage.first?.amount == 3)
        #expect(damage.first?.keyword == .stun)
    }

    @Test(arguments: [false, true])
    func `fire arrow always deals two burn`(enemyAlreadyBurning: Bool) {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        if enemyAlreadyBurning {
            context.appendEffect(.burn(3), to: context.enemy, sourceID: context.hero.id, remainingTurns: 0)
        }
        let events = BattleTurnEngine.performAction(
            ability: .fireArrow,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(events.first { $0.kind == .abilityDamage }?.amount == 2)
    }

    @Test func `damage component applies do T stack without immediate tick`() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            abilities: [.kindling],
        )
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

        let events = BattleTurnEngine.performAction(
            ability: .kindling,
            actor: hero,
            abilityTarget: enemy,
            context: &context,
        )

        try #expect(context.roster.activeEffects(for: enemy).contains { $0.effect.keyword == .burn })
        let abilityDamage = events
            .filter { $0.kind == ActionEvent.Kind.abilityDamage }
            .reduce(0) { $0 + $1.amount }
        try #expect(context.roster.health(for: enemy) == startingHealth - abilityDamage)
        try #expect(!events.contains { $0.kind == ActionEvent.Kind.status && $0.keyword == .burn })
    }

    @Test func `ice shot doubles freeze without consuming it`() {
        var context = iceShotBattle(frozenEnemy: true)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 1)
        #expect(components.map(\.keyword) == [.freeze])
        #expect(components.first?.amount == 4)
        #expect(BattleConditionEvaluator.isMet(.enemyFrozen, actor: context.hero, in: context))
    }

    @Test func `ice shot builds freeze on an unfrozen enemy`() {
        var context = iceShotBattle(frozenEnemy: false)
        let events = BattleTurnEngine.performAction(
            ability: .iceShot,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let components = events.filter { $0.kind == .abilityDamage }
        #expect(components.count == 1)
        #expect(components.map(\.keyword) == [.freeze])
        #expect(components.first?.amount == 2)
    }

    @Test func `cold snap doubles freeze buildup after its damage`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 3, 20), remainingTurns: 0)],
            for: context.enemy,
            on: &context,
        )

        let events = BattleTurnEngine.performAction(
            ability: .coldSnap,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )

        let meter = context.activeEffects(of: context.enemy).first { $0.effect.keyword == .freeze }
        #expect(meter?.effect.controlMeterValues?.amount == 8)
        #expect(events.contains { $0.effectKind == .dotAmplified && $0.keyword == .freeze })
    }

    @Test func `cold snap triggers freeze when doubling reaches threshold`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        BattleStateTestFactory.seedActiveEffects(
            [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 10, 20), remainingTurns: 0)],
            for: context.enemy,
            on: &context,
        )

        let events = BattleTurnEngine.performAction(
            ability: .coldSnap,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )

        #expect(events.contains { $0.effectKind == .controlTriggered && $0.keyword == .freeze })
        #expect(context.roster.hasControlStatus(for: context.enemy, keyword: .freeze))
    }

    @Test func `poison dagger resolves two poison hits`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false
        let before = context.health(of: context.enemy)

        let events = BattleTurnEngine.performAction(
            ability: .poisonDagger,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )

        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.amount) == [1, 1])
        #expect(damage.allSatisfy { $0.keyword == .poison })
        #expect(context.health(of: context.enemy) == before - 2)
    }

    @Test func `spiked shield deals damage and grants one random defense effect`() {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        context.appliesFightPacing = false

        let events = BattleTurnEngine.performAction(
            ability: .spikedShield,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )

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
        let events = BattleTurnEngine.performAction(
            ability: .rayOfFrost,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        let damage = events.filter { $0.kind == .abilityDamage }
        #expect(damage.map(\.amount) == [1, 1])
        #expect(damage.map(\.keyword) == [.freeze, .freeze])
        #expect(context.health(of: context.enemy) == before - 2)
        #expect(!context.activeEffects(of: context.enemy).contains { $0.effect.kind == .recurringDamage })
    }

    @Test(arguments: [(0, 1, 1), (5, 6, 3)])
    func `shield bash gains block before calculating floored minimum stun`(
        startingBlock: Int, expectedBlock: Int, expectedDamage: Int,
    ) {
        var context = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        DefensePoolEngine.set(startingBlock, on: context.hero, in: &context)
        let events = BattleTurnEngine.performAction(
            ability: .shieldBash,
            actor: context.hero,
            abilityTarget: context.enemy,
            context: &context,
        )
        #expect(BattleTestFixtures.shieldPoints(for: context.hero, in: context) == expectedBlock)
        #expect(events.first { $0.kind == .abilityDamage }?.amount == expectedDamage)
        #expect(!events.contains { $0.effectKind == .blockSpent })
    }
}

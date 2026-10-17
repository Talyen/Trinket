import Testing
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [0, 10])
    func `chilling scales rolls on damage taken after block`(block: Int) {
        var profile = CombatantTalentCatalog.profile(for: ["frost_whelp_freeze_t1_2"])
        profile.triggers.onDamageFreezeRetaliationChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile,
            dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(block, on: battle.companion, in: &battle)
        let enemyHealth = battle.health(of: battle.enemy)

        let hit = battle.recordingResult { context in context.resolveTestDamage(
            4,
            from: .enemy,
            to: .companion,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }

        #expect(hit.value.healthLost == (block == 0 ? 4 : 0))
        #expect(battle.health(of: battle.enemy) == enemyHealth - (block == 0 ? 4 : 0))
        #expect(battle.activeEffects(of: battle.enemy).contains {
            $0.effect == .controlMeter(.freeze, 4, ControlMeterEngine.threshold(for: battle.enemy, in: battle))
        } == (block == 0))
        #expect(hit.events.contains { $0.abilityName == "Chilling Scales" && $0.keyword == .freeze && $0.amount == 4 } == (block == 0))
    }

    @Test func `dense bones gains reduction only from attack hits up to four`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 100,
            companionModifiers: .withTriggers {
                $0.toughnessOnHit = 1
                $0.toughnessOnHitCap = 4
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        for options in [DamageOperation.periodic, .healthCost, .reaction()] {
            let outcome = battle.resolveTestDamage(
                2,
                to: battle.companion,
                keyword: .bleed,
                sourceActorID: options.isHealthCost ? battle.companion.id : battle.enemy.id,
                options: options,
            )
            #expect(outcome.healthLost == 2)
            #expect(battle.roster.runtime(for: battle.companion)?.talents.battle.flatDamageReductionBonus == 0)
        }
        for hit in 0 ..< 6 {
            let outcome = battle.resolveTestDamage(
                6,
                from: .enemy,
                to: .companion,
                options: .attack(scaling: .flat, accuracy: .unavoidable),
            )
            #expect(outcome.healthLost == 6 - min(hit, 4))
            #expect(battle.roster.runtime(for: battle.companion)?.talents.battle.flatDamageReductionBonus == min(hit + 1, 4))
        }
    }

    @Test func `dense bones clamps a stacked step to its cap`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxHealth: 100,
            companionModifiers: .withTriggers {
                $0.toughnessOnHit = 3
                $0.toughnessOnHitCap = 4
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(
                6,
                from: .enemy,
                to: .companion,
                options: .attack(scaling: .flat, accuracy: .unavoidable),
            )
        }
        #expect(battle.roster.runtime(for: battle.companion)?.talents.battle.flatDamageReductionBonus == 4)
    }

    @Test(arguments: [DamageOperation.healthCost, .periodic, .reaction()])
    func `soul sharing heals from enemy damage but not skeleton health costs`(options: DamageOperation) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .withTriggers { $0.companionDamageLeechesToHeroPercent = 0.5 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 5 }
        let outcome = battle.resolveTestDamage(
            4,
            to: options.isHealthCost ? battle.companion : battle.enemy,
            keyword: .bleed,
            sourceActorID: battle.companion.id,
            options: options,
        )
        #expect(outcome.healthLost == 4)
        #expect(battle.health(of: battle.hero) == (options.isHealthCost ? 5 : 7))
    }

    @Test func `bloodrush draws only physical cards on bleed ticks`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: .withTriggers { $0.bleedTickDrawChancePercent = 1.0 },
            dealOpeningHand: false,
        )
        battle.companionDeck = CombatDeck(abilities: [.kindling, .slash])
        battle.insertEffect(.bleed(4), to: battle.enemy, sourceID: battle.companion.id, remainingTurns: 2)
        let active = try #require(battle.activeEffects(of: battle.enemy).first)
        let outcome = battle.recordingEvents { battle in await EffectHandlers.advanceTurn(active, on: battle.enemy, in: &battle) }
        #expect(outcome.contains(where: { $0.effectKind == .cardsDrawn }))
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.slash.id])
        let remaining = try #require(battle.activeEffects(of: battle.enemy).first { $0.effect.isBleed })
        let next = battle.recordingEvents { battle in await EffectHandlers.advanceTurn(remaining, on: battle.enemy, in: &battle) }
        #expect(!next.contains { $0.effectKind == .cardsDrawn })
        #expect(battle.companionDeck.count == 1)
    }

    @Test func `bone armor grants block on every health loss except absorbed damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers { $0.onSelfHealthLossGainBlock = 1 },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .shield(.block, 5), remainingTurns: 0)], for: battle.hero,
        )
        let absorbed = battle.resolveTestDamage(5, from: .enemy, to: .hero, options: .reaction())
        #expect(absorbed.healthLost == 0)
        for turn in 0 ... 1 {
            battle.turnCount = turn
            for expectedBlock in [1, 1] {
                let outcome = battle.recordingResult { context in context.resolveTestDamage(
                    1,
                    to: .hero,
                    keyword: .bleed,
                    options: .healthCost,
                ) }
                #expect(outcome.value.healthLost == 1)
                let block = outcome.events.filter { $0.effectKind == .shieldApplied }.reduce(0) { $0 + $1.amount }
                #expect(block == expectedBlock)
            }
        }
    }

    @Test(arguments: [1, 8], [false, true])
    func `cross contamination rolls twenty percent for full poison damage`(amount: Int, shouldProc: Bool) throws {
        let seed = try #require((UInt64(1) ... 32).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return BattleChance.succeeds(probability: 0.20, using: &rng) == shouldProc
        })
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers { $0.crossContamination = true },
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        var hit = DamageResolutionState(
            amount: amount, combatant: battle.enemy, sourceActorID: battle.hero.id,
            damageKeyword: .bleed, options: .periodic,
        )
        hit.remaining = amount
        CombatExecutor.run { await DamagePipeline.applyAttackerMirroredReactions(to: &hit, in: &battle) }
        let poison = battle.activeEffects(of: battle.enemy).first { $0.effect.keyword == .poison }
        #expect(poison?.effect == (shouldProc ? .poison(amount) : nil))
        #expect(battle.health(of: battle.enemy) == battle.maxHealth(of: battle.enemy) - (shouldProc ? amount : 0))
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [DamageOperation.attack(scaling: .flat, accuracy: .unavoidable), .reaction(), .resolvedPeriodic])
    func `concussive force builds stun from every physical damage origin`(operation: DamageOperation) {
        var profile = CombatModifierProfile.zero
        profile.triggers.physicalStunBuildupPercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile,
            dealOpeningHand: false,
            appliesFightPacing: false,
        )
        let hit = battle.resolveTestDamage(4, options: operation)
        #expect(hit.healthLost == 4)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect == .controlMeter(.stun, 4, 20) })
    }

    @Test(arguments: [DamageOperation.attack(scaling: .flat, accuracy: .unavoidable), .reaction(), .resolvedPeriodic])
    func `martial guard grants block from physical reaction and periodic damage`(operation: DamageOperation) {
        var profile = CombatModifierProfile.zero
        profile.triggers.physicalDamageBlockPercent = 0.5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile,
            dealOpeningHand: false,
            appliesFightPacing: false,
        )
        let hit = battle.resolveTestDamage(4, options: operation)
        #expect(hit.healthLost == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
    }

    @Test(arguments: [false, true])
    func `Bloodfire strengthens every Burn attack hit without creating Bleed or strengthening ongoing Burn`(bleeding: Bool) throws {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_burn_t1_1"])
        profile.triggers.criticalChanceBonus = -1
        let ability = Ability(
            id: "bloodfire-check", name: "Bloodfire Check", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .burn), DamageComponent(2, keyword: .burn)],
            criticalChanceBonus: -1,
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [ability], enemyMaxHealth: 100, heroModifiers: profile, appliesFightPacing: false,
        )
        if bleeding {
            battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 1)
        }
        let card = try #require(battle.hand.cards.first)
        let events = try battle.playCard(cardID: card.id).events
        #expect(battle.health(of: battle.enemy) == (bleeding ? 94 : 96))
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.burn, .burn])
        #expect(CombatTriggerEngine.totalPotency(of: .bleed, on: battle.enemy, in: battle) == (bleeding ? 1 : 0))
        let tick = battle.resolveTestDamage(4, keyword: .burn, options: .resolvedPeriodic)
        #expect(tick.healthLost == 4)
    }
}

extension CombatTriggerTalentDamageTests {
    @Test func `martial guard converts actual damage without overkill or a second block bonus`() {
        var profile = CombatModifierProfile(blockGainedBonus: 10)
        profile.triggers.physicalDamageBlockPercent = 0.5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile,
            dealOpeningHand: false,
            appliesFightPacing: false,
        )
        battle.roster.enemy.currentHealth = 4
        let hit = battle.resolveTestDamage(20, options: .attack(scaling: .flat, accuracy: .unavoidable))
        #expect(hit.healthLost == 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
    }

    @Test func `Denouncing waits for the next Smite and Sunwall uses that attacks combined damage`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t4_1"])
        let power = try #require(GameContent.itemAffixDefinition(matching: "denouncing")).astral
        profile.merge(power.modifiers)
        power.triggers.apply(to: &profile)
        profile.triggers.sunwallChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.smite], heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.nextStrikeDouble, to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let card = BattleCardCombatEngine.deal(.smite, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id).events

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus?.value == 4)
        #expect(events.filter { $0.effectKind == .shieldApplied && $0.abilityName == "Sunwall" }.map(\.amount) == [4])
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 4)

        let next = BattleCardCombatEngine.deal(.smite, owner: .hero, context: &battle)
        let nextEvents = try battle.playCard(cardID: next.id).events
        #expect(nextEvents.filter { $0.effectKind == .shieldApplied && $0.abilityName == "Sunwall" }.map(\.amount) == [8])
        #expect(battle.health(of: battle.enemy) == 88)
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus == nil)
    }
}

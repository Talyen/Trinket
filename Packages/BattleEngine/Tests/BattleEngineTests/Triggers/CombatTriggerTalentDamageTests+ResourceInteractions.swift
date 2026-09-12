import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [UInt64(1), 2])
    func `arcane focus deals damage for either random element`(seed: UInt64) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_mana_t1_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        var preview = battle.rng
        let keyword: Keyword = BattleChance.succeeds(probability: 0.5, using: &preview) ? .burn : .freeze
        let before = battle.health(of: battle.enemy)
        let payment = battle.payMana(3, for: battle.hero)
        _ = CombatTriggerEngine.afterSpendMana(payment, in: &battle)
        #expect(before - battle.health(of: battle.enemy) == 1)
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.keyword == keyword })
    }

    @Test(arguments: ["bear_physical_t4_1", "wolf_physical_t4_1"])
    func `physical reactions preserve next attack resources`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        let hero = battle.hero
        DefensePoolEngine.set(7, on: hero, in: &battle)
        battle.storedBlockedDamageByActorID[hero.id] = 7
        let reaction = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical,
            sourceActorID: hero.id, options: .reaction(),
        ))
        #expect(reaction.healthLost == 2)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 7)
        #expect(battle.storedBlockedDamageByActorID[hero.id] == 7)
        let attack = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.enemy, keyword: .physical, sourceActorID: hero.id,
            options: DamageOperation.attack(tier: .skill, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(attack.healthLost == 9)
        if talentID == "bear_physical_t4_1" {
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 0)
        } else {
            #expect(battle.storedBlockedDamageByActorID[hero.id] == nil)
        }
    }

    @Test(arguments: [false, true])
    func `armor pierce recognizes leech cards`(hasLeech: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t1_2"]),
            enemyModifiers: CombatModifierProfile(damageTakenReduction: [.physical: 0.5]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: DamageOperation.attack(
                tier: .skill,
                scaling: .items,
                accuracy: .unavoidable,
                abilityCriticalChanceBonus: -1,
                abilityHasLeech: hasLeech,
            ),
        ))
        #expect(outcome.healthLost == (hasLeech ? 10 : 5))
    }

    @Test(arguments: [0, 2, 10])
    func `blood link transfers only excess leech`(missingHealth: Int) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t2_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = $0.maxHealth - missingHealth }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        _ = HealingEngine.leechFromDamage(
            10, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth == 50 - max(0, missingHealth - 5))
        #expect(battle.roster.companion.currentHealth == 1 + max(0, 5 - missingHealth))
    }

    @Test(arguments: [false, true])
    func `protective bloom triggers on sprite touch healing`(injured: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: CombatantTalentCatalog.profile(for: ["pixie_health_t2_2", "pixie_health_t1_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = injured ? 10 : $0.maxHealth }
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.companion.currentHealth == (injured ? 12 : 20))
        #expect(battle.roster.enemy.currentHealth == (injured ? 48 : 50))
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [false, true])
    func `last mana damage survives mana refund`(refundBeforeReactions: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["warlock_mana_t1_1"])
        profile.triggers.spendManaRefundChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let actor = battle.hero
        let payment = battle.payMana(3, for: actor)
        if refundBeforeReactions {
            _ = battle.restoreManaEmitting(3, to: actor, abilityName: "Early refund")
        }
        _ = CombatTriggerEngine.afterSpendMana(payment, in: &battle)
        #expect(battle.mana(of: actor) == 3)
        #expect(battle.health(of: battle.enemy) == 97)
    }

    @Test func `arcane burst accumulates mana across cards and turns`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 15,
            companionModifiers: CombatantTalentCatalog.profile(for: ["mana_moth_mana_t3_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let actor = battle.companion
        for index in 0 ..< 5 {
            battle.companionDeck = CombatDeck(abilities: [.block])
            battle.turnCount = index
            let card = BattleCardCombatEngine.deal(.kindling, owner: .companion, context: &battle)
            let events = try BattleCardCombatEngine.playDrawnCard(card, context: &battle)
            #expect(events.contains { $0.kind == .ability && $0.abilityID == Ability.block.id } == (index == 1 || index >= 3))
        }
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: actor)) == 9)
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [4, 5, 12])
    func `arcane burst keeps excess after every crossed threshold`(amount: Int) {
        var profile = CombatModifierProfile.zero
        profile.triggers.spendManaThresholdAutoPlayCard = 5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 12, heroMana: amount, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.block])
        let payment = battle.payMana(amount, for: battle.hero)
        let events = CombatTriggerEngine.afterSpendMana(payment, in: &battle)
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == amount / 5)
        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == amount % 5)
    }

    @Test func `automatic payment ancestry suppresses recursive arcane burst and then restores`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.spendManaThresholdAutoPlayCard = 3
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 6, heroMana: 6, heroModifiers: profile, dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.kindling])
        let card = BattleCardCombatEngine.deal(.kindling, owner: .hero, context: &battle)
        let events = try battle.playCard(cardID: card.id)
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.kindling.id } == 2)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == 0)
        #expect(!battle.resolution.isAutomaticPlay)
        _ = battle.restoreManaEmitting(3, to: battle.hero, abilityName: "Refill")
        battle.heroDeck = CombatDeck(abilities: [.block])
        let payment = battle.payMana(3, for: battle.hero)
        let next = CombatTriggerEngine.afterSpendMana(payment, in: &battle)
        #expect(next.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == 1)
    }

    @Test func `mana reactions stop when automatic play defeats the payer`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.spendManaThresholdAutoPlayCard = 3
        profile.triggers.spendManaRandomDoTFlat = 5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 3, companionMana: 3, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.slash])
        battle.appendEffect(.thorns(10), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let payment = battle.payMana(3, for: battle.companion)
        _ = CombatTriggerEngine.afterSpendMana(payment, in: &battle)
        #expect(!battle.roster.companion.isAlive)
        #expect(!battle.roster.hasAffliction(.burn, on: battle.enemy))
        #expect(!battle.roster.enemy.activeEffects.contains { $0.keyword == .freeze })
    }
}

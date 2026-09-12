import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `playful energy heals on third party card only`() throws {
        var battle = capstoneBattle(companion: ["golden_retriever_health_t1_2"])
        battle.roster.hero.currentHealth = 10
        battle.roster.companion.currentHealth = 10
        let card = Ability(id: "wait", name: "Wait", tier: .basic, directDamage: 0)
        for owner in [BattleParticipant.hero, .companion, .hero, .companion] {
            let events = try playHeroTalentCard(card, owner: owner, in: &battle)
            let count = battle.turnCadence.cardsPlayed.values.reduce(0, +)
            #expect(battle.roster.hero.currentHealth == (count >= 3 ? 12 : 10))
            #expect(battle.roster.companion.currentHealth == (count >= 3 ? 12 : 10))
            #expect(events.contains { $0.abilityName == "Playful Energy" } == (count == 3))
        }
        _ = CombatTriggerEngine.atPlayerEndTurn(in: &battle)
        #expect(battle.roster.hero.currentHealth == 12)
        #expect(battle.roster.companion.currentHealth == 12)
    }

    @Test(arguments: [false, true], [Keyword.physical, .freeze, .bleed])
    func `feint strike is reserved for one party card`(supportFirst: Bool, keyword: Keyword) throws {
        var battle = capstoneBattle(companion: ["fox_dodge_t1_1"])
        battle.roster.hero.currentMana = 0
        battle.roster.companion.currentMana = 0
        let attack = Ability(
            id: "feint-check", name: "Feint Check", tier: .basic, directDamage: keyword == .physical ? 4 : 0,
            targetedEffects: keyword == .physical ? [] : [TargetedEffect(keyword == .bleed ? .bleed(4) : .recurringDamage(.freeze, 4, 2))],
            criticalChanceBonus: -1,
        )
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        if supportFirst {
            try playHeroTalentCard(Ability(id: "wait", name: "Wait", tier: .basic, directDamage: 0), in: &battle)
        }
        let before = battle.roster.enemy.currentHealth
        try playHeroTalentCard(attack, in: &battle)
        #expect(before - battle.roster.enemy.currentHealth == (supportFirst ? 4 : 6))
        let afterFirst = battle.roster.enemy.currentHealth
        try playHeroTalentCard(attack, owner: .companion, in: &battle)
        #expect(afterFirst - battle.roster.enemy.currentHealth == 4)
    }

    @Test func `feint strike stays with its card across nested plays and later ticks`() throws {
        var battle = capstoneBattle(companion: ["fox_dodge_t1_1"])
        battle.roster.hero.currentMana = 0
        battle.heroDeck = CombatDeck(abilities: [.rayOfFrost])
        let card = Ability(id: "nested-feint", name: "Nested Feint", tier: .basic, targetedEffects: [
            TargetedEffect(.drawAndPlayCards(1), target: .actor),
            TargetedEffect(.recurringDamage(.holy, 4, 2)),
        ])
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        let before = battle.roster.enemy.currentHealth
        let events = try playHeroTalentCard(card, in: &battle)
        #expect(before - battle.roster.enemy.currentHealth == 7)
        #expect(events.contains { $0.kind == .status && $0.keyword == .freeze && $0.amount == 1 })
        #expect(events.contains { $0.kind == .status && $0.keyword == .holy && $0.amount == 6 })
        let active = try #require(battle.activeEffects(of: battle.enemy).first { $0.keyword == .holy })
        let handler = try #require(EffectHandlers.all[.recurringDamage])
        let afterCard = battle.roster.enemy.currentHealth
        _ = handler.advanceTurn(active, on: battle.enemy, in: &battle)
        #expect(afterCard - battle.roster.enemy.currentHealth == 4)
    }

    @Test(arguments: [false, true])
    func `short dodge bonuses do not inherit cleanse duration`(smokeScreen: Bool) {
        var battle = capstoneBattle(hero: ["ranger_burn_t2_2"], companion: ["wolf_dodge_t2_1"])
        battle.roster.hero.talents.grantTimedDodge(0.2, untilTurn: 3)
        if smokeScreen {
            _ = battle.applyDecayingDoT(
                keyword: .burn, potency: 2, to: battle.enemy, sourceActorID: battle.hero.id, application: .ability,
            )
        } else {
            _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        }
        #expect(abs(DamagePipeline.dodgeChance(for: battle.hero, attackerID: battle.enemy.id, in: battle) - 0.4) < 0.0001)
        battle.turnCount = 1
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(abs(DamagePipeline.dodgeChance(for: battle.hero, attackerID: battle.enemy.id, in: battle) - 0.3) < 0.0001)
    }

    @Test func `three turn talents pay on the third and sixth player turns`() {
        var battle = capstoneBattle(companion: ["golden_retriever_gold_t1_2", "shield_scarab_stun_t3_1"])
        for turn in 0 ..< 6 {
            battle.turnCount = turn
            let goldBefore = battle.gold
            let healthBefore = battle.roster.enemy.currentHealth
            let blockBefore = talentPoints(.shield, on: .hero, in: battle)
            _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
            let due = (turn + 1).isMultiple(of: 3)
            #expect(battle.gold - goldBefore == (due ? 2 : 0))
            #expect(healthBefore - battle.roster.enemy.currentHealth == (due ? 3 : 0))
            for owner in [BattleParticipant.hero, .companion] {
                #expect(talentPoints(.shield, on: owner, in: battle) - blockBefore == (due ? 5 : 0))
            }
            if due {
                let stun = battle.roster.enemy.activeEffects.first { $0.keyword == .stun }
                #expect(stun?.effect.controlMeterValues?.amount == 3 * ((turn + 1) / 3))
            }
        }
    }

    @Test func `freezing gale deals damage through block and builds freeze`() {
        var battle = capstoneBattle(companion: ["frost_whelp_freeze_t3_2"])
        battle.turnCount = 2
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.enemy.currentHealth == before - 1)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
        #expect(battle.activeEffects(of: battle.enemy).contains {
            $0.effect.controlMeterValues?.amount == 1 && $0.keyword == .freeze
        })
    }

    @Test(arguments: [19, 20, 21])
    func `safe perch requires more than half health`(health: Int) {
        var battle = capstoneBattle(companion: ["library_owl_health_t1_1"])
        battle.roster.companion.currentHealth = health
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(battle.roster.companion.currentHealth == health + (health > 20 ? 2 : 0))
    }

    @Test func `wing buffet delays an uncontrolled enemy exactly once`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [.slash],
            companionModifiers: CombatantTalentCatalog.profile(for: ["frost_whelp_dodge_t2_2"]),
            dealOpeningHand: false,
        )
        _ = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id] == 1)
        let delayed = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        #expect(!delayed.contains { $0.kind == .ability && $0.actorID == battle.enemy.id })
        #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id, default: 0] == 0)
        let resumed = BattleCardCombatEngine.resolveEnemyTurn(context: &battle)
        #expect(resumed.contains { $0.kind == .ability && $0.actorID == battle.enemy.id })
    }

    @Test func `natural poison expiry pays the last source and explicit removal does not`() {
        var battle = heroTalentBattle("alchemist_poison_t2_2", "druid_poison_t2_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.companion.currentHealth == 2)
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 2)
        battle.turnCount += 1
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        battle.removeTalentPoint(.poison, from: battle.hero)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 2)
        #expect(battle.roster.companion.currentHealth == 3)
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle, source: .companion)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 2)
    }

    @Test func `sealed vial consumes all self poison without cleanse or expiry rewards`() throws {
        var battle = heroTalentBattle("alchemist_poison_t4_1", "alchemist_poison_t2_2", "alchemist_cleanse_t2_2")
        battle.roster.hero.currentMana = 0
        for potency in [7, 9] {
            seedHeroTalentEffect(.poison(potency), on: .hero, in: &battle, source: .enemy)
            let before = talentPoints(.poison, on: .enemy, in: battle)
            let events = try playHeroTalentCard(.causticJab, in: &battle)
            #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
            #expect(talentPoints(.poison, on: .enemy, in: battle) == before + potency + 1)
            #expect(events.contains { $0.kind == .abilityDamage && $0.keyword == .poison && $0.amount >= potency })
            #expect(!events.contains { $0.effectKind == .cleanseApplied })
        }
        #expect(battle.roster.hero.currentMana == 0)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 0)
    }

    @Test func `mixture transfers resolved excess repeatedly without bouncing or revival`() throws {
        var battle = heroTalentBattle("alchemist_health_t4_1")
        let healCard = Ability(id: "self-heal", name: "Self Heal", tier: .basic, targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3), target: .actor),
        ])
        battle.roster.companion.currentHealth = 1
        for _ in 0 ..< 2 {
            let before = battle.roster.companion.currentHealth
            let events = try playHeroTalentCard(healCard, in: &battle)
            let heal = try #require(events.first { $0.effectKind == .instantHeal && $0.abilityName == healCard.name })
            let transfer = try #require(events.first { $0.abilityName == "Masterwork Mixture" })
            #expect(transfer.amount == (heal.isCritical ? 6 : 3))
            #expect(!transfer.isCritical)
            #expect(battle.roster.companion.currentHealth == before + transfer.amount)
            #expect(events.count { $0.abilityName == "Masterwork Mixture" } == 1)
        }
        battle.roster.companion.currentHealth = battle.roster.companion.maxHealth - 1
        let limited = try playHeroTalentCard(healCard, in: &battle)
        #expect(limited.first { $0.abilityName == "Masterwork Mixture" }?.amount == 1)
        battle.roster.companion.currentHealth = 0
        let defeated = try playHeroTalentCard(healCard, in: &battle)
        #expect(battle.roster.companion.currentHealth == 0)
        #expect(!defeated.contains { $0.abilityName == "Masterwork Mixture" })
    }

    @Test func `quiet grove counts health lost rather than net health change`() {
        var battle = heroTalentBattle("druid_health_t2_1")
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        battle.heroTalents.enemyTurnActive = true
        _ = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.hero,
            keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .reaction(),
        ))
        _ = battle.healEmitting(amount: 1, target: battle.hero, source: battle.hero, abilityName: "Recovery")
        _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        #expect(battle.roster.companion.currentHealth == 1)
        battle.heroTalents.healthLostDuringEnemyTurn = []
        _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        #expect(battle.roster.companion.currentHealth == 2)
    }

    @Test func `barbed spores rewards poison damage and respects companion defeat`() {
        var battle = heroTalentBattle("druid_poison_t1_1")
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: .poison,
                sourceActorID: battle.hero.id, options: .periodic,
            ))
        }
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 2)
        battle.turnCount += 1
        battle.roster.companion.currentHealth = 0
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .poison,
            sourceActorID: battle.hero.id, options: .periodic,
        ))
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 0)
    }

    @Test func `shared current uses each actual mana payment without a turn cap`() throws {
        var battle = capstoneBattle(
            hero: ["druid_mana_t3_1"],
            companion: ["frost_whelp_mana_t3_2", "frost_whelp_mana_t1_1"],
        )
        let startingMana = battle.roster.companion.currentMana
        try playHeroTalentCard(.kindling, owner: .companion, in: &battle)
        #expect(battle.roster.companion.currentMana == startingMana)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 0)
        for expected in [2, 4, 6] {
            try playHeroTalentCard(.kindling, owner: .companion, in: &battle)
            #expect(talentPoints(.thorns, on: .hero, in: battle) == expected)
            #expect(startingMana - battle.roster.companion.currentMana == expected)
        }
    }

    @Test(arguments: [0, 5, 6, 11, 12, 30])
    func `grove reserve grants one block per six unspent mana`(mana: Int) {
        var battle = heroTalentBattle("druid_mana_t2_1")
        battle.roster.hero.currentMana = mana
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == mana / 6)
    }

    @Test func `perfect purity refreshes the next attack after actual cleansing`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t4_1")
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
            try playHeroTalentCard(.cleanse, in: &battle)
        }
        let events = try playHeroTalentCard(.slash, in: &battle)
        #expect(events.count { $0.kind == .abilityDamage && $0.keyword == .poison } == 1)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
        let plain = try playHeroTalentCard(.slash, in: &battle)
        #expect(!plain.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
        try playHeroTalentCard(.cleanse, in: &battle)
        let empty = try playHeroTalentCard(.slash, in: &battle)
        #expect(!empty.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
    }

    @Test func `last wager uses the last hero card and waiting does not improve dodge odds`() throws {
        var battle = heroTalentBattle("wildcard_gold_t3_1", "wildcard_dodge_t3_2")
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        try playHeroTalentCard(.block, owner: .companion, in: &battle)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 1)
        for _ in 0 ..< 8 {
            _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
            _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        }
        #expect(DamagePipeline.dodgeChance(for: battle.hero, attackerID: battle.enemy.id, in: battle) == 0.10)
    }
}

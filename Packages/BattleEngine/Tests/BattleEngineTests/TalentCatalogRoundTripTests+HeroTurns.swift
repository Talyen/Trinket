import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
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

    @Test func `grove reserve grants block from unspent mana at turn end`() throws {
        var battle = heroTalentBattle("druid_mana_t2_1")
        try playHeroTalentCard(.kindling, in: &battle)
        #expect(battle.roster.hero.currentMana == 7)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
        battle.roster.hero.currentMana = 1
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
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

import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
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
        #expect(battle.roster.hero.currentMana == 1)
        battle.turnCount += 1
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        battle.removeTalentPoint(.poison, from: battle.hero)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.companion.currentHealth == 2)
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle, source: .companion)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 1)
    }

    @Test func `sealed vial removes one without paying expiration`() {
        var battle = heroTalentBattle("alchemist_poison_t4_1", "alchemist_poison_t2_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        seedHeroTalentEffect(.poison(2), on: .enemy, in: &battle)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `mixture requires successful healing and both allies alive`() throws {
        var battle = heroTalentBattle("alchemist_health_t4_1")
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        try playHeroTalentCard(.poisonDagger, in: &battle)
        let heal = Ability(
            id: "test-heal-hero",
            name: "Heal Hero",
            tier: .basic,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .hero)],
        )
        try playHeroTalentCard(heal, in: &battle)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(battle.roster.companion.currentHealth == 1)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
        try playHeroTalentCard(heal, in: &battle)
        let before = battle.roster.hero.currentHealth
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(battle.roster.hero.currentHealth == before + 1)
        #expect(battle.roster.companion.currentHealth == 2)
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        let survivingHealth = battle.roster.hero.currentHealth
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(battle.roster.hero.currentHealth == survivingHealth)
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
            options: .flatReaction,
        ))
        _ = battle.healEmitting(amount: 1, target: battle.hero, source: battle.hero, abilityName: "Recovery")
        _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        #expect(battle.roster.companion.currentHealth == 1)
        battle.heroTalents.healthLostDuringEnemyTurn = []
        _ = CombatTriggerEngine.afterHeroTalentEnemyTurn(in: &battle)
        #expect(battle.roster.companion.currentHealth == 2)
    }

    @Test func `shelter seed and barbed spores are bounded and respect companion defeat`() {
        var battle = heroTalentBattle("druid_health_t2_2", "druid_poison_t1_1")
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 11,
                target: battle.hero,
                keyword: .physical,
                sourceActorID: battle.enemy.id,
                options: .flatReaction,
            ))
            battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 20 }
        }
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 1)
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1,
                target: battle.enemy,
                keyword: .poison,
                sourceActorID: battle.hero.id,
                options: .doTTick,
            ))
        }
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 2)
        battle.turnCount += 1
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        _ = battle.resolveDamage(DamageRequest(
            amount: 1,
            target: battle.enemy,
            keyword: .poison,
            sourceActorID: battle.hero.id,
            options: .doTTick,
        ))
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 0)
    }

    @Test func `mana spend triggers require actual spend and empowerment has its own trigger`() throws {
        var battle = heroTalentBattle("druid_mana_t1_2", "druid_mana_t3_1", "druid_mana_t4_1")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        _ = CombatTriggerEngine.afterSpendMana(by: battle.companion, amountSpent: 0, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 2)
        try playHeroTalentCard(.kindling, owner: .companion, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 0)
        seedHeroTalentEffect(.thorns(2), on: .enemy, in: &battle)
        try playHeroTalentCard(.kindling, in: &battle)
        #expect(talentPoints(.thorns, on: .enemy, in: battle) == 0)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 1)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 1)
    }

    @Test func `grove reserve arrives after decay and uses restored starting mana`() throws {
        var battle = heroTalentBattle("druid_mana_t2_1")
        _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        try playHeroTalentCard(.kindling, in: &battle)
        _ = battle.endTurn()
        #expect(talentPoints(.shield, on: .companion, in: battle) == 1)
        #expect(battle.heroTalents.history[battle.hero.id]?.startingMana == battle.roster.hero.currentMana)
        _ = battle.endTurn()
        #expect(talentPoints(.shield, on: .companion, in: battle) == 0)
    }

    @Test func `purity reduces the first eligible enemy block gain only`() {
        var battle = heroTalentBattle("alchemist_cleanse_t4_1")
        seedHeroTalentEffect(.burn(1), on: .companion, in: &battle)
        #expect(DefensePoolEngine.add(2, to: battle.enemy, in: &battle) == 2)
        battle.removeTalentPoint(.burn, from: battle.companion)
        #expect(DefensePoolEngine.add(1, to: battle.enemy, in: &battle) == 0)
        #expect(DefensePoolEngine.add(2, to: battle.enemy, in: &battle) == 2)
        battle.turnCount += 1
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 0 }
        #expect(DefensePoolEngine.add(2, to: battle.enemy, in: &battle) == 2)
    }

    @Test func `last wager uses the last hero card and improving odds caps at five percent`() throws {
        var battle = heroTalentBattle("wildcard_gold_t3_1", "wildcard_dodge_t3_2")
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        try playHeroTalentCard(.block, owner: .companion, in: &battle)
        _ = CombatTriggerEngine.endHeroTalentTurn(in: &battle)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 1)
        for _ in 0 ..< 8 {
            _ = battle.endTurn()
        }
        #expect(battle.heroTalents.history[battle.hero.id]?.dodgeGrowth == 5)
        let hit = DamageResolutionState(
            amount: 1,
            combatant: battle.hero,
            sourceActorID: battle.enemy.id,
            damageKeyword: .physical,
            options: .directAbilityHit,
        )
        #expect(abs(DamagePipeline.dodgeChance(for: hit, in: battle) - 0.15) < 0.0001)
    }
}
